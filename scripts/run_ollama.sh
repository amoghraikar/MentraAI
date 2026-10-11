#!/usr/bin/env bash
# Mentra Ollama Supervisor
# Ensures Ollama is always running on port 11434 without colliding if already active.

OLLAMA_BIN="/Applications/Ollama.app/Contents/Resources/ollama"
if [ ! -x "$OLLAMA_BIN" ]; then
  OLLAMA_BIN="$(command -v ollama || true)"
fi

while true; do
  if curl -s -m 2 http://127.0.0.1:11434/api/tags >/dev/null 2>&1; then
    sleep 10
  else
    if [ -x "$OLLAMA_BIN" ]; then
      "$OLLAMA_BIN" serve
    fi
    sleep 5
  fi
done
