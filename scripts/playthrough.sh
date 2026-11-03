#!/usr/bin/env bash
# Plays the whole game in a real browser (Playwright + Chromium) against a
# throwaway web build that carries a test-only driver hook. The shipped project
# is not modified. Output: PASS/FAIL lines and screenshots in test/e2e/out/play_*.png.
set -euo pipefail

cd "$(dirname "$0")/.."
game_dir="$PWD"
work="$(mktemp -d)"
trap 'kill "$server" 2>/dev/null || true; rm -rf "$work"' EXIT

rsync -a --exclude export --exclude .git --exclude art_src --exclude test/e2e/node_modules ./ "$work/"
sed -i 's#^exclude_filter=.*#exclude_filter="addons/gut/*"#' "$work/export_presets.cfg"
sed -i 's#^Polish=.*#&\nE2EDriver="*res://test/e2e/e2e_driver.gd"#' "$work/project.godot"
(cd "$work" && mkdir -p export/web && godot --headless --import --quit >/dev/null 2>&1 || true
 godot --headless --export-release "Web" export/web/index.html >/dev/null 2>&1)

port="${PORT:-8767}"
python3 -m http.server "$port" --bind 127.0.0.1 --directory "$work/export/web" >/dev/null 2>&1 &
server=$!
sleep 1
cd test/e2e
GAME_URL="http://127.0.0.1:$port/index.html" OUT_DIR="$game_dir/test/e2e/out" node playthrough.mjs
