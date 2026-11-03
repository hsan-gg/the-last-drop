#!/usr/bin/env python3
"""Composes the game's music and writes assets/audio/music/*.ogg (sox does the
ogg step). Run from game/:  python3 tools/generate_music.py [track ...]

The aim is the warm, acoustic feel of Stardew Valley's score, not chiptune:
instruments are modelled additively (each harmonic decays at its own rate, the
way a plucked string or a struck piano string does), with an FM electric
piano, a breathy flute, string ensembles, accordion reeds and brushed or
taiko percussion. Everything goes through a stereo convolution reverb.

Each track is a small composition: a key, a mood, a chord progression per
section (intro, A, B, A'), a melody built from motifs that repeat and answer
each other and land on chord tones at phrase ends, and humanised timing and
dynamics. Loops are seamless: notes that ring past the end wrap to the start,
and the reverb is circular.
"""
import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

SR = 32000
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio" / "music"

MAJOR = [0, 2, 4, 5, 7, 9, 11]
MINOR = [0, 2, 3, 5, 7, 8, 10]
QUALITIES = {"M": [0, 4, 7], "m": [0, 3, 7], "M7": [0, 4, 7, 11], "m7": [0, 3, 7, 10],
             "7": [0, 4, 7, 10], "sus": [0, 5, 7], "add9": [0, 4, 7, 14], "dim": [0, 3, 6]}
NOTE = {"C": 0, "C#": 1, "Db": 1, "D": 2, "Eb": 3, "E": 4, "F": 5, "F#": 6, "Gb": 6, "G": 7, "Ab": 8, "A": 9, "Bb": 10, "B": 11}


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12.0)


def chord(name, octave=3):
    """'Am7' -> (root midi, [intervals]); 'G/B' keeps the bass note B."""
    bass = None
    if "/" in name:
        name, bass = name.split("/")
    root_name = name[:2] if len(name) > 1 and name[1] in "#b" else name[:1]
    quality = name[len(root_name):] or "M"
    root = 12 * (octave + 1) + NOTE[root_name]
    bass_midi = 12 * (octave + 1) + NOTE[bass] if bass else root
    if bass_midi > root:
        bass_midi -= 12
    return root, QUALITIES[quality], bass_midi


# ------------------------------------------------------------------ instruments

def _t(seconds):
    return np.arange(int(seconds * SR)) / SR


def _attack(sig, seconds):
    n = min(int(seconds * SR), len(sig))
    if n:
        sig[:n] *= np.linspace(0.0, 1.0, n) ** 1.5
    return sig


def _release(sig, seconds):
    n = min(int(seconds * SR), len(sig))
    if n:
        sig[-n:] *= np.linspace(1.0, 0.0, n)
    return sig


def additive(freq, seconds, partials, ring=1.5, inharm=0.0, attack=0.003):
    """partials: list of (amplitude, decay per second) for harmonics 1..n."""
    t = _t(seconds + ring)
    out = np.zeros_like(t)
    for k, (amp, decay) in enumerate(partials, start=1):
        f = freq * k * np.sqrt(1 + inharm * k * k)
        if f > SR * 0.45:
            break
        out += amp * np.sin(2 * np.pi * f * t + k) * np.exp(-decay * t)
    return _release(_attack(out, attack), 0.05)


def harp(midi, seconds, vel=0.8):
    p = [(1 / k ** 1.3, 1.2 + 0.9 * k) for k in range(1, 9)]
    return additive(hz(midi), seconds, p, ring=2.0) * vel


def guitar(midi, seconds, vel=0.8):
    # plucked a fifth of the way along the string: a comb in the harmonics
    p = [(abs(np.sin(np.pi * k * 0.2)) / k, 1.8 + 0.7 * k) for k in range(1, 12)]
    return additive(hz(midi), seconds, p, ring=1.2, inharm=0.00002) * vel


