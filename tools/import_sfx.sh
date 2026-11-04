#!/usr/bin/env bash
# Builds the game's sound effects from CC0 packs on OpenGameArt (see CREDITS.md),
# downloaded to art_src/sfx_cc0/. Each sound is converted to 22 kHz mono WAV,
# trimmed, faded and levelled so the mix stays even. Run from game/ after
# tools/generate_audio.sh (this overwrites the synthesised placeholders it
# replaces and leaves the others).
set -euo pipefail

cd "$(dirname "$0")/.."
SRC=art_src/sfx_cc0
SFX=assets/audio/sfx
[ -d "$SRC" ] || { echo "missing $SRC: download the packs listed in CREDITS.md" >&2; exit 1; }

UI="$SRC/kenney_interfaceSounds/Audio"
RPG="$SRC/80-CC0-RPG-SFX_0"
HUNDRED="$SRC/100-CC0-SFX_0"
V2="$SRC/sfx_100_v2"
KENNEY="$SRC/RPGsounds_Kenney/OGG"
BANG="$SRC/25-CC0-bang-sfx"
PACK="$SRC/rpg_sound_pack/RPG Sound Pack"

# take <name> <source> <gain dB> [max seconds] [extra sox effects...]
take() {
	local name="$1" source="$2" gain="$3" length="${4:-2}"
	shift 4 || shift $#
	sox -V1 "$source" -r 22050 -c 1 -b 16 "$SFX/$name.wav" norm -1 gain "$gain" trim 0 "$length" "$@" fade h 0.002 -0 0.02
}

# Interface
take click "$UI/click_002.ogg" 0 0.2
take ui_move "$UI/tick_002.ogg" -10 0.1
take ui_back "$UI/back_001.ogg" -8 0.2
take task_done "$UI/confirmation_002.ogg" -6 0.6
take wrong "$UI/error_006.ogg" -6 0.5
take sort_bad "$UI/error_004.ogg" -6 0.3
take sort_ok "$UI/confirmation_001.ogg" -8 0.3

# World
take chest_open "$HUNDRED/wooded_box_open.ogg" -3 0.5
take loot "$RPG/item_coins_01.ogg" -6 0.45
take door_open "$KENNEY/doorOpen_1.ogg" -4 0.9
take door_close "$KENNEY/doorClose_1.ogg" -5 0.7
take generator_on "$HUNDRED/machine_01.ogg" -3 0.6
take mine_hit "$RPG/item_stone_01.ogg" -5 0.4
take rock_break "$RPG/stones_01.ogg" -3 0.7
take dig "$V2/sfx100v2_wood_hit_01.ogg" -8 0.35 pitch -400
take secret "$RPG/spell_02.ogg" -6 1.2

# Combat
take swing "$PACK/battle/swing.wav" -7 0.25
take hit "$RPG/blade_01.ogg" -5 0.3
take enemy_hurt "$RPG/creature_hurt_01.ogg" -9 0.45
take enemy_die "$RPG/creature_die_01.ogg" -6 0.9
take hurt "$V2/sfx100v2_hit_01.ogg" -3 0.4
take block "$RPG/metal_01.ogg" -6 0.35
take parry "$V2/sfx100v2_metal_hit_01.ogg" -5 0.6
take flame "$RPG/spell_fire_01.ogg" -9 0.35
take shotgun "$BANG/shot_01.ogg" -3 0.45

# The generator coming back to life: a machine clunk, then a hum that rises
# in pitch as it spins up, then settles.
sox -V1 -n -r 22050 -c 1 -b 16 "$SFX/.hum.wav" synth 1.8 sawtooth 45:110 sawtooth 90:220 vol 0.5 lowpass 900 tremolo 9 30 fade h 0.3 1.8 0.7 norm -8
sox "$SFX/generator_on.wav" "$SFX/.hum.wav" "$SFX/generator_start.wav" splice -q 0.45,0.05 norm -2
rm -f "$SFX/.hum.wav"

# A dialogue voice: a short, round "bup" (a sine with a little triangle for body).
# The game pitches it per speaker, so one sound gives everyone their own voice.
sox -V1 -n -r 22050 -c 1 -b 16 "$SFX/voice.wav" synth 0.06 sine 330 triangle 495 vol 0.5 fade q 0.004 0.06 0.05 lowpass 2400 norm -9

echo "imported CC0 sound effects into $SFX"
