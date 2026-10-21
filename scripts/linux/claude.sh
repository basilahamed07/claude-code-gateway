#!/usr/bin/env bash
# ==============================================================================
# Universal Claude Code LLM Gateway - Linux / macOS Launcher
# Can be run from here or copied to any project folder on your system.
# ==============================================================================

GATEWAY_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Check parent folder if run from inside scripts/linux
if [ -f "$GATEWAY_DIR/../../.env" ]; then
    GATEWAY_DIR="$(cd "$GATEWAY_DIR/../.." && pwd)"
fi

# --- Gateway Discovery ---
if [ ! -f "$GATEWAY_DIR/.env" ]; then
    if [ -n "$CLAUDE_GATEWAY_DIR" ] && [ -f "$CLAUDE_GATEWAY_DIR/.env" ]; then
        GATEWAY_DIR="$CLAUDE_GATEWAY_DIR"
    elif [ -f "$HOME/.claude-gateway-root" ]; then
        SAVED_DIR="$(cat "$HOME/.claude-gateway-root" | tr -d '[:space:]')"
        if [ -f "$SAVED_DIR/.env" ]; then
            GATEWAY_DIR="$SAVED_DIR"
        fi
    fi
fi

if [ ! -f "$GATEWAY_DIR/.env" ]; then
    echo "[ERROR] Could not locate the gateway's \".env\" file."
    echo "If you copied this script to another folder, either:"
    echo "  1. Run setup.sh or start.sh once from the gateway directory to register it."
    echo "  2. Or export CLAUDE_GATEWAY_DIR=\"/path/to/claude-code-gateway\""
    exit 40
fi

# 1. Dynamically locate Claude Code executable
CLAUDE_EXE="${CLAUDE_PATH:-}"

if [ -z "$CLAUDE_EXE" ] && command -v claude >/dev/null 2>&1; then
    CLAUDE_EXE="$(command -v claude)"
fi

if [ -z "$CLAUDE_EXE" ] && [ -f "$HOME/.npm-global/bin/claude" ]; then
    CLAUDE_EXE="$HOME/.npm-global/bin/claude"
fi

if [ -z "$CLAUDE_EXE" ] && [ -f "/usr/local/bin/claude" ]; then
    CLAUDE_EXE="/usr/local/bin/claude"
fi

if [ -z "$CLAUDE_EXE" ]; then
    echo "[ERROR] Claude Code CLI was not found."
    echo "Please install it globally via: npm install -g @anthropic-ai/claude-code"
    echo "Or set CLAUDE_PATH=/path/to/claude in your environment."
    exit 41
fi

# 2. Load gateway settings from .env
set -a
# shellcheck disable=SC1091
source "$GATEWAY_DIR/.env"
set +a

GATEWAY_PORT="${GATEWAY_PORT:-4000}"
GATEWAY_MODEL_ALIAS="${GATEWAY_MODEL_ALIAS:-custom-model}"

if [ -z "$GATEWAY_MASTER_KEY" ]; then
    echo "[ERROR] GATEWAY_MASTER_KEY is missing from .env."
    exit 42
fi

# 3. Port Selection (Supports multiple running servers)
PORT_OVERRIDE=""

# Check CLI arguments for --port <P>
ARGS=()
while [[ $# -gt 0 ]]; do
    case "$1" in
        --port)
            PORT_OVERRIDE="$2"
            shift 2
            ;;
        *)
            ARGS+=("$1")
            shift
            ;;
    esac
done

if [ -z "$PORT_OVERRIDE" ] && [ -n "$CLAUDE_PORT" ]; then
    PORT_OVERRIDE="$CLAUDE_PORT"
fi

if [ -z "$PORT_OVERRIDE" ] && [ -t 0 ]; then
    echo ""
    read -r -p "Which Gateway Port is your LLM listening on? [$GATEWAY_PORT]: " INPUT_PORT
    if [ -n "$INPUT_PORT" ]; then
        PORT_OVERRIDE="$INPUT_PORT"
    fi
fi

if [ -n "$PORT_OVERRIDE" ]; then
    GATEWAY_PORT="$PORT_OVERRIDE"
fi

echo "[CONNECT] Connecting to Gateway on port $GATEWAY_PORT..."

# 4. Check if local gateway proxy is reachable and discover active model
if command -v curl >/dev/null 2>&1; then
    HTTP_RESP=$(curl -s -H "Authorization: Bearer $GATEWAY_MASTER_KEY" "http://127.0.0.1:$GATEWAY_PORT/v1/models" || true)
    if [ -z "$HTTP_RESP" ]; then
        echo "[ERROR] Gateway is not running or rejected the key at http://127.0.0.1:$GATEWAY_PORT/v1/models"
        echo "Please start the gateway first: $GATEWAY_DIR/start.sh $GATEWAY_PORT"
        exit 45
    fi
    # If Python is available, discover model name
    if command -v python3 >/dev/null 2>&1; then
        DISCOVERED=$(python3 -c "import json, sys; data=json.loads(sys.argv[1]); models=[m['id'] for m in data.get('data', [])]; alias=sys.argv[2]; print(alias if alias in models else (models[0] if models else alias))" "$HTTP_RESP" "$GATEWAY_MODEL_ALIAS" 2>/dev/null || echo "$GATEWAY_MODEL_ALIAS")
        if [ -n "$DISCOVERED" ]; then
            GATEWAY_MODEL_ALIAS="$DISCOVERED"
        fi
    fi
fi

echo "[CONNECT] Connected! Active Model: $GATEWAY_MODEL_ALIAS"
echo ""

# 5. Set process-scoped Anthropic environment variables
export ANTHROPIC_BASE_URL="http://127.0.0.1:$GATEWAY_PORT"
export ANTHROPIC_AUTH_TOKEN="$GATEWAY_MASTER_KEY"
export ANTHROPIC_MODEL="$GATEWAY_MODEL_ALIAS"
export ANTHROPIC_DEFAULT_SONNET_MODEL="$GATEWAY_MODEL_ALIAS"
export ANTHROPIC_DEFAULT_OPUS_MODEL="$GATEWAY_MODEL_ALIAS"
export ANTHROPIC_DEFAULT_HAIKU_MODEL="$GATEWAY_MODEL_ALIAS"

unset ANTHROPIC_API_KEY
export CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY=1
export CLAUDE_CODE_DISABLE_EXPERIMENTAL_BETAS=1
export CLAUDE_CODE_DISABLE_ADAPTIVE_THINKING=1
export CLAUDE_CODE_ATTRIBUTION_HEADER=0

# 6. Launch Claude Code preserving all arguments
exec "$CLAUDE_EXE" "${ARGS[@]}"
