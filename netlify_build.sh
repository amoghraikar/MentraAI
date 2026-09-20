#!/usr/bin/env bash
set -e

echo "==========================================="
echo "  MENTRA — Netlify Automated Build"
echo "==========================================="

FLUTTER_CHANNEL="stable"

# Check if flutter is already installed
if command -v flutter &> /dev/null; then
  echo "✓ Flutter is already present in PATH:"
  flutter --version
else
  echo "→ Downloading Flutter SDK ($FLUTTER_CHANNEL)..."
  if [ ! -d "$HOME/flutter" ]; then
    git clone https://github.com/flutter/flutter.git --depth 1 -b $FLUTTER_CHANNEL "$HOME/flutter"
  fi
  export PATH="$HOME/flutter/bin:$PATH"
  echo "✓ Installed Flutter:"
  flutter --version
fi

# Disable analytics and precache web artifacts
flutter config --no-analytics
flutter precache --web

# Navigate to Flutter project directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
if [ -f "$SCRIPT_DIR/pubspec.yaml" ]; then
  cd "$SCRIPT_DIR"
elif [ -d "$SCRIPT_DIR/apps/mentra" ]; then
  cd "$SCRIPT_DIR/apps/mentra"
else
  echo "Error: Could not locate apps/mentra directory!"
  exit 1
fi

echo "→ Resolving dependencies..."
flutter pub get

echo "→ Compiling Mentra Web Release..."
flutter build web --release --base-href /

# Ensure Netlify SPA routing file is present
cp -f web/_redirects build/web/_redirects 2>/dev/null || true

echo "==========================================="
echo "  ✓ Mentra Web Build Succeeded!"
echo "  Output directory: $(pwd)/build/web"
echo "==========================================="
