#!/usr/bin/env bash
# ==============================================================================
# Universal Claude Code LLM Gateway - Linux / macOS Startup Script
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CORE_DIR="$PROJECT_DIR/core"
cd "$PROJECT_DIR"

echo ""
echo "======================================================="
echo "       Claude Code Universal LLM Gateway (Linux/macOS) "
echo "======================================================="
echo "Gateway Root: $PROJECT_DIR"
echo ""

# 1. Locate Python 3
if command -v python3 >/dev/null 2>&1; then
    PYTHON_CMD="python3"
elif command -v python >/dev/null 2>&1; then
    PYTHON_CMD="python"
else
    echo "[ERROR] Python 3 was not found. Please install Python 3.10+."
    exit 10
fi

# 2. Setup virtual environment inside core/ if missing
VENV_DIR="$CORE_DIR/.venv"
VENV_BIN="$VENV_DIR/bin"
VENV_PYTHON="$VENV_BIN/python"
VENV_LITELLM="$VENV_BIN/litellm"

if [ ! -f "$VENV_LITELLM" ]; then
    echo "[SETUP] Setting up virtual environment..."
    if [ ! -d "$VENV_DIR" ]; then
        $PYTHON_CMD -m venv "$VENV_DIR"
    fi
    echo "[SETUP] Installing dependencies..."
    "$VENV_PYTHON" -m pip install --upgrade pip >/dev/null 2>&1 || true
    "$VENV_PYTHON" -m pip install -r "$CORE_DIR/requirements.txt"
    echo "[SETUP] Dependencies installed successfully."
    echo ""
fi

# 3. Configure .env if missing
if [ ! -f "$PROJECT_DIR/.env" ]; then
    echo "[INFO] No .env found. Starting interactive configuration wizard..."
    "$VENV_PYTHON" "$CORE_DIR/configure.py"
    if [ ! -f "$PROJECT_DIR/.env" ]; then
        echo "[ERROR] Configuration was not completed. Exiting."
        exit 13
    fi
fi

# 4. Export variables from .env
set -a
# shellcheck disable=SC1091
source "$PROJECT_DIR/.env"
set +a

GATEWAY_PORT="${GATEWAY_PORT:-4000}"
GATEWAY_MODEL_ALIAS="${GATEWAY_MODEL_ALIAS:-custom-model}"

if [ -z "$GATEWAY_MASTER_KEY" ]; then
    echo "[ERROR] GATEWAY_MASTER_KEY is not defined in .env."
    exit 14
fi

# 5. Register this directory so claude.sh can find it from any folder
echo "$PROJECT_DIR" > "$HOME/.claude-gateway-root"

echo "Gateway Port : $GATEWAY_PORT"
echo "Model Alias  : $GATEWAY_MODEL_ALIAS"
echo "Binding to   : 127.0.0.1:$GATEWAY_PORT"
echo ""
echo "Leave this terminal open while using Claude Code."
echo "Press Ctrl+C or run ./stop.sh to shut down."
echo ""

PID_FILE="$CORE_DIR/.gateway.pid"

cleanup() {
    rm -f "$PID_FILE"
}
trap cleanup EXIT INT TERM

"$VENV_LITELLM" --config "$CORE_DIR/config.yaml" --host 127.0.0.1 --port "$GATEWAY_PORT" &
GATEWAY_PID=$!
echo "$GATEWAY_PID" > "$PID_FILE"
echo "Gateway running on PID $GATEWAY_PID"

wait "$GATEWAY_PID"