def piano(midi, seconds, vel=0.8):
    f = hz(midi)
    p = [(1 / k ** 1.4, 0.6 + 0.5 * k + (midi - 48) * 0.02) for k in range(1, 11)]
    body = additive(f, seconds, p, ring=1.6, inharm=0.0003)
    t = np.arange(len(body)) / SR
    hold = np.where(t < seconds, 1.0, np.exp(-(t - seconds) * 6.0))  # the damper falls on release
    hammer = np.random.default_rng(midi).normal(0, 1, len(body)) * np.exp(-t * 60) * 0.02
    return (body * hold + hammer) * vel


def epiano(midi, seconds, vel=0.8):
    f = hz(midi)
    t = _t(seconds + 1.0)
    index = 2.2 * np.exp(-t * 4.0) + 0.25
    tone = np.sin(2 * np.pi * f * t + index * np.sin(2 * np.pi * f * t))
    tine = 0.08 * np.sin(2 * np.pi * f * 14 * t) * np.exp(-t * 20)
    env = np.exp(-t * 1.2) * np.where(t < seconds, 1.0, np.exp(-(t - seconds) * 5.0))
    return _attack((tone + tine) * env, 0.004) * vel


def flute(midi, seconds, vel=0.7):
    f = hz(midi)
    t = _t(seconds + 0.25)
    vibrato = 1 + 0.004 * np.sin(2 * np.pi * 5.2 * t) * np.clip((t - 0.25) * 3, 0, 1)
    phase = 2 * np.pi * f * np.cumsum(vibrato) / SR
    tone = np.sin(phase) + 0.22 * np.sin(2 * phase) + 0.07 * np.sin(3 * phase)
    breath = _bandpass(np.random.default_rng(midi + 7).normal(0, 1, len(t)), f, f * 0.5) * 0.12
    env = np.where(t < seconds, 1.0, np.exp(-(t - seconds) * 18))
    return _attack((tone + breath) * env, 0.07) * vel


def strings(midi, seconds, vel=0.6, attack=0.35):
    t = _t(seconds + 0.6)
    out = np.zeros_like(t)
    for cents in (-7, -2, 3, 8):
        f = hz(midi) * 2 ** (cents / 1200)
        for k in range(1, 12):
            if f * k > SR * 0.45:
                break
            out += (1 / k) * np.exp(-k * 0.18) * np.sin(2 * np.pi * f * k * t + cents * k)
    env = np.where(t < seconds, 1.0, np.exp(-(t - seconds) * 5))
    return _attack(out * env / 4, attack) * vel


def accordion(midi, seconds, vel=0.6):
    t = _t(seconds + 0.15)
    out = np.zeros_like(t)
    for cents in (-4, 4):
        f = hz(midi) * 2 ** (cents / 1200)
        for k in (1, 2, 3, 4, 5, 6, 7):
            amp = (1 / k) if k % 2 else 0.35 / k
            out += amp * np.sin(2 * np.pi * f * k * t)
    tremolo = 1 + 0.08 * np.sin(2 * np.pi * 5.5 * t)
    env = np.where(t < seconds, 1.0, np.exp(-(t - seconds) * 25))
    return _attack(out * tremolo * env / 3, 0.04) * vel


def bass(midi, seconds, vel=0.8):
    p = [(1.0, 1.5), (0.5, 2.5), (0.25, 4.0), (0.12, 6.0)]
    return additive(hz(midi), seconds, p, ring=0.4, attack=0.006) * vel


def brass(midi, seconds, vel=0.7):
    t = _t(seconds + 0.1)
    bright = np.clip(t * 12, 0, 1)
    out = sum((1 / k) * np.sin(2 * np.pi * hz(midi) * k * t) * (bright if k > 2 else 1) for k in range(1, 9))
    env = np.where(t < seconds, 1.0, np.exp(-(t - seconds) * 30))
    return _attack(out * env / 2, 0.03) * vel


def _bandpass(noise, centre, width):
    spectrum = np.fft.rfft(noise)
    freqs = np.fft.rfftfreq(len(noise), 1 / SR)
    spectrum *= np.exp(-((freqs - centre) / max(width, 1.0)) ** 2)
    return np.fft.irfft(spectrum, len(noise))


