#!/usr/bin/env bash
# Screenshots one area (outpost, factory, dump, ...) in a real web build, without
# touching the project: builds a throwaway copy whose main scene is that area.
# Output: test/e2e/out/preview_<area>_*.png. Needs the same tools as e2e.sh.
set -euo pipefail

area="${1:?usage: preview_area.sh <area>}"
cd "$(dirname "$0")/.."
game_dir="$PWD"
work="$(mktemp -d)"
trap 'kill "$server" 2>/dev/null || true; rm -rf "$work"' EXIT

rsync -a --exclude export --exclude .git --exclude art_src --exclude test/e2e/node_modules ./ "$work/"
scene="res://world/${area}.tscn"
[[ "$area" == res://* ]] && scene="$area"
sed -i "s#^run/main_scene=.*#run/main_scene=\"${scene}\"#" "$work/project.godot"
sed -i 's#^exclude_filter=.*#exclude_filter="addons/gut/*"#' "$work/export_presets.cfg"
(cd "$work" && mkdir -p export/web && godot --headless --import --quit >/dev/null 2>&1 || true
 godot --headless --export-release "Web" export/web/index.html >/dev/null 2>&1)

port="${PORT:-8766}"
python3 -m http.server "$port" --bind 127.0.0.1 --directory "$work/export/web" >/dev/null 2>&1 &
server=$!
sleep 1
script=preview.mjs
[[ "$area" == res://test/e2e/ui_preview.tscn ]] && script=ui_shots.mjs
(cd test/e2e && GAME_URL="http://127.0.0.1:$port/index.html" AREA="${area##*/}" OUT_DIR="$game_dir/test/e2e/out" node "$script")
echo "screenshots written to test/e2e/out"
