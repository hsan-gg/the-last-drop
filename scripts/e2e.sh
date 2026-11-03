#!/usr/bin/env bash
# Exports the web build, serves it, and runs the browser smoke test against it.
# Needs Godot web export templates, a Chromium install (CHROMIUM_PATH to override)
# and `npm install` once in test/e2e.
set -euo pipefail

cd "$(dirname "$0")/.."
PORT="${PORT:-8765}"

rm -rf export/web && mkdir -p export/web
godot --headless --export-release "Web" export/web/index.html

python3 -m http.server "$PORT" --bind 127.0.0.1 --directory export/web >/dev/null 2>&1 &
server=$!
trap 'kill "$server" 2>/dev/null || true' EXIT
sleep 1

(cd test/e2e && GAME_URL="http://127.0.0.1:$PORT/index.html" OUT_DIR="$PWD/out" node web_smoke.mjs)
