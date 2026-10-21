#!/usr/bin/env python3
"""
Universal Claude Code LLM Gateway - Diagnostics & Connection Probes
Tests local gateway health, authentication, upstream connectivity,
Anthropic Messages API translation, streaming, tool-calling, and vision.
Works identically on Windows, Linux, and macOS.
"""

import sys
import os
import json
import socket
import urllib.request
import urllib.error

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)  # Parent of core/
ENV_FILE = os.path.join(PROJECT_DIR, ".env")

GREEN = "\033[92m"
RED = "\033[91m"
YELLOW = "\033[93m"
CYAN = "\033[96m"
RESET = "\033[0m"

# Enable Windows ANSI color support if possible
if sys.platform == "win32":
    os.system("")

def print_result(label, status, detail=""):
    color = GREEN if status == "PASS" else (RED if status == "FAIL" else YELLOW)
    print(f"[{color}{status:<4}{RESET}] {label}: {detail}")

def safe_request(url, method="GET", headers=None, body=None, timeout=30):
    if headers is None:
        headers = {}
    data = body.encode("utf-8") if isinstance(body, str) else body
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=timeout) as resp:
            content = resp.read().decode("utf-8", errors="ignore")
            return resp.status, content, None
    except urllib.error.HTTPError as e:
        content = e.read().decode("utf-8", errors="ignore")
        return e.code, content, None
    except Exception as e:
        return 0, "", str(e)

