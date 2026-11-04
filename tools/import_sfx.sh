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

SWISH="$SRC/swishes/swishes"
ZOMBIE="$SRC/zombies/zombies"

# Loudness targets (dB, loudest 50 ms window), by role, so every sound sits at
# the level its job needs: actions you trigger are clear, feedback is present,
# footsteps stay underneath. A sound is never pushed past -1 dB peak.
UI_LOUD=-13
FEEDBACK=-12
ACTION=-10
IMPACT=-9
VOICE=-12
WORLD=-12
STEPS=-24

# take <name> <source> <target dB> [max seconds] [extra sox effects...]
take() {
	local name="$1" source="$2" target="$3" length="${4:-2}"
	shift 4 || shift $#
	local raw="$SFX/.raw.wav"
	# One channel, not a mix: some packs' stereo halves are out of phase and
	# would cancel each other out in a mono mix. The fade-out is done on the
	# reversed sound: sox reads a "-0" stop position as the start, not the end,
	# which once cut every effect to its first few milliseconds.
	sox -V1 "$source" -r 22050 -c 1 -b 16 "$raw" remix 1 silence 1 0.002 -50d trim 0 "$length" "$@" fade h 0.002 reverse fade h 0.02 reverse
	local stats loud peak gain
	stats=$(sox "$raw" -n stats 2>&1)
	loud=$(awk '/RMS Pk dB/{print $4}' <<<"$stats")
	peak=$(awk '/Pk lev dB/{print $4}' <<<"$stats")
	# A sharp click or clang is all peak and little body: squeeze it first (a fast
	# compressor), so it can be as present as the rest without clipping.
	if awk -v t="$target" -v l="$loud" -v p="$peak" 'BEGIN { exit !((t - l) > (-1 - p) + 4) }'; then
		sox -V1 "$raw" "$SFX/.squeezed.wav" norm -1 compand 0.0005,0.06 6:-70,-70,-36,-14,-12,-6,0,-3 -1 -90 0.0005
		mv "$SFX/.squeezed.wav" "$raw"
		stats=$(sox "$raw" -n stats 2>&1)
		loud=$(awk '/RMS Pk dB/{print $4}' <<<"$stats")
		peak=$(awk '/Pk lev dB/{print $4}' <<<"$stats")
	fi
	gain=$(awk -v t="$target" -v l="$loud" -v p="$peak" 'BEGIN { g = t - l; c = -1 - p; print (g < c ? g : c) }')
	sox -V1 "$raw" "$SFX/$name.wav" gain "$gain"
	rm -f "$raw"
}

# Interface: a firm click for every button, a soft tick when the selection moves.
take click "$UI/toggle_002.ogg" $UI_LOUD 0.15
take ui_move "$UI/select_002.ogg" $((UI_LOUD - 8)) 0.1
take ui_back "$UI/back_002.ogg" $((UI_LOUD - 2)) 0.25
take menu_open "$UI/open_002.ogg" $((UI_LOUD - 2)) 0.35
take menu_close "$UI/close_002.ogg" $((UI_LOUD - 3)) 0.35
take task_done "$UI/confirmation_002.ogg" $FEEDBACK 0.6
take wrong "$UI/error_006.ogg" $FEEDBACK 0.5
take sort_bad "$UI/error_004.ogg" $FEEDBACK 0.3
take sort_ok "$UI/confirmation_001.ogg" $FEEDBACK 0.3
take denied "$UI/error_001.ogg" $((FEEDBACK - 4)) 0.25
take dial "$KENNEY/metalClick.ogg" $((UI_LOUD - 2)) 0.15
take unlock "$KENNEY/metalClick.ogg" $FEEDBACK 0.45
take card_flip "$KENNEY/bookFlip1.ogg" $((UI_LOUD - 2)) 0.3
take equip "$PACK/inventory/chainmail1.wav" $FEEDBACK 0.45
take bandage "$KENNEY/cloth2.ogg" $FEEDBACK 0.45

# World
take chest_open "$HUNDRED/wooded_box_open.ogg" $WORLD 0.5
take loot "$PACK/inventory/coin.wav" $FEEDBACK 0.5
take door_open "$KENNEY/doorOpen_1.ogg" $WORLD 0.9
take door_close "$KENNEY/doorClose_1.ogg" $((WORLD - 2)) 0.7
take generator_on "$HUNDRED/machine_01.ogg" $WORLD 0.6
take mine_hit "$RPG/item_stone_01.ogg" $IMPACT 0.4
take rock_break "$RPG/stones_02.ogg" $IMPACT 0.7
take dig "$V2/sfx100v2_wood_hit_01.ogg" $WORLD 0.35 pitch -400
take secret "$RPG/spell_02.ogg" $FEEDBACK 1.2

