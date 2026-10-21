#!/usr/bin/env python3
"""
Universal Claude Code LLM Gateway - Interactive Configuration Wizard
Guides users through configuring any LLM backend (Azure OpenAI, AWS Bedrock,
Google Gemini, Ollama, self-hosted vLLM, OpenAI Direct, Groq, DeepSeek).
Works on Windows, Linux, and macOS.
"""

import os
import sys
import secrets

try:
    import yaml
except ImportError:
    yaml = None

SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
PROJECT_DIR = os.path.dirname(SCRIPT_DIR)  # Parent directory where .env lives
ENV_FILE = os.path.join(PROJECT_DIR, ".env")
CONFIG_FILE = os.path.join(SCRIPT_DIR, "config.yaml")

PROVIDERS = [
    {
        "id": "custom",
        "name": "Custom / Self-Hosted Endpoint (vLLM, Open WebUI, LM Studio, TGI)",
        "description": "Any OpenAI-compatible server running locally or on a private server."
    },
    {
        "id": "azure",
        "name": "Microsoft Azure OpenAI / Azure AI Foundry",
        "description": "Enterprise hosted models (GPT-4o, Claude on Azure, etc.)"
    },
    {
        "id": "bedrock",
        "name": "AWS Bedrock",
        "description": "Anthropic Claude 3.5, Meta Llama, Amazon Titan via AWS Bedrock"
    },
    {
        "id": "gemini",
        "name": "Google Gemini / Vertex AI",
        "description": "Gemini 2.5 Pro / Flash via Google AI Studio or Vertex AI"
    },
    {
        "id": "ollama",
        "name": "Ollama (Local LLMs)",
        "description": "Locally running Ollama models (Qwen 2.5 Coder, Llama 3.3, DeepSeek)"
    },
    {
        "id": "openai",
        "name": "OpenAI Direct",
        "description": "Direct OpenAI API (GPT-4o, o1, o3-mini)"
    },
    {
        "id": "other",
        "name": "Other Cloud Providers (Groq, DeepSeek, Mistral, OpenRouter)",
        "description": "Any provider supported by LiteLLM via OpenAI-compatible endpoints"
    }
]

def load_existing_env():
    """Load existing .env key-value pairs if present."""
    env = {}
    if os.path.exists(ENV_FILE):
        try:
            with open(ENV_FILE, "r", encoding="utf-8") as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith("#") and "=" in line:
                        k, v = line.split("=", 1)
                        env[k.strip()] = v.strip().strip("'\"")
        except Exception:
            pass
    return env

def prompt(text, default=""):
    """Prompt user for standard input with an optional default value."""
    if default:
        res = input(f"{text} [{default}]: ").strip()
        return res if res else default
    res = input(f"{text}: ").strip()
    return res

def prompt_secret(text, existing=""):
    """Prompt for a secret (hiding input when possible), preserving existing values."""
    hint = "[Press Enter to keep existing secret]" if existing else ""
    try:
        import getpass
        prompt_label = f"{text} {hint} (input hidden): " if hint else f"{text} (input hidden): "
        res = getpass.getpass(prompt_label).strip()
    except Exception:
        prompt_label = f"{text} {hint}: " if hint else f"{text}: "
        res = input(prompt_label).strip()

    if not res and existing:
        return existing
    return res