def main():
    print(f"\n{CYAN}=== Universal Claude Code LLM Gateway Diagnostics ==={RESET}")
    print(f"Directory: {SCRIPT_DIR}\n")

    has_failures = False

    # 1. Check .env file
    if not os.path.exists(ENV_FILE):
        print_result(".env File", "FAIL", "Missing. Run start-gateway or python configure.py first.")
        sys.exit(1)
    print_result(".env File", "PASS", "Present.")

    # Load .env
    env = {}
    with open(ENV_FILE, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line and not line.startswith("#") and "=" in line:
                k, v = line.split("=", 1)
                env[k.strip()] = v.strip().strip("'\"")

    port = int(env.get("GATEWAY_PORT", "4000"))
    master_key = env.get("GATEWAY_MASTER_KEY", "")
    model_alias = env.get("GATEWAY_MODEL_ALIAS", "custom-model")

    if not master_key or master_key.startswith("sk-replace_"):
        print_result("Master Key", "FAIL", "GATEWAY_MASTER_KEY not properly set in .env.")
        has_failures = True
    else:
        print_result("Master Key", "PASS", "Configured (secret hidden).")

    # 2. Check local TCP port
    port_open = False
    try:
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.settimeout(2.0)
            port_open = (s.connect_ex(("127.0.0.1", port)) == 0)
    except Exception:
        port_open = False

    if port_open:
        print_result("Local Port", "PASS", f"127.0.0.1:{port} is accepting connections.")
    else:
        print_result("Local Port", "FAIL", f"Nothing listening on 127.0.0.1:{port}. Start the gateway first.")
        sys.exit(1)

    auth_header = {"Authorization": f"Bearer {master_key}"}

    # 3. Check /v1/models
    status, body, err = safe_request(f"http://127.0.0.1:{port}/v1/models", headers=auth_header)
    if status == 200:
        try:
            data = json.loads(body)
            models = [m["id"] for m in data.get("data", [])]
            print_result("Proxy Auth & /v1/models", "PASS", f"Authenticated. Found models: {models}")
            if model_alias in models:
                print_result("Model Alias Discovery", "PASS", f"Alias '{model_alias}' is recognized.")
            else:
                print_result("Model Alias Discovery", "WARN", f"Alias '{model_alias}' not in {models}.")
        except Exception:
            print_result("Proxy Auth & /v1/models", "PASS", "Authenticated response received.")
    elif status in (401, 403):
        print_result("Proxy Auth & /v1/models", "FAIL", f"Rejected master key (HTTP {status}).")
        has_failures = True
    else:
        print_result("Proxy Auth & /v1/models", "FAIL", f"HTTP {status} {err or ''}")
        has_failures = True

    # 4. Check Chat Completions (OpenAI format)
    chat_payload = json.dumps({
        "model": model_alias,
        "messages": [{"role": "user", "content": "Reply with exactly 1"}],
        "max_tokens": 5,
        "stream": False
    })
    headers = {**auth_header, "Content-Type": "application/json"}
    status, body, err = safe_request(f"http://127.0.0.1:{port}/v1/chat/completions", method="POST", headers=headers, body=chat_payload)
    if status == 200:
        print_result("OpenAI Chat Completions", "PASS", "Model responded successfully via /v1/chat/completions.")
    else:
        print_result("OpenAI Chat Completions", "FAIL", f"HTTP {status}: {body[:200] if body else err}")
        has_failures = True

    # 5. Check Anthropic Messages API (/v1/messages)
    messages_payload = json.dumps({
        "model": model_alias,
        "messages": [{"role": "user", "content": "Reply with exactly 1"}],
        "max_tokens": 5
    })
    anthropic_headers = {
        **auth_header,
        "anthropic-version": "2023-06-01",
        "Content-Type": "application/json"
    }
    status, body, err = safe_request(f"http://127.0.0.1:{port}/v1/messages", method="POST", headers=anthropic_headers, body=messages_payload)
    if status == 200:
        print_result("Anthropic Messages API", "PASS", "Claude Code API route /v1/messages translated and responded.")
    else:
        print_result("Anthropic Messages API", "FAIL", f"HTTP {status}: {body[:200] if body else err}")
        has_failures = True

    # 6. Check Streaming SSE
    stream_payload = json.dumps({
        "model": model_alias,
        "messages": [{"role": "user", "content": "Hi"}],
        "max_tokens": 5,
        "stream": True
    })
    status, body, err = safe_request(f"http://127.0.0.1:{port}/v1/messages", method="POST", headers=anthropic_headers, body=stream_payload)
    if status == 200 and ("message_start" in body or "data:" in body):
        print_result("Streaming through Messages", "PASS", "Anthropic SSE stream events verified.")
    else:
        print_result("Streaming through Messages", "WARN", f"Stream returned HTTP {status}.")

    # 7. Check Tool Calling
    tool_payload = json.dumps({
        "model": model_alias,
        "messages": [{"role": "user", "content": "Call function test_fn now"}],
        "tools": [{
            "type": "function",
            "function": {
                "name": "test_fn",
                "description": "Diagnostic test function",
                "parameters": {"type": "object", "properties": {}}
            }
        }],
        "tool_choice": {"type": "function", "function": {"name": "test_fn"}},
        "max_tokens": 20
    })
    status, body, err = safe_request(f"http://127.0.0.1:{port}/v1/chat/completions", method="POST", headers=headers, body=tool_payload)
    if status == 200 and "tool_calls" in body:
        print_result("Tool Calling Probe", "PASS", "Model returned function call.")
    elif status == 200:
        print_result("Tool Calling Probe", "WARN", "Request accepted, but tool_calls not triggered.")
    else:
        print_result("Tool Calling Probe", "WARN", f"Tool request returned HTTP {status}.")

    # 8. Check Vision
    pixel_png = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
    vision_payload = json.dumps({
        "model": model_alias,
        "messages": [{
            "role": "user",
            "content": [
                {"type": "text", "text": "Describe this pixel:"},
                {"type": "image_url", "image_url": {"url": f"data:image/png;base64,{pixel_png}"}}
            ]
        }],
        "max_tokens": 10
    })
    status, body, err = safe_request(f"http://127.0.0.1:{port}/v1/chat/completions", method="POST", headers=headers, body=vision_payload)
    if status == 200:
        print_result("Vision Probe", "PASS", "Base64 image input accepted and completed.")
    else:
        print_result("Vision Probe", "WARN", f"Vision returned HTTP {status}.")

    print("\n" + "=" * 65)
    if has_failures:
        print(f"{RED}Diagnostics completed with failures.{RESET}")
        sys.exit(1)
    else:
        print(f"{GREEN}All critical diagnostics passed successfully!{RESET}")
        print("Claude Code is ready to launch:")
        print("  Windows: claude.bat")
        print("  Linux/macOS: ./claude.sh\n")
        sys.exit(0)

if __name__ == "__main__":
    main()