# Footsteps: soft outdoors, hollow wood indoors.
for i in 0 1 2 3; do
	take "step_$((i + 1))" "$KENNEY/footstep0$i.ogg" $STEPS 0.25
done
for i in 1 2 3; do
	take "step_wood_$i" "$V2/sfx100v2_footstep_wood_0$i.ogg" $STEPS 0.25
done

# Combat: three swishes (one is picked at random, slightly re-pitched, so
# repeated swings never sound mechanical), the guard coming up, and impacts.
take swing_1 "$SWISH/swish-3.wav" $ACTION 0.25
take swing_2 "$SWISH/swish-7.wav" $ACTION 0.25
take swing_3 "$SWISH/swish-5.wav" $ACTION 0.25
cp "$SFX/swing_1.wav" "$SFX/swing.wav"
take guard_up "$PACK/inventory/armor-light.wav" $((ACTION - 3)) 0.3
take hit "$KENNEY/knifeSlice2.ogg" $IMPACT 0.3
take hurt "$KENNEY/chop.ogg" $IMPACT 0.3
take block "$RPG/metal_02.ogg" $IMPACT 0.4
take parry "$V2/sfx100v2_metal_hit_01.ogg" $((IMPACT + 2)) 0.6
take flame "$RPG/spell_fire_01.ogg" $((ACTION - 4)) 0.35
take shotgun "$BANG/shot_01.ogg" $IMPACT 0.45
# The shotgun's two shells: a pump-rack as it reloads, a shell sliding home,
# and the hollow click of an empty gun.
take reload "$KENNEY/metalLatch.ogg" $ACTION 0.35
take shell_in "$PACK/inventory/metal-small2.wav" $((FEEDBACK - 2)) 0.25
take dry_fire "$HUNDRED/switch_02.ogg" $((FEEDBACK - 2)) 0.2

# The zombies: groans while they wander, a snarl when they spot you, a rasp
# as they wind up a swing (your cue to guard), and hurt and dying cries.
take zombie_groan_1 "$ZOMBIE/zombie-16.wav" $((VOICE - 6)) 1.5
take zombie_groan_2 "$ZOMBIE/zombie-17.wav" $((VOICE - 6)) 1.6
take zombie_groan_3 "$ZOMBIE/zombie-18.wav" $((VOICE - 6)) 1.2
take zombie_groan_4 "$ZOMBIE/zombie-21.wav" $((VOICE - 6)) 1.2
take zombie_alert_1 "$ZOMBIE/zombie-2.wav" $VOICE 0.8
take zombie_alert_2 "$ZOMBIE/zombie-8.wav" $VOICE 0.85
take zombie_attack_1 "$ZOMBIE/zombie-6.wav" $VOICE 0.55
take zombie_attack_2 "$ZOMBIE/zombie-10.wav" $VOICE 0.7
take zombie_attack_3 "$ZOMBIE/zombie-14.wav" $VOICE 0.7
take enemy_hurt_1 "$ZOMBIE/zombie-5.wav" $((VOICE - 2)) 0.5
take enemy_hurt_2 "$ZOMBIE/zombie-11.wav" $((VOICE - 2)) 0.5
take enemy_hurt_3 "$ZOMBIE/zombie-24.wav" $((VOICE - 2)) 0.35
cp "$SFX/enemy_hurt_1.wav" "$SFX/enemy_hurt.wav"
take enemy_die "$ZOMBIE/zombie-12.wav" $VOICE 0.8 pitch -200

# Low health: two soft heart thumps, repeated by the game while health is low.
sox -V1 -n -r 22050 -c 1 -b 16 "$SFX/.beat.wav" synth 0.09 sine 55 fade q 0.005 0.09 0.07
sox -V1 "$SFX/.beat.wav" "$SFX/.beat.wav" "$SFX/heartbeat.wav" pad 0 0.08 lowpass 300 norm -8
rm -f "$SFX/.beat.wav"

# The generator coming back to life: a machine clunk, then a hum that rises
# in pitch as it spins up, then settles.
sox -V1 -n -r 22050 -c 1 -b 16 "$SFX/.hum.wav" synth 1.8 sawtooth 45:110 sawtooth 90:220 vol 0.5 lowpass 900 tremolo 9 30 fade h 0.3 1.8 0.7 norm -8
sox "$SFX/generator_on.wav" "$SFX/.hum.wav" "$SFX/generator_start.wav" splice -q 0.45,0.05 norm -2
rm -f "$SFX/.hum.wav"

# A dialogue voice: a short, round "bup" (a sine with a little triangle for body).
# The game pitches it per speaker, so one sound gives everyone their own voice.
sox -V1 -n -r 22050 -c 1 -b 16 "$SFX/voice.wav" synth 0.06 sine 330 triangle 495 vol 0.5 fade q 0.004 0.06 0.05 lowpass 2400 norm -9

echo "imported CC0 sound effects into $SFX"
