# Gateway Scripts Directory

This directory contains the platform-specific scripts for managing the Universal Claude Code LLM Gateway.

```text
scripts/
├── windows/                   # Windows Batch Scripts (.bat)
│   ├── setup.bat              # Creates core\.venv and launches interactive configuration
│   ├── start.bat              # Starts the LiteLLM proxy server on 127.0.0.1:4000
│   ├── stop.bat               # Gracefully stops the background proxy server
│   ├── test.bat               # Runs the 8-point connection and capability probe suite
│   └── claude.bat             # Claude Code launcher (can be copied to ANY project)
│
└── linux/                     # Linux & macOS Shell Scripts (.sh)
    ├── setup.sh               # Creates core/.venv and launches interactive configuration
    ├── start.sh               # Starts the LiteLLM proxy server on 127.0.0.1:4000
    ├── stop.sh                # Gracefully stops the background proxy server
    ├── test.sh                # Runs the 8-point connection and capability probe suite
    └── claude.sh              # Claude Code launcher (can be copied to ANY project)
```

---

## Usage Guide

### Windows Users
* Run scripts directly from `scripts\windows\` or use the convenient shortcuts in the project root:
  * Setup: `scripts\windows\setup.bat` (or root `setup.bat`)
  * Start: `scripts\windows\start.bat` (or root `start.bat`)
  * Test: `scripts\windows\test.bat` (or root `test.bat`)
  * Stop: `scripts\windows\stop.bat` (or root `stop.bat`)
  * Claude Code: Copy `scripts\windows\claude.bat` into any project repository and run it.

### Linux / macOS Users
* Ensure execution permissions are set:
  ```bash
  chmod +x scripts/linux/*.sh
  ```
* Run scripts directly from `scripts/linux/` or use the root shortcuts:
  * Setup: `./scripts/linux/setup.sh` (or root `./setup.sh`)
  * Start: `./scripts/linux/start.sh` (or root `./start.sh`)
  * Test: `./scripts/linux/test.sh` (or root `./test.sh`)
  * Stop: `./scripts/linux/stop.sh` (or root `./stop.sh`)
  * Claude Code: Copy `scripts/linux/claude.sh` into any project repository and run it.

---

## Automatic Root Discovery
When `setup` or `start` runs, it writes the gateway root path to `~/.claude-gateway-root`.
When `claude.bat` or `claude.sh` is copied into another folder on your machine, it reads that path to locate the `.env` configuration file automatically.