def _noise(seconds, seed):
    return np.random.default_rng(seed).normal(0, 1, int(seconds * SR))


def kick(vel=0.9):
    t = _t(0.35)
    sweep = 2 * np.pi * np.cumsum(50 + 90 * np.exp(-t * 30)) / SR
    return np.sin(sweep) * np.exp(-t * 9) * vel


def brush(vel=0.5, seed=1):
    t = _t(0.3)
    return _bandpass(_noise(0.3, seed), 3500, 2500) * np.exp(-t * 14) * vel * 0.6


def shaker(vel=0.3, seed=2):
    t = _t(0.09)
    return _bandpass(_noise(0.09, seed), 8000, 3000) * np.exp(-t * 45) * vel * 0.5


def tick(vel=0.3):
    t = _t(0.05)
    return np.sin(2 * np.pi * 2400 * t) * np.exp(-t * 120) * vel


def taiko(vel=0.9, seed=3):
    t = _t(0.6)
    body = np.sin(2 * np.pi * (70 + 40 * np.exp(-t * 20)) * t) * np.exp(-t * 6)
    skin = _bandpass(_noise(0.6, seed), 400, 300) * np.exp(-t * 25) * 0.6
    return (body + skin) * vel


def tom(midi, vel=0.7):
    t = _t(0.4)
    return np.sin(2 * np.pi * hz(midi) * (1 + 0.3 * np.exp(-t * 25)) * t) * np.exp(-t * 9) * vel


INSTRUMENTS = {"harp": harp, "guitar": guitar, "piano": piano, "epiano": epiano, "flute": flute,
               "strings": strings, "accordion": accordion, "bass": bass, "brass": brass}


# ------------------------------------------------------------------ the score

class Track:
    def __init__(self, bpm, beats_per_bar, bars, seed, swing=0.0, loop=True):
        self.beat = 60.0 / bpm
        self.bpb = beats_per_bar
        self.bars = bars
        self.loop = loop
        self.n = int(round(bars * beats_per_bar * self.beat * SR))
        self.dry = np.zeros((2, self.n))
        self.wet = np.zeros((2, self.n))
        self.rng = np.random.default_rng(seed)
        self.swing = swing

    def put(self, beat, sig, pan=0.0, send=0.3, human=0.008):
        if self.swing and abs(beat * 2 - round(beat * 2)) < 1e-6 and round(beat * 2) % 2 == 1:
            beat += self.swing  # late off-beats: a lazy, swung feel
        start = int((beat * self.beat + self.rng.normal(0, human)) * SR)
        left, right = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
        for channel, gain in ((0, left), (1, right)):
            self._add(self.dry[channel], start, sig * gain)
            self._add(self.wet[channel], start, sig * gain * send)

    def _add(self, buffer, start, sig):
        start %= self.n
        end = start + len(sig)
        if end <= self.n:
            buffer[start:end] += sig
            return
        first = self.n - start
        buffer[start:] += sig[:first]
        if self.loop:
            rest = sig[first:]
            while len(rest):
                take = min(len(rest), self.n)
                buffer[:take] += rest[:take]
                rest = rest[take:]

    def note(self, instrument, beat, midi, beats, vel=0.8, pan=0.0, send=0.3):
        vel *= 1 + self.rng.normal(0, 0.06)
        self.put(beat, INSTRUMENTS[instrument](midi, beats * self.beat, vel), pan, send)

    def hit(self, sig, beat, pan=0.0, send=0.15):
        self.put(beat, sig * (1 + self.rng.normal(0, 0.08)), pan, send, human=0.004)

    def finish(self, room=2.2, wet=0.35):
        out = self.dry + wet * np.stack([_reverb(self.wet[c], room, seed=c + 11) for c in (0, 1)])
        out /= max(np.max(np.abs(out)), 1e-9)
        out = np.tanh(out * 1.3) * 0.86
        if not self.loop:
            fade = int(SR * 1.5)
            out[:, -fade:] *= np.linspace(1, 0, fade)
        return out


