#!/usr/bin/env bash
# Runs the GUT unit and integration tests headless.
# Exits non-zero on a failing test AND on a script that failed to load: GUT
# alone only warns about the latter and would otherwise report a green run.
set -uo pipefail

cd "$(dirname "$0")/.."

# Registers global classes (including GUT's) when .godot/ is missing or stale.
godot --headless --import --quit >/dev/null 2>&1 || true

output=$(godot --headless -s addons/gut/gut_cmdln.gd -gconfig=res://.gutconfig.json "$@" 2>&1)
status=$?
printf '%s\n' "$output"

if grep -qE "SCRIPT ERROR|Parse Error|Ignoring script" <<<"$output"; then
	echo "test.sh: a script failed to load or compile; failing the run" >&2
	exit 1
fi
exit "$status"
