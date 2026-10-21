# Universal Claude Code LLM Gateway

A lightweight, enterprise-ready, cross-platform bridge that connects Anthropic's **Claude Code CLI** to **any LLM provider** (Microsoft Azure OpenAI, AWS Bedrock, Google Gemini, Ollama, self-hosted vLLM, LM Studio, Open WebUI, and direct OpenAI-compatible endpoints) across **Windows**, **Linux**, and **macOS**.

---

## Table of Contents
1. [The Problem: Subscription Sprawl & Vendor Lock-In](#1-the-problem-subscription-sprawl--vendor-lock-in)
2. [The Solution & Architecture](#2-the-solution--architecture)
3. [Clean Repository Structure](#3-clean-repository-structure)
4. [Supported Providers](#4-supported-providers)
5. [Quick Start (3-Step Setup)](#5-quick-start-3-step-setup)
6. [Interactive Configuration Wizard](#6-interactive-configuration-wizard)
7. [Provider Configuration Examples](#7-provider-configuration-examples)
8. [Using Claude Code in Any Project Folder](#8-using-claude-code-in-any-project-folder)
9. [Diagnostic Probe Suite](#9-diagnostic-probe-suite)
10. [Under the Hood: Technical Quirks & Solutions](#10-under-the-hood-technical-quirks--solutions)
11. [Security & Privacy](#11-security--privacy)
12. [Troubleshooting](#12-troubleshooting)
13. [Pushing to GitHub / Git Server](#13-pushing-to-github--git-server)
14. [Docker Deployment (Optional)](#14-docker-deployment-optional)
15. [Author & Enterprise Consulting](#15-author--enterprise-consulting)
16. [License](#license)

---

## 1. The Problem: Subscription Sprawl & Vendor Lock-In

### The Enterprise Dilemma
Most modern engineering organizations face a major challenge with modern AI coding tools:
1. **AI Subscription Fatigue & Double Billing:**
   * Companies already have active enterprise contracts or minimum cloud commitments with **AWS Bedrock**, **Microsoft Azure**, **Google Cloud Vertex AI**, or **on-premise private GPU clusters**.
   * Yet tools like Claude Code require either expensive per-seat subscriptions ($20–$30/user/month) or direct Anthropic API credits.
   * **Result:** Companies pay twice—once for their enterprise cloud infrastructure, and again for individual Anthropic licenses.
2. **Centralized Cost Monitoring & Budget Governance:**
   * When hundreds of engineers purchase individual AI tool subscriptions, finance and engineering leadership lose visibility into token usage, cost spikes, and spend efficiency.
   * **With this gateway:** All LLM queries route through your company's existing cloud provider (e.g. AWS Bedrock or Azure OpenAI). Usage is tracked centrally in your existing cloud billing dashboard (AWS Cost Explorer, Azure Cost Management), where volume discounts, corporate enterprise credits, and strict department budget caps automatically apply.
3. **Data Sovereignty & Enterprise Compliance:**
   * Strict privacy policies (HIPAA, SOC2, GDPR, internal IP protection) forbid sending proprietary source code to external multi-tenant public APIs.
   * Code must remain strictly inside your corporate VPC or on-premise servers (like private vLLM or Ollama clusters).

### Technical Limitations of Claude Code
[Claude Code](https://code.claude.com) is Anthropic's terminal-based agentic coding tool. While powerful, it has architectural constraints:
* **Protocol Lock-In:** Claude Code exclusively issues requests using Anthropic's proprietary **Messages API** (`/v1/messages`), expecting Server-Sent Events (SSE) in Anthropic's specific JSON streaming schema.
* **Endpoint Lock-In:** By default, it connects strictly to `api.anthropic.com`.
* **Enterprise Blockers:** Organizations cannot natively point Claude Code to private enterprise instances:
  * **AWS Bedrock** (Anthropic Claude inside private VPCs with corporate billing)
  * **Microsoft Azure OpenAI / Azure AI Foundry** (enterprise GPT-4o / custom models)
  * **Google Cloud Vertex AI & Google Gemini Studio**
  * **Local Offline Models via Ollama** (e.g., Qwen 2.5 Coder, Llama 3.3)
  * **Internal Self-Hosted Clusters** (vLLM, Open WebUI, TGI, LM Studio)

---

## 2. The Solution & Architecture

The **Universal Claude Code LLM Gateway** uses [LiteLLM](https://github.com/BerriAI/litellm) as a transparent, high-performance local proxy running on `127.0.0.1:4000`:

```
┌────────────────────────────────────────────────────────┐
│        Any Project Folder on Your Machine              │
│        (e.g., C:\Projects\MyAwesomeApp)                │
│                                                        │
│   claude.bat / claude.sh                               │
│   └── Sets process-scoped Anthropic env variables      │
└──────────────────────────┬─────────────────────────────┘
                           │ Anthropic Messages API (/v1/messages)
                           ▼
┌────────────────────────────────────────────────────────┐
│       Universal Gateway (127.0.0.1:4000)               │
│       Powered by LiteLLM Proxy                         │
│                                                        │
│   • Translates /v1/messages -> Provider APIs           │
│   • Drops unsupported Anthropic beta flags             │
│   • Streams SSE tokens back to Claude Code             │
│   • Bridges tool-calling & multimodal vision           │
└──────────────┬───────────┬───────────┬─────────┬───────┘
               │           │           │         │
               ▼           ▼           ▼         ▼
        Azure OpenAI  AWS Bedrock   Gemini    vLLM / Ollama
        (Enterprise)   (VPC/IAM)   (Studio)   (Self-Hosted)
```

---

## 3. Clean Repository Structure

The repository is organized for maximum simplicity. The root directory contains **only** the daily user-facing scripts and configuration, while platform-specific implementations live in `scripts/`, Docker containers in `docker/`, and backend proxy routing in `core/`:

```text
claude-code-gateway/
├── start.bat  / start.sh      # Start the LLM gateway server (auto-creates venv if needed)
├── stop.bat   / stop.sh       # Stop the running gateway server
├── claude.bat / claude.sh     # Claude Code launcher (run here or copy to ANY folder)
├── .env                       # Active provider credentials & endpoint configuration
├── .env.example               # Provider template reference (safe for GitHub)
├── README.md                  # Complete guide and enterprise documentation
├── LICENSE                    # MIT Open-Source License
├── .gitignore                 # Protects .env, virtual environments, and log files
│
├── scripts/                   # Platform-specific scripts (run setup & diagnostics here)
│   ├── README.md              # Script usage guide
│   ├── windows/               # Windows batch scripts (.bat)
│   │   ├── setup.bat          # Python check, venv creation, interactive wizard
│   │   ├── start.bat          # Background server launcher with custom port support
│   │   ├── stop.bat           # Graceful process shutdown
│   │   ├── test.bat           # Comprehensive 8-point diagnostic probe
│   │   └── claude.bat         # Standalone Claude Code launcher
│   └── linux/                 # Linux / macOS shell scripts (.sh)
│       ├── setup.sh           # Setup & configuration wizard
│       ├── start.sh           # Background server launcher with custom port support
│       ├── stop.sh            # Graceful process shutdown
│       ├── test.sh            # Comprehensive 8-point diagnostic probe
│       └── claude.sh          # Standalone Claude Code launcher
│
├── docker/                    # Containerized deployment
│   ├── Dockerfile             # Production container definition
│   └── docker-compose.yml     # 1-command startup (docker compose up -d)
│
└── core/                      # Internal proxy engine (not touched by end-users)
    ├── config.yaml            # LiteLLM routing definitions & model aliases
    ├── configure.py           # Interactive multi-provider configuration wizard
    ├── requirements.txt       # Python dependencies (litellm, pyyaml)
    ├── test-connection.py     # Diagnostic probe engine
    └── .venv/                 # Isolated Python virtual environment (auto-created)
```

---

## 4. Supported Providers

| Provider | Supported Models | Required Credentials / Variables |
| :--- | :--- | :--- |
| **Self-Hosted vLLM** | Gemma, Llama, Qwen, DeepSeek, Mistral | `CUSTOM_API_BASE`, `CUSTOM_API_KEY` (if enabled), `CUSTOM_MODEL_ID` |
| **Microsoft Azure OpenAI** | GPT-4o, GPT-4o-mini, Claude on Azure | `AZURE_API_BASE`, `AZURE_API_KEY`, `AZURE_DEPLOYMENT_NAME` |
| **AWS Bedrock** | Claude 3.5 Sonnet, Llama 3.3, Amazon Titan | `AWS_REGION_NAME`, `AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY` |
| **Google Gemini / Vertex** | Gemini 2.5 Pro, Gemini 2.0 Flash | `GEMINI_API_KEY`, `GEMINI_MODEL_ID` |
| **Ollama (Local)** | Qwen 2.5 Coder, Llama 3.2, DeepSeek | `OLLAMA_API_BASE` (default `http://localhost:11434`), `OLLAMA_MODEL_ID` |
| **OpenAI Direct** | GPT-4o, o1, o3-mini | `OPENAI_API_KEY`, `OPENAI_MODEL_ID` |
| **Other Providers** | Groq, DeepSeek, Mistral, OpenRouter | Provider API Key & Model Name |

---

## 5. Quick Start (3-Step Setup)

### Prerequisites
* **Python 3.10+ (64-bit)** installed and on your PATH ([python.org](https://www.python.org/downloads/)).
* **Node.js 18+** with Claude Code installed globally:
  ```bash
  npm install -g @anthropic-ai/claude-code
  ```

---

### Step 1: Configure Your Provider

Run the configuration wizard or edit `.env` directly:
* **Windows:** Run the setup script:
  ```cmd
  scripts\windows\setup.bat
  ```
* **Linux / macOS:**
  ```bash
  chmod +x scripts/linux/*.sh
  ./scripts/linux/setup.sh
  ```
This script automatically prepares the virtual environment inside `core/.venv`, installs dependencies, launches the interactive configuration wizard, and creates `.env` and `core/config.yaml`. *(Alternatively, copy `.env.example` to `.env` and edit your API keys directly).*

---

### Step 2: Start the Gateway

Launch the background gateway server:
* **Windows:** Double-click `start.bat` or run:
  ```cmd
  start.bat
  ```
* **Linux / macOS:**
  ```bash
  chmod +x *.sh
  ./start.sh
  ```

> **Automatic Virtual Environment:** On first run, `start.bat` / `start.sh` creates `core/.venv`, installs all packages, registers the gateway path in `~/.claude-gateway-root`, and starts LiteLLM on `127.0.0.1:4000`. **Keep this window open while coding.**

---

### Step 3: Run Claude Code (From Any Folder!)

Now launch Claude Code in your project repository:
* **Windows:**
  ```cmd
  claude.bat
  ```
* **Linux / macOS:**
  ```bash
  ./claude.sh
  ```

---

## 6. Interactive Configuration Wizard

The wizard in `core/configure.py` simplifies switching between backends:

```text
======================================================================
     Universal Claude Code LLM Gateway - Configuration Wizard
======================================================================
Select your LLM Provider:
  1) Custom / Self-Hosted Endpoint (vLLM, Open WebUI, LM Studio, TGI)
  2) Microsoft Azure OpenAI / Azure AI Foundry
  3) AWS Bedrock
  4) Google Gemini / Vertex AI
  5) Ollama (Local LLMs)
  6) OpenAI Direct
  7) Other Cloud Providers (Groq, DeepSeek, Mistral, OpenRouter)

Enter choice [1-7]: 1
--> Selected: Custom / Self-Hosted Endpoint

Local Gateway Port [4000]: 4000
Model alias for Claude Code [custom-model]: gemma-4-31B-it
Endpoint Base URL: http://192.168.1.100:8080/api
Upstream Model ID: google/gemma-4-31b-it
Upstream API Key (leave blank if unauthenticated): [hidden]

----------------------------------------------------------------------
  Summary of Settings to be Saved:
----------------------------------------------------------------------
  Provider       : Custom / Self-Hosted Endpoint
  Gateway Port   : 4000
  Model Alias    : gemma-4-31B-it
  CUSTOM_API_BASE: http://192.168.1.100:8080/api
  CUSTOM_MODEL_ID: google/gemma-4-31b-it
  CUSTOM_API_KEY : [hidden]
----------------------------------------------------------------------
Save this configuration? [Y/n]: y

Configuration saved successfully!
```

---

## 7. Provider Configuration Examples

If you prefer to configure manually, copy `.env.example` to `.env` and fill in your values.

### Example A: Self-Hosted vLLM / Internal Server
In `.env`:
```dotenv
GATEWAY_PORT=4000
GATEWAY_MASTER_KEY=sk-your-generated-32-char-secret-key-12345
GATEWAY_MODEL_ALIAS=gemma-4-31B-it

CUSTOM_API_BASE=http://your-server-ip:8080/api
CUSTOM_API_KEY=your_upstream_token_or_not_required
CUSTOM_MODEL_ID=google/gemma-4-31b-it
```

In `core/config.yaml`:
```yaml
model_list:
  - model_name: gemma-4-31B-it
    litellm_params:
      model: hosted_vllm/google/gemma-4-31b-it
      api_base: os.environ/CUSTOM_API_BASE
      api_key: os.environ/CUSTOM_API_KEY
      temperature: 0.2
      top_p: 0.9
      timeout: 180

litellm_settings:
  drop_params: true
  set_verbose: false
  use_chat_completions_url_for_anthropic_messages: true

general_settings:
  master_key: os.environ/GATEWAY_MASTER_KEY
```

---

### Example B: Microsoft Azure OpenAI
In `.env`:
```dotenv
GATEWAY_PORT=4000
GATEWAY_MASTER_KEY=sk-your-generated-32-char-secret-key-12345
GATEWAY_MODEL_ALIAS=azure-gpt4o

AZURE_API_BASE=https://my-company.openai.azure.com/
AZURE_API_KEY=your_azure_api_key_here
AZURE_DEPLOYMENT_NAME=gpt-4o
AZURE_API_VERSION=2024-08-01-preview
```

In `core/config.yaml`:
```yaml
model_list:
  - model_name: azure-gpt4o
    litellm_params:
      model: azure/gpt-4o
      api_base: os.environ/AZURE_API_BASE
      api_key: os.environ/AZURE_API_KEY
      api_version: os.environ/AZURE_API_VERSION
      timeout: 180
```

---

### Example C: AWS Bedrock
In `.env`:
```dotenv
GATEWAY_PORT=4000
GATEWAY_MASTER_KEY=sk-your-generated-32-char-secret-key-12345
GATEWAY_MODEL_ALIAS=bedrock-claude

AWS_REGION_NAME=us-east-1
AWS_ACCESS_KEY_ID=AKIAIOSFODNN7EXAMPLE
AWS_SECRET_ACCESS_KEY=wJalrXUtnFEMI/K7MDENG/bPxRfiCYEXAMPLEKEY
BEDROCK_MODEL_ID=anthropic.claude-3-5-sonnet-20241022-v2:0
```

In `core/config.yaml`:
```yaml
model_list:
  - model_name: bedrock-claude
    litellm_params:
      model: bedrock/anthropic.claude-3-5-sonnet-20241022-v2:0
      aws_region_name: os.environ/AWS_REGION_NAME
      aws_access_key_id: os.environ/AWS_ACCESS_KEY_ID
      aws_secret_access_key: os.environ/AWS_SECRET_ACCESS_KEY
      timeout: 180
```

---

### Example D: Local Ollama
In `.env`:
```dotenv
GATEWAY_PORT=4000
GATEWAY_MASTER_KEY=sk-your-generated-32-char-secret-key-12345
GATEWAY_MODEL_ALIAS=local-qwen

OLLAMA_API_BASE=http://localhost:11434
OLLAMA_MODEL_ID=qwen2.5-coder:32b
```

In `core/config.yaml`:
```yaml
model_list:
  - model_name: local-qwen
    litellm_params:
      model: ollama/qwen2.5-coder:32b
      api_base: os.environ/OLLAMA_API_BASE
      timeout: 180
```

---

## 8. Using Claude Code in Any Project Folder

You can use Claude Code with your custom LLM backend from **any folder on your computer**:

### Method A: Copy `claude.bat` / `claude.sh` to Your Project Folder
When `start.bat` / `start.sh` starts, it registers the gateway's location on your system (`~/.claude-gateway-root`).

You can copy `claude.bat` (or `claude.sh`) into any repository on your machine:
```text
C:\Users\you\MyProject\
├── src/
├── package.json
└── claude.bat       <-- Just paste it here!
```
When you run `claude.bat` inside `C:\Users\you\MyProject`, it automatically:
1. Discovers the gateway location from `~/.claude-gateway-root`.
2. Connects to `127.0.0.1:4000` using the credentials in your gateway `.env`.
3. Runs Claude Code **inside your `MyProject` folder**, so all files read and written belong to your project.

### Method B: Run via Direct Path (No Copying Required)
From inside your project folder in terminal, invoke the launcher directly:
```cmd
# Windows
"D:\path\to\claude-code-gateway\claude.bat"

# Linux / macOS
/path/to/claude-code-gateway/claude.sh
```

Pass any flags just like native Claude Code:
```bash
claude.bat --version
claude.bat -p "Analyze this repository and summarize its components"
```

---

## 9. Diagnostic Probe Suite

To verify that the proxy and upstream LLM are working properly, run the diagnostic test script:
* **Windows:** `scripts\windows\test.bat`
* **Linux / macOS:** `./scripts/linux/test.sh`

The probe executes 8 automated checks:
```text
=== Universal Claude Code LLM Gateway Diagnostics ===
[PASS] .env File              : Present.
[PASS] Master Key             : Configured (secret hidden).
[PASS] Local Port             : 127.0.0.1:4000 is accepting connections.
[PASS] Proxy Auth & /v1/models: Authenticated. Found models: ['custom-model', 'gemma-4-31B-it']
[PASS] Model Alias Discovery  : Alias 'gemma-4-31B-it' is recognized.
[PASS] OpenAI Chat Completions: Model responded successfully via /v1/chat/completions.
[PASS] Anthropic Messages API : Claude Code route /v1/messages translated and responded.
[PASS] Streaming SSE Events   : Anthropic SSE stream events verified.
[PASS] Tool Calling Probe     : Model returned function call.
=================================================================
All critical diagnostics passed successfully!
```

---

## 10. Under the Hood: Technical Quirks & Solutions

This gateway incorporates specific engineering fixes for subtle edge cases:

1. **Self-Referencing Loop Prevention:**
   On Windows, naming the launcher `claude.bat` caused `where claude` to find `claude.bat` in the current folder, creating an infinite recursive loop. `claude.bat` explicitly searches for `claude.cmd` (npm's executable) and filters out `%~f0` (itself).

2. **Windows Path Space & Quotes Handling:**
   Paths with spaces (e.g., `D:\OFFICE PROJECT\...`) often break CMD argument passing. All scripts strip trailing backslashes and use relative paths for internal YAML configuration to guarantee quote safety.

3. **Console UTF-8 Encoding:**
   LiteLLM prints a Unicode startup banner. On standard Windows `cp1252` console code pages, this causes a fatal `UnicodeEncodeError`. `start.bat` automatically forces `PYTHONIOENCODING=utf-8` and `PYTHONUTF8=1`.

4. **Anthropic Message Routing to OpenAI Backends:**
   LiteLLM v1.106+ routes generic `openai/` prefixes to OpenAI's Responses API (`/api/responses`), causing `HTTP 405 Method Not Allowed` on vLLM endpoints. The configuration uses `hosted_vllm/` with `use_chat_completions_url_for_anthropic_messages: true` to route cleanly to `/api/chat/completions`.

5. **Model ID Casing:**
   Upstream vLLM engines are case-sensitive (e.g. `google/gemma-4-31b-it` requires lowercase `b`). The gateway handles alias resolution so Claude Code can request friendly aliases while the upstream server receives the exact casing it requires.

---

## 11. Security & Privacy

1. **Localhost Only:** The gateway binds strictly to `127.0.0.1`. It never listens on public interfaces (`0.0.0.0`) or exposes ports to your LAN.
2. **Process-Scoped Isolation:** Authentication tokens (`ANTHROPIC_AUTH_TOKEN`, `ANTHROPIC_BASE_URL`) are injected exclusively into the Claude Code child process. No permanent environment variables or registry entries are modified.
3. **Secret Protection:** `.gitignore` excludes `.env`, `core/.venv/`, and `core/.gateway.pid`.

---

## 12. Troubleshooting

| Symptom | Cause | Solution |
| :--- | :--- | :--- |
| `Gateway is not running or rejected the key` | Port 4000 is down or master key mismatch | Run `start.bat` / `./start.sh` and ensure it displays `Gateway running on PID ...`. |
| `Claude Code CLI was not found` | Claude Code is not installed globally | Run `npm install -g @anthropic-ai/claude-code`. |
| `Could not locate the gateway's .env file` | Running a copied `claude.bat` before starting the gateway | Run `start.bat` at least once from the gateway directory to register `~/.claude-gateway-root`. |
| `400 Bad Request: Model not found` | Upstream model identifier mismatch or case error | Check the exact casing on your upstream server (e.g. `google/gemma-4-31b-it`). |
| `405 Method Not Allowed` | Routing to `/responses` instead of `/chat/completions` | Ensure `use_chat_completions_url_for_anthropic_messages: true` is set in `core/config.yaml`. |
| `UnicodeEncodeError` on Windows | Console encoding not UTF-8 | Set `PYTHONIOENCODING=utf-8` and `PYTHONUTF8=1` (already handled in `start.bat`). |

## 13. Pushing to GitHub / Git Server

Follow these steps to publish this repository cleanly without leaking your `.env` secrets or virtual environment:

### Step 1: Initialize Git & Verify Ignored Files
Open a terminal in the `claude-code-gateway` directory:
```bash
git init
```

Check what files Git sees:
```bash
git status
```
> **Security Check:** Confirm that `.env` and `core/.venv/` are **NOT** listed in `git status`. They are automatically excluded by `.gitignore`.

### Step 2: Stage and Commit the Files
```bash
git add .
git commit -m "feat: universal claude code gateway for all llm providers"
```

### Step 3: Link to Your Remote Repository & Push
```bash
# Rename branch to main
git branch -M main

# Add your GitHub / Git server URL
git remote add origin https://github.com/your-username/claude-code-gateway.git

# Push to the remote repository
git push -u origin main
```

---

## 14. Docker Deployment (Optional)

You can also run the gateway as a background containerized service using Docker and Docker Compose:

```bash
# 1. Start the container in the background
cd docker && docker compose up -d

# 2. Monitor gateway logs
docker compose logs -f

# 3. Stop the container
docker compose down
```

---

## 15. Author & Enterprise Consulting

This project was designed, developed, and maintained by **Basil Ahamed H**.

If your engineering organization or enterprise requires custom AI gateway architecture, private VPC deployments (AWS Bedrock / Azure AI Foundry), multi-tenant cost-tracking proxies, or custom on-premise model integrations:

* **Lead Architect & Developer:** Basil Ahamed H
* **LinkedIn:** [linkedin.com/in/basil-ahamed-h](https://www.linkedin.com/in/basil-ahamed-h/)
* **Direct Contact / WhatsApp:** [+91 7397061751](tel:+917397061751)
* **Email:** [basilahamed46@gmail.com](mailto:basilahamed46@gmail.com) | [basilahamed46@protonmail.com](mailto:basilahamed46@protonmail.com)

---

## License

This project is released under the **[MIT License](LICENSE)** &copy; 2026 **Basil Ahamed H**.
Permission is hereby granted to use, modify, distribute, and integrate commercially or in open-source projects.