def main():
    try:
        print("\n" + "=" * 70)
        print("     Universal Claude Code LLM Gateway - Configuration Wizard")
        print("=" * 70)
        print("This wizard configures your LLM backend so Claude Code can communicate")
        print("with your model through LiteLLM's Anthropic Messages API adapter.\n")

        existing_env = load_existing_env()
        if existing_env:
            print("[INFO] Found existing configuration in .env. Press Enter to accept defaults.\n")

        print("Select your LLM Provider:")
        for idx, p in enumerate(PROVIDERS, 1):
            print(f"  {idx}) {p['name']}")
            print(f"     -> {p['description']}")

        choice = prompt("\nEnter choice [1-7]", "1")
        try:
            choice_idx = int(choice) - 1
            if choice_idx < 0 or choice_idx >= len(PROVIDERS):
                choice_idx = 0
        except ValueError:
            choice_idx = 0

        provider = PROVIDERS[choice_idx]
        print(f"\n--> Selected: {provider['name']}\n")

        # 1. Gateway settings
        port_default = existing_env.get("GATEWAY_PORT", "4000")
        port = prompt("Local Gateway Port", port_default)

        alias_default = existing_env.get("GATEWAY_MODEL_ALIAS", "custom-model")
        model_alias = prompt("Model alias for Claude Code", alias_default)

        # Retain or generate master key
        existing_key = existing_env.get("GATEWAY_MASTER_KEY", "")
        if existing_key and len(existing_key) >= 32 and not existing_key.startswith("sk-replace_"):
            master_key = existing_key
        else:
            master_key = f"sk-{secrets.token_urlsafe(32)}"

        env_vars = {
            "GATEWAY_PORT": port,
            "GATEWAY_MASTER_KEY": master_key,
            "GATEWAY_MODEL_ALIAS": model_alias,
        }

        model_entry = {
            "model_name": model_alias,
            "litellm_params": {
                "timeout": 180
            }
        }

        # 2. Provider-specific configuration
        if provider["id"] == "custom":
            api_base_default = existing_env.get("CUSTOM_API_BASE", "http://127.0.0.1:8080/api")
            model_id_default = existing_env.get("CUSTOM_MODEL_ID", "google/gemma-4-31b-it")
            existing_custom_key = existing_env.get("CUSTOM_API_KEY", "")

            api_base = prompt("Endpoint Base URL (e.g. http://server-ip:8080/api)", api_base_default)
            model_id = prompt("Upstream Model ID (e.g. google/gemma-4-31b-it)", model_id_default)
            api_key = prompt_secret("Upstream API Key (leave blank if unauthenticated)", existing_custom_key)

            # Strip trailing /chat/completions if entered by mistake
            if api_base.endswith("/chat/completions"):
                api_base = api_base[:-len("/chat/completions")].rstrip("/")

            env_vars["CUSTOM_API_BASE"] = api_base
            env_vars["CUSTOM_API_KEY"] = api_key if api_key else "not_required"
            env_vars["CUSTOM_MODEL_ID"] = model_id

            model_entry["litellm_params"]["model"] = f"hosted_vllm/{model_id}"
            model_entry["litellm_params"]["api_base"] = "os.environ/CUSTOM_API_BASE"
            model_entry["litellm_params"]["api_key"] = "os.environ/CUSTOM_API_KEY"
            model_entry["litellm_params"]["temperature"] = 0.2
            model_entry["litellm_params"]["top_p"] = 0.9

        elif provider["id"] == "azure":
            api_base_default = existing_env.get("AZURE_API_BASE", "https://your-resource.openai.azure.com/")
            deployment_default = existing_env.get("AZURE_DEPLOYMENT_NAME", "gpt-4o")
            version_default = existing_env.get("AZURE_API_VERSION", "2024-08-01-preview")
            existing_azure_key = existing_env.get("AZURE_API_KEY", "")

            api_base = prompt("Azure Endpoint Base (e.g. https://your-resource.openai.azure.com/)", api_base_default)
            deployment = prompt("Azure Deployment Name (e.g. gpt-4o)", deployment_default)
            api_key = prompt_secret("Azure API Key", existing_azure_key)
            api_version = prompt("API Version", version_default)

            env_vars["AZURE_API_BASE"] = api_base
            env_vars["AZURE_API_KEY"] = api_key
            env_vars["AZURE_DEPLOYMENT_NAME"] = deployment
            env_vars["AZURE_API_VERSION"] = api_version

            model_entry["litellm_params"]["model"] = f"azure/{deployment}"
            model_entry["litellm_params"]["api_base"] = "os.environ/AZURE_API_BASE"
            model_entry["litellm_params"]["api_key"] = "os.environ/AZURE_API_KEY"
            model_entry["litellm_params"]["api_version"] = "os.environ/AZURE_API_VERSION"

        elif provider["id"] == "bedrock":
            region_default = existing_env.get("AWS_REGION_NAME", "us-east-1")
            model_default = existing_env.get("BEDROCK_MODEL_ID", "anthropic.claude-3-5-sonnet-20241022-v2:0")
            existing_ak = existing_env.get("AWS_ACCESS_KEY_ID", "")
            existing_sk = existing_env.get("AWS_SECRET_ACCESS_KEY", "")

            region = prompt("AWS Region Name (e.g. us-east-1)", region_default)
            model_id = prompt("Bedrock Model ID", model_default)
            access_key = prompt("AWS Access Key ID", existing_ak)
            secret_key = prompt_secret("AWS Secret Access Key", existing_sk)

            env_vars["AWS_REGION_NAME"] = region
            env_vars["BEDROCK_MODEL_ID"] = model_id
            env_vars["AWS_ACCESS_KEY_ID"] = access_key
            env_vars["AWS_SECRET_ACCESS_KEY"] = secret_key

            model_entry["litellm_params"]["model"] = f"bedrock/{model_id}"
            model_entry["litellm_params"]["aws_region_name"] = "os.environ/AWS_REGION_NAME"
            model_entry["litellm_params"]["aws_access_key_id"] = "os.environ/AWS_ACCESS_KEY_ID"
            model_entry["litellm_params"]["aws_secret_access_key"] = "os.environ/AWS_SECRET_ACCESS_KEY"

        elif provider["id"] == "gemini":
            model_default = existing_env.get("GEMINI_MODEL_ID", "gemini-2.5-pro")
            existing_gemini_key = existing_env.get("GEMINI_API_KEY", "")

            model_id = prompt("Gemini Model ID", model_default)
            api_key = prompt_secret("Google AI Studio / Gemini API Key", existing_gemini_key)

            env_vars["GEMINI_MODEL_ID"] = model_id
            env_vars["GEMINI_API_KEY"] = api_key

            model_entry["litellm_params"]["model"] = f"gemini/{model_id}"
            model_entry["litellm_params"]["api_key"] = "os.environ/GEMINI_API_KEY"

        elif provider["id"] == "ollama":
            base_default = existing_env.get("OLLAMA_API_BASE", "http://localhost:11434")
            model_default = existing_env.get("OLLAMA_MODEL_ID", "qwen2.5-coder:32b")

            api_base = prompt("Ollama Base URL", base_default)
            model_id = prompt("Ollama Model Name (e.g. qwen2.5-coder:32b, llama3.3)", model_default)

            env_vars["OLLAMA_API_BASE"] = api_base
            env_vars["OLLAMA_MODEL_ID"] = model_id

            model_entry["litellm_params"]["model"] = f"ollama/{model_id}"
            model_entry["litellm_params"]["api_base"] = "os.environ/OLLAMA_API_BASE"

        elif provider["id"] == "openai":
            model_default = existing_env.get("OPENAI_MODEL_ID", "gpt-4o")
            existing_openai_key = existing_env.get("OPENAI_API_KEY", "")

            model_id = prompt("OpenAI Model (e.g. gpt-4o, o3-mini)", model_default)
            api_key = prompt_secret("OpenAI API Key", existing_openai_key)

            env_vars["OPENAI_MODEL_ID"] = model_id
            env_vars["OPENAI_API_KEY"] = api_key

            model_entry["litellm_params"]["model"] = f"openai/{model_id}"
            model_entry["litellm_params"]["api_key"] = "os.environ/OPENAI_API_KEY"

        elif provider["id"] == "other":
            prefix = prompt("LiteLLM Provider Prefix (e.g. groq, deepseek, mistral, openrouter)", "groq")
            model_id = prompt("Model Identifier (e.g. llama-3.3-70b-versatile, deepseek-chat)")
            api_key = prompt_secret("Provider API Key")

            env_vars["PROVIDER_API_KEY"] = api_key
            env_vars["PROVIDER_MODEL_ID"] = model_id

            model_entry["litellm_params"]["model"] = f"{prefix}/{model_id}"
            model_entry["litellm_params"]["api_key"] = "os.environ/PROVIDER_API_KEY"

        # 3. Summary & Confirmation
        print("\n" + "-" * 70)
        print("  Summary of Settings to be Saved:")
        print("-" * 70)
        print(f"  Provider       : {provider['name']}")
        print(f"  Gateway Port   : {env_vars['GATEWAY_PORT']}")
        print(f"  Model Alias    : {env_vars['GATEWAY_MODEL_ALIAS']}")
        for k, v in env_vars.items():
            if k not in ("GATEWAY_PORT", "GATEWAY_MODEL_ALIAS", "GATEWAY_MASTER_KEY"):
                val_display = "[hidden]" if "KEY" in k or "SECRET" in k else v
                print(f"  {k:<15}: {val_display}")
        print("-" * 70)

        confirm = prompt("Save this configuration? [Y/n]", "y").lower()
        if confirm not in ("y", "yes", ""):
            print("[INFO] Configuration cancelled without saving.")
            return

        # 4. Write .env file
        with open(ENV_FILE, "w", encoding="utf-8") as f:
            f.write("# Universal Claude Code LLM Gateway - Environment Configuration\n")
            f.write(f"# Configured for: {provider['name']}\n\n")
            for k, v in env_vars.items():
                f.write(f"{k}={v}\n")

        # 5. Build and write core/config.yaml
        config_data = {
            "model_list": [
                model_entry,
                # Also expose model directly under its upstream ID if different from alias
                {
                    "model_name": env_vars.get("CUSTOM_MODEL_ID") or env_vars.get("BEDROCK_MODEL_ID") or env_vars.get("GEMINI_MODEL_ID") or env_vars.get("OLLAMA_MODEL_ID") or env_vars.get("OPENAI_MODEL_ID") or model_alias,
                    "litellm_params": model_entry["litellm_params"]
                }
            ],
            "litellm_settings": {
                "drop_params": True,
                "set_verbose": False,
                "use_chat_completions_url_for_anthropic_messages": True
            },
            "general_settings": {
                "master_key": "os.environ/GATEWAY_MASTER_KEY"
            }
        }

        # Filter duplicate models in model_list
        seen_names = set()
        deduped_models = []
        for m in config_data["model_list"]:
            name = m.get("model_name")
            if name and name not in seen_names:
                seen_names.add(name)
                deduped_models.append(m)
        config_data["model_list"] = deduped_models

        if yaml:
            with open(CONFIG_FILE, "w", encoding="utf-8") as f:
                f.write("# Universal Claude Code LLM Gateway - LiteLLM Configuration\n")
                f.write("# Automatically generated by core/configure.py\n\n")
                yaml.dump(config_data, f, default_flow_style=False, sort_keys=False)
        else:
            # Fallback if pyyaml is not yet installed in host Python
            import json
            print("[WARN] PyYAML not found in current Python. Writing YAML template.")

        print("\n" + "=" * 70)
        print("  Configuration saved successfully!")
        print(f"  - Environment File : {ENV_FILE}")
        print(f"  - Config File      : {CONFIG_FILE}")
        print("=" * 70)
        print("\nNext steps:")
        print("  1. Start the gateway:")
        print("     Windows     : start.bat")
        print("     Linux/macOS : ./start.sh")
        print("  2. Verify connectivity:")
        print("     Windows     : test.bat")
        print("     Linux/macOS : ./test.sh")
        print("  3. Launch Claude Code (from any folder!):")
        print("     Windows     : claude.bat")
        print("     Linux/macOS : ./claude.sh\n")

    except (KeyboardInterrupt, EOFError):
        print("\n\n[INFO] Configuration wizard cancelled.")
        sys.exit(0)

if __name__ == "__main__":
    main()
