#!/usr/bin/env bash
# ==============================================================================
# Universal Claude Code LLM Gateway - Linux / macOS Setup Script
# ==============================================================================

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CORE_DIR="$PROJECT_DIR/core"
cd "$PROJECT_DIR"

echo ""
echo "======================================================="
echo "   Claude Code Universal LLM Gateway - Setup (Linux/macOS)"
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

# 3. Launch interactive configuration wizard
echo "[SETUP] Launching Interactive Configuration Wizard..."
echo ""
"$VENV_PYTHON" "$CORE_DIR/configure.py"

# 4. Register gateway directory
echo "$PROJECT_DIR" > "$HOME/.claude-gateway-root"

echo ""
echo "======================================================="
echo "                   Setup Completed!"
echo "======================================================="
echo "Next steps:"
echo "  1. Start the gateway server : ./start.sh"
echo "  2. Test your model backend  : ./test.sh"
echo "  3. Launch Claude Code       : ./claude.sh (from any folder!)"
echo ""
