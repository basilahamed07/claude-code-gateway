#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
CORE_DIR="$PROJECT_DIR/core"
PID_FILE="$CORE_DIR/.gateway.pid"
STOP_PORT="${1:-}"

STOPPED=0

if [ -f "$PID_FILE" ]; then
    PID=$(cat "$PID_FILE")
    if [ -n "$PID" ] && kill -0 "$PID" 2>/dev/null; then
        kill "$PID" 2>/dev/null || true
        echo "Stopped gateway process PID $PID"
        STOPPED=1
    fi
    rm -f "$PID_FILE"
fi

# If a port was specified or if PID was not found, find litellm on that port
if [ -n "$STOP_PORT" ] && command -v lsof >/dev/null 2>&1; then
    PORT_PID=$(lsof -ti :"$STOP_PORT" 2>/dev/null || true)
    if [ -n "$PORT_PID" ]; then
        kill "$PORT_PID" 2>/dev/null || true
        echo "Stopped process on port $STOP_PORT PID $PORT_PID"
        STOPPED=1
    fi
fi

if [ "$STOPPED" -eq 0 ]; then
    echo "No active gateway process found."
fi

echo "Done."
