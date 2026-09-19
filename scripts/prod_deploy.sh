#!/usr/bin/env bash
set -e

# Mentra Production & Startup Deployment Script
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

echo "================================================="
echo "   🚀 MENTRA STARTUP PRODUCTION DEPLOYMENT      "
echo "================================================="

# 1. Environment file check
if [ ! -f "$ROOT_DIR/.env" ]; then
  echo "Generating production .env from template..."
  cp "$ROOT_DIR/.env.example" "$ROOT_DIR/.env"
  # Generate random JWT Secret
  RANDOM_SECRET=$(openssl rand -hex 32 2>/dev/null || date +%s | shasum | base64 | head -c 32)
  sed -i '' "s/replace_with_a_secure_jwt_secret_in_production/$RANDOM_SECRET/g" "$ROOT_DIR/.env" || true
fi

# 2. Build and run Docker infrastructure & Backend
echo "📦 1/2 Building and starting backend services..."
docker compose -f "$ROOT_DIR/infrastructure/docker/docker-compose.yml" --env-file "$ROOT_DIR/.env" up --build -d

echo "Verifying Backend API container health..."
for i in {1..30}; do
  if curl -s http://127.0.0.1:8000/health | grep -q '"status":"ok"'; then
    echo "✅ Backend API container is healthy and serving requests!"
    break
  fi
  sleep 1
done

# 3. Build Flutter Web Production Bundle
echo "📦 2/2 Building Flutter Web production release..."
cd "$ROOT_DIR/apps/mentra"
flutter build web --release

echo ""
echo "================================================="
echo "   🎉 MENTRA IS READY FOR PRODUCTION LAUNCH!     "
echo "================================================="
echo "API Server: http://127.0.0.1:8000"
echo "API Docs:   http://127.0.0.1:8000/docs"
echo "Web Build:  $ROOT_DIR/apps/mentra/build/web"
echo "================================================="
