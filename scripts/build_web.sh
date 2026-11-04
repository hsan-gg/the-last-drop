#!/usr/bin/env bash
# Builds the deployable web version of the game.
#
#   build/web/                    upload this folder to any static host
#   build/the-last-drop-web.zip   the same, zipped, for itch.io
#
# The build is single-threaded, so it needs no special server headers
# (no SharedArrayBuffer / cross-origin isolation) and runs on GitHub Pages,
# Netlify, Vercel, Cloudflare Pages and itch.io as is. It is also an
# installable app (PWA) that plays offline once loaded.
# Needs Godot 4.7 on PATH (or GODOT=/path/to/godot) with its web export templates.
set -euo pipefail

cd "$(dirname "$0")/.."
godot="${GODOT:-godot}"
out="build/web"

rm -rf "$out" build/the-last-drop-web.zip
mkdir -p "$out"
"$godot" --headless --import --quit >/dev/null 2>&1 || true
"$godot" --headless --export-release "Web" "$out/index.html"
test -s "$out/index.wasm" || { echo "export failed: no index.wasm" >&2; exit 1; }

cp deploy/_headers "$out/_headers"
cp deploy/vercel.json "$out/vercel.json"
touch "$out/.nojekyll"  # GitHub Pages: serve the files as they are

(cd "$out" && zip -qr ../the-last-drop-web.zip . -x vercel.json -x _headers -x .nojekyll)
du -sh "$out" build/the-last-drop-web.zip
