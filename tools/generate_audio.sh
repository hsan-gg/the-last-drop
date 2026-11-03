#!/usr/bin/env bash
# Synthesises placeholder sound effects and an ambient loop with sox.
# Run from the game/ folder:  bash tools/generate_audio.sh
# Replace any file with real audio under the same name and the game uses it.
set -euo pipefail

cd "$(dirname "$0")/.."
SFX=assets/audio/sfx
mkdir -p "$SFX"

synth() {
	local name="$1"
	shift
	sox -n -r 22050 -c 1 -b 16 "$SFX/$name.wav" synth "$@"
}

synth pickup 0.12 sine 600:1100 fade h 0.005 0.12 0.06 vol 0.5
synth sort_ok 0.3 sine 880 sine 1320 fade h 0.01 0.3 0.2 vol 0.35
synth sort_bad 0.3 square 120:90 fade h 0.005 0.3 0.15 vol 0.3
synth repair 0.5 sawtooth 220:660 lowpass 2000 fade h 0.01 0.5 0.3 vol 0.3
synth drink 0.3 sine 500:250 tremolo 25 fade h 0.01 0.3 0.15 vol 0.5
synth blip 0.025 square 520 vol 0.12
synth reveal 1.2 sine 220 sine 277 sine 330 fade h 0.2 1.2 0.6 vol 0.3
synth collapse 0.6 sine 180:40 fade h 0.01 0.6 0.4 vol 0.5
synth click 0.03 square 900 vol 0.2
# Combat
synth swing 0.14 whitenoise lowpass 2200 fade h 0.01 0.14 0.1 vol 0.25
synth hit 0.12 square 180:70 fade h 0.002 0.12 0.08 vol 0.4
synth block 0.18 square 700:480 sine 1400 fade h 0.002 0.18 0.14 vol 0.3
synth parry 0.3 sine 1500 sine 2250 fade h 0.002 0.3 0.25 vol 0.35
synth hurt 0.25 sawtooth 200:80 fade h 0.005 0.25 0.18 vol 0.35
synth enemy_die 0.4 sawtooth 160:30 lowpass 900 fade h 0.01 0.4 0.3 vol 0.4
synth level_up 0.7 sine 523 sine 659 sine 784 fade h 0.02 0.7 0.5 vol 0.3
synth loot 0.25 sine 700:1400 sine 1050 fade h 0.01 0.25 0.15 vol 0.3

# 24 s of brown noise; 0.25 Hz tremolo completes whole cycles so the loop is seamless.
sox -n -r 22050 -c 1 assets/audio/ambient.ogg synth 24 brownnoise lowpass 500 tremolo 0.25 40 vol 0.5

echo "audio written to assets/audio"
