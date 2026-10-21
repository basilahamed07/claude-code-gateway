#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CORE_DIR="$PROJECT_DIR/core"
VENV_PYTHON="$CORE_DIR/.venv/bin/python"

if [ ! -f "$VENV_PYTHON" ]; then
    echo "[ERROR] Virtual environment not found. Run ./setup.sh first."
    exit 1
fi

set -a
# shellcheck disable=SC1091
source "$PROJECT_DIR/.env"
set +a

echo "Running gateway diagnostics..."
echo ""
"$VENV_PYTHON" "$CORE_DIR/test-connection.py"
