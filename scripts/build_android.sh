#!/usr/bin/env bash
# Builds the Android app (APK) into build/android/.
#
# Without release keys it builds a debug APK, signed with the standard Android
# debug key (made on first use), for testing and sideloading:
#   bash scripts/build_android.sh
#   adb install -r build/android/the-last-drop-debug.apk
#
# For a release build (sideloading for others, or an app store), point these at
# your own keystore. Keep the keystore and its password out of git:
#   GODOT_ANDROID_KEYSTORE_RELEASE_PATH=~/keys/lastdrop.keystore \
#   GODOT_ANDROID_KEYSTORE_RELEASE_USER=lastdrop \
#   GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD=... \
#   bash scripts/build_android.sh
#
# Needs: Godot 4.7 with its Android export templates, the Android SDK
# (ANDROID_HOME, default /opt/android-sdk) with "platforms;android-36" and
# "build-tools;36.1.0", and a JDK 17. It is a Gradle build: the template is
# unpacked into android/build/ (not in git) and our own Android code from
# android/overlay/ is laid over it (the volume buttons, see GodotApp.java).
set -euo pipefail

cd "$(dirname "$0")/.."
godot="${GODOT:-godot}"
templates="$HOME/.local/share/godot/export_templates/$("$godot" --version | sed -E 's/^([0-9.]+\.[a-z]+).*/\1/')"
if [[ ! -f android/.build_version ]] || ! cmp -s android/.build_version "$templates/version.txt"; then
	rm -rf android/build
	mkdir -p android/build
	unzip -q "$templates/android_source.zip" -d android/build
	cp "$templates/version.txt" android/.build_version
	touch android/build/.gdignore
fi
cp -r android/overlay/. android/build/
export GODOT_ANDROID_SDK_PATH="${GODOT_ANDROID_SDK_PATH:-${ANDROID_HOME:-/opt/android-sdk}}"
mkdir -p build/android

if [[ -n "${GODOT_ANDROID_KEYSTORE_RELEASE_PATH:-}" ]]; then
	out="build/android/the-last-drop.apk"
	mode="--export-release"
else
	debug_store="${GODOT_ANDROID_KEYSTORE_DEBUG_PATH:-$HOME/.local/share/godot/keystores/debug.keystore}"
	if [[ ! -f "$debug_store" ]]; then
		mkdir -p "$(dirname "$debug_store")"
		# The well-known Android debug key: not a secret, only for test builds.
		keytool -genkeypair -v -keystore "$debug_store" -storepass android -alias androiddebugkey \
			-keypass android -keyalg RSA -keysize 2048 -validity 10000 \
			-dname "CN=Android Debug,O=Android,C=US" >/dev/null 2>&1
	fi
	export GODOT_ANDROID_KEYSTORE_DEBUG_PATH="$debug_store"
	export GODOT_ANDROID_KEYSTORE_DEBUG_USER="${GODOT_ANDROID_KEYSTORE_DEBUG_USER:-androiddebugkey}"
	export GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD="${GODOT_ANDROID_KEYSTORE_DEBUG_PASSWORD:-android}"
	out="build/android/the-last-drop-debug.apk"
	mode="--export-debug"
fi

rm -f "$out"
"$godot" --headless --import --quit >/dev/null 2>&1 || true
"$godot" --headless "$mode" "Android" "$out"
test -s "$out" || { echo "export failed: no $out" >&2; exit 1; }
du -h "$out"
