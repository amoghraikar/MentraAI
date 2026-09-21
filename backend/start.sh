#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# Mentra Backend — Bulletproof Startup Script with Auto-Restart Watchdog
# ---------------------------------------------------------------------------
# Usage:
#   ./backend/start.sh            # starts on default port 8000
#   PORT=9000 ./backend/start.sh  # custom port
# ---------------------------------------------------------------------------
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

VENV_PYTHON="$SCRIPT_DIR/.venv/bin/python"
PORT="${PORT:-8000}"
HOST="${HOST:-127.0.0.1}"
LOG_LEVEL="${LOG_LEVEL:-info}"
MAX_RESTARTS=20
RESTART_DELAY=3

# Verify virtualenv exists
if [[ ! -f "$VENV_PYTHON" ]]; then
    echo "[mentra] ERROR: Backend virtualenv not found at $VENV_PYTHON"
    echo "[mentra] Run: cd backend && python3 -m venv .venv && .venv/bin/pip install -r requirements.txt"
    exit 1
fi

CV_ENGINE_DIR="$SCRIPT_DIR/../cv-engine"
if [[ ! -d "$CV_ENGINE_DIR/src" ]]; then
    echo "[mentra] WARNING: cv-engine/src not found at $CV_ENGINE_DIR — CV endpoints will be degraded"
fi

echo "[mentra] Starting Mentra backend on $HOST:$PORT"
echo "[mentra] Python: $VENV_PYTHON"
echo "[mentra] Auto-restart enabled (max=$MAX_RESTARTS, delay=${RESTART_DELAY}s)"

restart_count=0

while true; do
    "$VENV_PYTHON" -m uvicorn app.main:app \
        --host "$HOST" \
        --port "$PORT" \
        --log-level "$LOG_LEVEL" \
        --timeout-keep-alive 30 \
        --access-log

    EXIT_CODE=$?

    if [[ $EXIT_CODE -eq 0 ]]; then
        echo "[mentra] Server exited cleanly. Stopping watchdog."
        break
    fi

    restart_count=$((restart_count + 1))
    if [[ $restart_count -ge $MAX_RESTARTS ]]; then
        echo "[mentra] FATAL: Server crashed $restart_count times. Giving up."
        exit 1
    fi

    echo "[mentra] Server exited with code $EXIT_CODE (restart $restart_count/$MAX_RESTARTS). Restarting in ${RESTART_DELAY}s..."
    sleep "$RESTART_DELAY"
done
