#!/usr/bin/env bash
set -e

# Mentra One-Click Startup & Development Launcher
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "================================================="
echo "   🧠 MENTRA — AI STUDY COACH (DEV RUNNER)       "
echo "================================================="

# 1. Clean up any zombie processes occupying port 8000
echo "🧹 1/4 Checking Port 8000 for stale listeners..."
if lsof -ti :8000 >/dev/null 2>&1; then
  echo "Found process running on port 8000. Terminating stale process..."
  lsof -ti :8000 | xargs kill -9 2>/dev/null || true
  sleep 1
fi
echo "✅ Port 8000 is clean"

# 2. Database check (PostgreSQL/Docker or built-in SQLite fallback)
echo "⚙️  2/4 Checking Database..."
if docker info >/dev/null 2>&1; then
  echo "Docker detected. Starting PostgreSQL and Redis containers..."
  docker compose -f "$ROOT_DIR/infrastructure/docker/docker-compose.yml" up postgres redis -d 2>/dev/null || true
  echo "✅ PostgreSQL & Redis ready on localhost"
else
  echo "ℹ️  Docker not active. Mentra will automatically use the high-performance local SQLite database (mentra.db)."
fi

# 3. Setup and start FastAPI Backend
echo "⚙️  3/4 Starting Mentra Backend API..."
cd "$ROOT_DIR/backend"

if [ ! -d ".venv" ]; then
  echo "Creating Python virtual environment..."
  if command -v uv >/dev/null 2>&1; then
    uv venv .venv --python 3.11 || uv venv .venv
    uv pip install -r requirements.txt
  else
    python3 -m venv .venv
    source .venv/bin/activate
    pip install -r requirements.txt
  fi
fi

source .venv/bin/activate
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload &
BACKEND_PID=$!

# Wait for backend health
echo "Waiting for Backend API to become ready..."
for i in {1..15}; do
  if curl -s http://127.0.0.1:8000/health | grep -q '"status":"ok"'; then
    echo "✅ Backend API is live at http://127.0.0.1:8000 (PID: $BACKEND_PID)"
    break
  fi
  sleep 0.5
done

cleanup() {
  echo ""
  echo "🛑 Stopping Mentra development environment..."
  kill "$BACKEND_PID" 2>/dev/null || true
  exit 0
}
trap cleanup SIGINT SIGTERM EXIT

# 4. Launch Flutter Client
cd "$ROOT_DIR/apps/mentra"

if [ -n "$1" ]; then
  TARGET_DEVICE="$1"
elif xcrun xcodebuild -version >/dev/null 2>&1; then
  TARGET_DEVICE="macos"
else
  TARGET_DEVICE="chrome"
fi

echo "⚙️  4/4 Launching Mentra App on: $TARGET_DEVICE..."
flutter run -d "$TARGET_DEVICE"
