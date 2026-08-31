#!/usr/bin/env bash
set -e

# Mentra One-Click Local Development Launcher
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "================================================="
echo "   🧠 MENTRA — AI STUDY COACH (DEV RUNNER)       "
echo "================================================="

# 1. Check Docker & Start Containers
echo "⚙️  1/3 Checking Database (PostgreSQL & Redis)..."
if ! docker info >/dev/null 2>&1; then
  echo "🚀 Launching Docker Desktop..."
  open -a Docker || true
  while ! docker info >/dev/null 2>&1; do
    sleep 1
  done
fi

docker compose -f "$ROOT_DIR/infrastructure/docker/docker-compose.yml" up -d
echo "✅ Database is running on localhost:5432"

# 2. Start FastAPI Backend in background
echo "⚙️  2/3 Starting Mentra Backend API..."
cd "$ROOT_DIR/backend"
source .venv/bin/activate
uvicorn app.main:app --port 8000 --reload &
BACKEND_PID=$!
echo "✅ Backend API running at http://127.0.0.1:8000 (PID: $BACKEND_PID)"

# Clean shutdown handler on CTRL+C
cleanup() {
  echo ""
  echo "🛑 Stopping Mentra development environment..."
  kill "$BACKEND_PID" 2>/dev/null || true
  exit 0
}
trap cleanup SIGINT SIGTERM EXIT

# 3. Determine best Flutter target (Chrome if Xcode is missing)
cd "$ROOT_DIR/apps/mentra"

if [ -n "$1" ]; then
  TARGET_DEVICE="$1"
elif which xcodebuild >/dev/null 2>&1 && xcode-select -p >/dev/null 2>&1; then
  TARGET_DEVICE="macos"
else
  TARGET_DEVICE="chrome"
fi

echo "⚙️  3/3 Launching Mentra App on: $TARGET_DEVICE..."
flutter run -d "$TARGET_DEVICE"