def _reverb(signal, room, seed):
    """Circular convolution with a decaying noise tail: a seamless hall."""
    n = len(signal)
    length = min(int(room * SR), n)
    t = np.arange(length) / SR
    ir = np.random.default_rng(seed).normal(0, 1, length) * np.exp(-t * 6.9 / room)
    ir = np.fft.irfft(np.fft.rfft(ir) * np.exp(-np.fft.rfftfreq(length, 1 / SR) / 4500), length)
    ir[: int(0.02 * SR)] = 0.0  # pre-delay
    padded = np.zeros(n)
    padded[:length] = ir
    return np.fft.irfft(np.fft.rfft(signal) * np.fft.rfft(padded), n) * 0.12


def tones(name, octave=3):
    root, intervals, bass_midi = chord(name, octave)
    return [root + i for i in intervals], bass_midi


def scale_notes(key, mode, low, high):
    base = NOTE[key]
    return [m for m in range(low, high + 1) if (m - base) % 12 in mode]


def compose_melody(rng, progression, key, mode, low, high, rhythms):
    """A melody over `progression` (one chord per bar), as [(beat, midi, beats)].

    Phrases are four bars. The second phrase starts by repeating the first's
    opening motif (re-fitted to its chords) and ends on the root for a cadence;
    strong beats land on chord tones and weak beats move by step, which is
    what makes a line singable."""
    scale = scale_notes(key, mode, low, high)
    notes, previous = [], scale[len(scale) // 2]
    phrase_rhythms = {}
    for bar, name in enumerate(progression):
        chord_pcs = {t % 12 for t in tones(name)[0]}
        targets = [m for m in scale if m % 12 in chord_pcs]
        phrase_bar = bar % 4
        rhythm = phrase_rhythms.get(phrase_bar % 2) if bar % 8 >= 4 and phrase_bar < 2 else None
        if rhythm is None:
            rhythm = rhythms[rng.integers(len(rhythms))]
            phrase_rhythms[phrase_bar % 2] = rhythm
        if phrase_bar == 3:  # end of phrase: a long note on a chord tone
            rhythm = [2.0, 2.0] if bar % 8 == 3 else [3.0, 1.0]
        beat = 0.0
        for index, length in enumerate(rhythm):
            strong = beat in (0.0, 2.0)
            if bar % 8 == 7 and index == len(rhythm) - 1:
                pool = [m for m in targets if m % 12 == NOTE[key]] or targets
            elif strong:
                pool = targets
            else:
                position = scale.index(min(scale, key=lambda m: abs(m - previous)))
                step = int(rng.choice([-2, -1, -1, 1, 1, 2]))
                pool = [scale[max(0, min(len(scale) - 1, position + step))]]
            pitch = min(pool, key=lambda m: abs(m - previous) + rng.random() * 2)
            if rng.random() < 0.08 and not strong:
                beat += length
                continue  # a breath
            notes.append((bar * 4 + beat, pitch, length * 0.95))
            previous = pitch
            beat += length
    return notes


RHYTHMS_GENTLE = [[1.5, 0.5, 1.0, 1.0], [1.0, 1.0, 2.0], [0.5, 0.5, 1.0, 2.0], [2.0, 1.0, 1.0]]
RHYTHMS_LIVELY = [[0.5, 0.5, 1.0, 0.5, 0.5, 1.0], [1.0, 0.5, 0.5, 1.0, 1.0], [0.75, 0.25, 1.0, 2.0]]


def arpeggio(t, bar, name, instrument, pattern, step, octave=4, vel=0.5, pan=0.0, beats_per_bar=4):
    chord_tones = tones(name, octave)[0]
    chord_tones += [n + 12 for n in chord_tones]
    beat = 0.0
    index = 0
    while beat < beats_per_bar - 1e-6:
        t.note(instrument, bar * beats_per_bar + beat, chord_tones[pattern[index % len(pattern)] % len(chord_tones)], step * 1.6, vel, pan)
        beat += step
        index += 1


def block_chord(t, bar, name, instrument, beats, octave=3, vel=0.35, pan=0.0, beats_per_bar=4, start=0.0):
    for i, n in enumerate(tones(name, octave)[0]):
        t.note(instrument, bar * beats_per_bar + start + i * 0.012, n, beats, vel, pan + (i - 1) * 0.15, send=0.45)


def play_melody(t, notes, instrument, offset_bars=0, vel=0.6, pan=0.1, transpose=0):
    for beat, midi, beats in notes:
        t.note(instrument, offset_bars * 4 + beat, midi + transpose, beats, vel, pan, send=0.4)


# ------------------------------------------------------------------ tracks

def title():
    """Hope on a hard morning: harp and flute in D major, strings in the B section."""
    t = Track(80, 4, 24, seed=1)
    intro = ["D", "Bm7", "G", "A"]
    a = ["D", "A/C#", "Bm", "G", "D", "A", "G", "A"]
    b = ["Em7", "A", "F#m", "Bm", "G", "A", "D", "D"]
    plan = intro + a + b + intro
    tune_a = compose_melody(t.rng, a, "D", MAJOR, 69, 88, RHYTHMS_GENTLE)
    tune_b = compose_melody(t.rng, b, "D", MAJOR, 71, 90, RHYTHMS_GENTLE)
    for bar, name in enumerate(plan):
        arpeggio(t, bar, name, "harp", [0, 1, 2, 3, 2, 1, 2, 3], 0.5, octave=4, vel=0.32, pan=-0.3)
        t.note("bass", bar * 4, tones(name, 2)[1], 3.5, 0.55)
        if 12 <= bar < 20:
            block_chord(t, bar, name, "strings", 4, octave=3, vel=0.22)
    play_melody(t, tune_a, "flute", offset_bars=4, vel=0.42)
    play_melody(t, tune_b, "flute", offset_bars=12, vel=0.45)
    return t.finish(room=2.8, wet=0.45)


def outpost():
    """A dusty morning: fingerpicked guitar in G, a shaker, a little e-piano tune."""
    t = Track(94, 4, 16, seed=2, swing=0.06)
    plan = ["G", "D/F#", "Em", "C", "G", "C", "D", "D", "Em", "C", "G", "D", "C", "G/B", "Am7", "D"]
    tune = compose_melody(t.rng, plan, "G", MAJOR, 67, 84, RHYTHMS_LIVELY)
    for bar, name in enumerate(plan):
        notes, low = tones(name, 3)
        t.note("guitar", bar * 4, low, 1.5, 0.6, -0.2)
        t.note("guitar", bar * 4 + 2, low + 7, 1.5, 0.5, -0.2)
        for beat, idx in ((0.5, 1), (1.0, 2), (1.5, 1), (2.5, 2), (3.0, 1), (3.5, 2)):
            t.note("guitar", bar * 4 + beat, notes[idx % len(notes)] + 12, 1.0, 0.36, 0.25)
        for step in range(8):
            t.hit(shaker(0.25 if step % 2 else 0.4, seed=bar * 8 + step), bar * 4 + step * 0.5, pan=0.4)
        if bar % 2 == 1:
            t.hit(brush(0.35, seed=bar), bar * 4 + 3, pan=-0.1)
    play_melody(t, tune, "epiano", vel=0.4, pan=0.15)
    return t.finish(room=1.8, wet=0.32)


def factory():
    """Machines that never stopped: an e-piano ostinato in A minor over ticking clocks."""
    t = Track(104, 4, 16, seed=3)
    plan = ["Am", "Am", "F", "G", "Am", "C", "Dm7", "E7", "F", "G", "Em", "Am", "Dm7", "Am", "Bb", "E7"]
    tune = compose_melody(t.rng, plan, "A", MINOR, 64, 79, RHYTHMS_GENTLE)
    for bar, name in enumerate(plan):
        arpeggio(t, bar, name, "epiano", [0, 2, 1, 2], 0.5, octave=4, vel=0.3, pan=-0.25)
        low = tones(name, 2)[1]
        for step in range(8):
            t.note("bass", bar * 4 + step * 0.5, low, 0.4, 0.38 if step % 2 else 0.5)
        for step in range(16):
            t.hit(tick(0.18 if step % 4 else 0.3), bar * 4 + step * 0.25, pan=0.5 if step % 2 else -0.5, send=0.05)
        if bar >= 8:
            block_chord(t, bar, name, "strings", 4, octave=3, vel=0.16)
        t.hit(kick(0.5), bar * 4)
        t.hit(kick(0.35), bar * 4 + 2.5)
    play_melody(t, tune, "flute", offset_bars=0, vel=0.3, pan=0.2, transpose=0)
    return t.finish(room=2.0, wet=0.3)


def dump():
    """A tired waltz among the heaps: accordion and harp in E minor, 3/4."""
    t = Track(126, 3, 24, seed=4)
    plan = ["Em", "Em", "Am", "Am", "D", "D", "G", "B7", "C", "C", "Am", "Am", "Em", "B7", "Em", "Em",
            "C", "D", "G", "Em", "Am", "B7", "Em", "Em"]
    scale = scale_notes("E", MINOR, 64, 83)
    previous = 71
    for bar, name in enumerate(plan):
        notes, low = tones(name, 3)
        t.note("bass", bar * 3, low, 1.0, 0.6)
        for beat in (1, 2):
            for n in notes:
                t.note("harp", bar * 3 + beat, n + 12, 0.7, 0.18, -0.3)
        chord_pcs = {n % 12 for n in notes}
        targets = [m for m in scale if m % 12 in chord_pcs]
        for beat, length in ((0, 1.5), (1.5, 0.5), (2, 1.0)) if bar % 4 != 3 else ((0, 3.0),):
            pool = targets if beat == 0 else [min(scale, key=lambda m: abs(m - previous - t.rng.choice([-2, -1, 1, 2])))]
            pitch = min(pool, key=lambda m: abs(m - previous))
            t.note("accordion", bar * 3 + beat, pitch, length * 0.95, 0.4, 0.2, send=0.35)
            previous = pitch
    return t.finish(room=2.4, wet=0.38)


def river():
    """Still water: flowing harp arpeggios in F, a slow flute, a shimmer of strings."""
    t = Track(72, 4, 16, seed=5)
    plan = ["Fadd9", "Am7", "Bb", "C", "Dm7", "Bb", "F", "C", "Bb", "C", "Am7", "Dm7", "Gm7", "C", "F", "F"]
    tune = compose_melody(t.rng, plan, "F", MAJOR, 65, 84, [[2.0, 2.0], [3.0, 1.0], [1.0, 1.0, 2.0]])
    for bar, name in enumerate(plan):
        arpeggio(t, bar, name, "harp", [0, 1, 2, 3, 4, 3, 2, 1], 0.25, octave=3, vel=0.25, pan=-0.2)
        t.note("bass", bar * 4, tones(name, 2)[1], 4.0, 0.45)
        block_chord(t, bar, name, "strings", 4, octave=4, vel=0.12)
    play_melody(t, tune, "flute", vel=0.35, pan=0.25)
    return t.finish(room=3.2, wet=0.5)


def story():
    """For the cutscenes: solo piano in C, gentle and unhurried."""
    t = Track(70, 4, 16, seed=6)
    plan = ["C", "G/B", "Am", "F", "C", "G", "F", "G", "Am", "Em", "F", "C", "F", "G", "Am", "G"]
    tune = compose_melody(t.rng, plan, "C", MAJOR, 67, 84, RHYTHMS_GENTLE)
    for bar, name in enumerate(plan):
        notes, low = tones(name, 3)
        t.note("piano", bar * 4, low - 12, 4.0, 0.5, -0.2)
        for beat, index in ((0.5, 0), (1, 1), (1.5, 2), (2.5, 0), (3, 1), (3.5, 2)):
            t.note("piano", bar * 4 + beat, notes[index], 1.5, 0.28, -0.1)
    play_melody(t, tune, "piano", vel=0.5, pan=0.15)
    return t.finish(room=2.6, wet=0.4)


def finale():
    """The water runs again: strings swell under flute and piano in D major."""
    t = Track(84, 4, 16, seed=7)
    plan = ["D", "A/C#", "Bm7", "G", "Em7", "A", "D", "D", "G", "A", "F#m", "Bm", "G", "A", "D", "D"]
    tune = compose_melody(t.rng, plan, "D", MAJOR, 69, 90, RHYTHMS_GENTLE)
    for bar, name in enumerate(plan):
        block_chord(t, bar, name, "strings", 4, octave=3, vel=0.3 + bar * 0.01)
        arpeggio(t, bar, name, "piano", [0, 1, 2, 1], 1.0, octave=4, vel=0.28, pan=-0.3)
        t.note("bass", bar * 4, tones(name, 2)[1], 4.0, 0.55)
        if bar >= 8:
            t.hit(taiko(0.35, seed=bar), bar * 4, send=0.4)
    play_melody(t, tune, "flute", vel=0.48, pan=0.2)
    return t.finish(room=3.0, wet=0.5)


def combat():
    """Danger: taiko and toms drive staccato strings and brass stabs in D minor."""
    t = Track(140, 4, 16, seed=8)
    plan = ["Dm", "Bb", "C", "A7", "Dm", "Bb", "Gm", "A7", "Gm", "Dm", "Bb", "A7", "Gm", "Bb", "C", "A7"]
    riff = compose_melody(t.rng, plan[8:], "D", MINOR, 62, 77, [[0.5, 0.5, 0.5, 0.5, 1.0, 1.0], [0.75, 0.75, 0.5, 2.0]])
    play_melody(t, riff, "brass", offset_bars=8, vel=0.32, pan=0.3)
    for bar, name in enumerate(plan):
        low = tones(name, 2)[1]
        for step in range(8):
            t.note("strings", bar * 4 + step * 0.5, low + 12 + (12 if step in (3, 6) else 0), 0.3, 0.45, -0.2, send=0.2)
            t.note("bass", bar * 4 + step * 0.5, low, 0.35, 0.6)
        for beat in (0, 1.5, 2, 3, 3.5):
            t.hit(taiko(0.8 if beat == 0 else 0.55, seed=bar * 10 + int(beat * 2)), bar * 4 + beat)
        if bar % 2 == 1:
            for i, m in enumerate((55, 52, 50, 47)):
                t.hit(tom(m, 0.5), bar * 4 + 3 + i * 0.25, pan=-0.4 + i * 0.25)
        for i, n in enumerate(tones(name, 4)[0]):
            t.note("brass", bar * 4 + 0.012 * i, n, 0.6, 0.3, 0.2)
            if bar % 2 == 0:
                t.note("brass", bar * 4 + 2.5 + 0.012 * i, n, 0.4, 0.25, 0.2)
    return t.finish(room=1.6, wet=0.25)


def gameover():
    """A sigh, not a punishment: piano, A minor to an open E."""
    t = Track(60, 4, 4, seed=9, loop=False)
    for bar, name in enumerate(["Am", "F", "Dm7", "E"]):
        notes, low = tones(name, 3)
        t.note("piano", bar * 4, low - 12, 4.0, 0.5)
        for i, n in enumerate(notes):
            t.note("piano", bar * 4 + 0.5 + i * 0.5, n + 12, 3.0, 0.35)
    return t.finish(room=3.0, wet=0.5)


TRACKS = {"title": title, "outpost": outpost, "factory": factory, "dump": dump, "river": river,
          "story": story, "finale": finale, "combat": combat, "gameover": gameover}


def write(name, stereo):
    OUT.mkdir(parents=True, exist_ok=True)
    wav_path = OUT / f"{name}.wav"
    with wave.open(str(wav_path), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(stereo.T, -1, 1) * 32767).astype(np.int16).tobytes())
    subprocess.run(["sox", str(wav_path), "-C", "4", str(OUT / f"{name}.ogg")], check=True)
    wav_path.unlink()
    print(f"{name}: {stereo.shape[1] / SR:.1f}s")


def main():
    wanted = sys.argv[1:] or list(TRACKS)
    for name in wanted:
        write(name, TRACKS[name]())


if __name__ == "__main__":
    main()
