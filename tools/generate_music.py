#!/usr/bin/env python3
"""Composes the game's music: a looping track per mood, synthesised with numpy
and written to assets/audio/music/*.ogg (needs sox for the ogg step).
Run from game/:  python3 tools/generate_music.py

Each track is a handful of layers (pad, bass, arpeggio, melody, drums) built
from simple oscillators with envelopes, then given a short echo. Lengths are
exact bar counts and the tail wraps to the start, so every loop is seamless.
Replace any file with real music under the same name and the game uses it.
"""
import subprocess
import wave
from pathlib import Path

import numpy as np

SR = 22050
OUT = Path(__file__).resolve().parent.parent / "assets" / "audio" / "music"
rng = np.random.default_rng(7)


def hz(midi):
    return 440.0 * 2 ** ((midi - 69) / 12.0)


def env(n, attack=0.01, decay=0.2, sustain=0.6, release=0.1):
    a, d, r = int(attack * SR), int(decay * SR), int(release * SR)
    out = np.full(n, sustain, dtype=np.float32)
    a, d, r = min(a, n), min(d, max(n - a, 0)), min(r, n)
    if a:
        out[:a] = np.linspace(0, 1, a)
    if d:
        out[a:a + d] = np.linspace(1, sustain, d)
    if r:
        out[n - r:] *= np.linspace(1, 0, r)
    return out


def osc(freq, n, kind="sine", detune=0.0):
    t = np.arange(n) / SR
    phase = 2 * np.pi * freq * (1 + detune) * t
    if kind == "sine":
        return np.sin(phase)
    if kind == "tri":
        return 2 / np.pi * np.arcsin(np.sin(phase))
    if kind == "square":
        return np.sign(np.sin(phase)) * 0.6
    if kind == "saw":
        return 2 * ((freq * (1 + detune) * t) % 1.0) - 1
    return np.sin(phase)


def tone(midi, seconds, kind="sine", vol=0.3, adsr=(0.01, 0.2, 0.6, 0.1), detune=0.0, layers=1):
    n = int(seconds * SR)
    f = hz(midi)
    sig = sum(osc(f, n, kind, detune * i) for i in range(layers)) / layers
    return (sig * env(n, *adsr) * vol).astype(np.float32)


def pluck(midi, seconds, vol=0.3):
    n = int(seconds * SR)
    f = hz(midi)
    t = np.arange(n) / SR
    sig = np.sin(2 * np.pi * f * t) + 0.5 * np.sin(4 * np.pi * f * t) * np.exp(-t * 9) + 0.25 * np.sin(6 * np.pi * f * t) * np.exp(-t * 14)
    return (sig * np.exp(-t * 5.5) * vol).astype(np.float32)


def kick(vol=0.5):
    n = int(0.22 * SR)
    t = np.arange(n) / SR
    return (np.sin(2 * np.pi * (45 + 90 * np.exp(-t * 28)) * t) * np.exp(-t * 14) * vol).astype(np.float32)


def snare(vol=0.3):
    n = int(0.18 * SR)
    t = np.arange(n) / SR
    noise = rng.uniform(-1, 1, n)
    return ((noise * 0.7 + np.sin(2 * np.pi * 190 * t) * 0.5) * np.exp(-t * 22) * vol).astype(np.float32)


def hat(vol=0.12, long=False):
    n = int((0.16 if long else 0.05) * SR)
    t = np.arange(n) / SR
    noise = np.diff(rng.uniform(-1, 1, n + 1))
    return (noise * np.exp(-t * (18 if long else 60)) * vol).astype(np.float32)


class Track:
    def __init__(self, bpm, bars):
        self.bpm, self.bars = bpm, bars
        self.beat = 60.0 / bpm
        self.n = int(bars * 4 * self.beat * SR)
        self.buf = np.zeros(self.n, dtype=np.float32)

    def at(self, beat):
        return int(beat * self.beat * SR)

    def put(self, beat, sig):
        start = self.at(beat)
        for i in range(0, len(sig), self.n):  # wrap the tail round to the start for a seamless loop
            chunk = sig[i:i + self.n]
            idx = (start + i + np.arange(len(chunk))) % self.n
            np.add.at(self.buf, idx, chunk)

    def finish(self, echo=0.28, echo_beats=0.75):
        d = self.at(echo_beats)
        wet = np.zeros_like(self.buf)
        for k in (1, 2, 3):
            wet += np.roll(self.buf, d * k) * (echo ** k)
        mixed = self.buf + wet
        peak = np.max(np.abs(mixed)) or 1.0
        return (mixed / peak * 0.8).astype(np.float32)


def chord_tones(root, quality):
    shapes = {"m": (0, 3, 7), "M": (0, 4, 7), "m7": (0, 3, 7, 10), "M7": (0, 4, 7, 11), "dim": (0, 3, 6), "sus": (0, 5, 7)}
    return [root + i for i in shapes[quality]]


def pad(t, bar, root, quality, vol=0.09, kind="tri"):
    for midi in chord_tones(root, quality):
        t.put(bar * 4, tone(midi, 4 * t.beat * 1.02, kind, vol, (0.5, 0.3, 0.8, 0.8), detune=0.004, layers=2))


def bass(t, bar, root, pattern, kind="sine", vol=0.28):
    for beat, length in pattern:
        t.put(bar * 4 + beat, tone(root - 24, length * t.beat, kind, vol, (0.01, 0.1, 0.7, 0.08)))


def arp(t, bar, root, quality, step=0.5, vol=0.14, octave=12, kind="pluck", order=(0, 1, 2, 1)):
    notes = chord_tones(root + octave, quality)
    for i in range(int(4 / step)):
        t.put(bar * 4 + i * step, pluck(notes[order[i % len(order)] % len(notes)], 0.9 * t.beat * 2, vol))


def melody(t, bar, notes, vol=0.2, kind="tri"):
    for beat, midi, length in notes:
        if midi is None:
            continue
        t.put(bar * 4 + beat, tone(midi, length * t.beat, kind, vol, (0.02, 0.15, 0.7, 0.2)))


def drums(t, bar, kick_beats=(0, 2), snare_beats=(1, 3), hat_step=0.5, vol=1.0):
    for b in kick_beats:
        t.put(bar * 4 + b, kick(0.55 * vol))
    for b in snare_beats:
        t.put(bar * 4 + b, snare(0.3 * vol))
    for i in range(int(4 / hat_step)):
        t.put(bar * 4 + i * hat_step, hat(0.1 * vol, long=(i % 4 == 3)))


def write(name, signal, loop=True):
    OUT.mkdir(parents=True, exist_ok=True)
    wav_path = OUT / f"{name}.wav"
    with wave.open(str(wav_path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((np.clip(signal, -1, 1) * 32767).astype(np.int16).tobytes())
    subprocess.run(["sox", str(wav_path), "-C", "3", str(OUT / f"{name}.ogg")], check=True)
    wav_path.unlink()
    print(f"{name}: {len(signal) / SR:.1f}s")


A, C, D, E, F, G = 57, 60, 62, 64, 65, 67  # MIDI roots (A3 etc.)


def title():
    t = Track(76, 16)
    prog = [(A, "m7"), (F, "M7"), (C, "M"), (G, "M")]
    for bar in range(16):
        root, q = prog[bar % 4]
        pad(t, bar, root, q, 0.1)
        bass(t, bar, root, [(0, 4)], "sine", 0.3)
        arp(t, bar, root, q, 0.5, 0.13)
    motif = [(0, 76, 1), (1, 79, 1), (2, 81, 2), (4, 79, 1), (5, 76, 1), (6, 74, 2)]
    for bar in range(4, 16, 2):
        melody(t, bar, motif, 0.16)
    return t.finish(0.3, 0.75)


def outpost():
    t = Track(68, 16)
    prog = [(D, "m"), (D - 2, "M"), (D + 3, "M"), (D - 5, "M")]
    for bar in range(16):
        root, q = prog[bar % 4]
        pad(t, bar, root, q, 0.08)
        bass(t, bar, root, [(0, 2), (2.5, 1.5)], "tri", 0.22)
        if bar % 2 == 0:
            arp(t, bar, root, q, 1.0, 0.12, order=(0, 2, 1, 2))
    for bar in (3, 7, 11, 15):
        melody(t, bar, [(0, 74, 1.5), (2, 77, 1), (3, 76, 1)], 0.15)
    return t.finish(0.35, 1.0)


def factory():
    t = Track(96, 16)
    prog = [(E - 12, "m"), (E - 12, "m"), (E - 14, "M"), (E - 11, "dim")]
    for bar in range(16):
        root, q = prog[bar % 4]
        pad(t, bar, root + 12, q, 0.07, "saw")
        bass(t, bar, root + 12, [(i * 0.5, 0.45) for i in range(8)], "square", 0.12)
        for b in (1, 3):
            t.put(bar * 4 + b, hat(0.22, long=True))
        if bar % 4 == 3:
            t.put(bar * 4 + 3.5, kick(0.4))
    return t.finish(0.25, 0.5)


def dump():
    t = Track(62, 16)
    prog = [(C - 1, "m"), (C - 1 - 4, "M"), (C - 3, "m"), (C - 6, "M")]
    for bar in range(16):
        root, q = prog[bar % 4]
        pad(t, bar, root, q, 0.09, "saw")
        bass(t, bar, root, [(0, 1), (1.5, 0.5), (2, 1), (3.5, 0.5)], "sine", 0.28)
        if bar % 3 == 2:
            t.put(bar * 4 + 2, pluck(root + 31, 2.5, 0.12))
    return t.finish(0.4, 1.0)


def river():
    t = Track(84, 16)
    prog = [(E, "m7"), (D, "M"), (C, "M7"), (D, "M")]
    for bar in range(16):
        root, q = prog[bar % 4]
        pad(t, bar, root, q, 0.07)
        bass(t, bar, root, [(0, 4)], "sine", 0.24)
        arp(t, bar, root, q, 0.25, 0.1, order=(0, 1, 2, 3, 2, 1))
    for bar in range(8, 16, 2):
        melody(t, bar, [(0, 76, 1), (1, 78, 1), (2, 79, 2), (4, 78, 1), (5, 76, 3)], 0.14)
    return t.finish(0.35, 0.5)


def story():
    t = Track(60, 16)
    prog = [(A, "m"), (F, "M7"), (D, "m"), (E, "M")]
    for bar in range(16):
        root, q = prog[bar % 4]
        pad(t, bar, root, q, 0.1)
        bass(t, bar, root, [(0, 4)], "sine", 0.25)
    for bar in range(2, 16, 2):
        melody(t, bar, [(0, 69, 2), (2, 72, 1), (3, 74, 1), (4, 76, 3)], 0.17, "tri")
    return t.finish(0.4, 1.0)


def finale():
    t = Track(80, 16)
    prog = [(C, "M"), (G, "M"), (A, "m"), (F, "M")]
    for bar in range(16):
        root, q = prog[bar % 4]
        pad(t, bar, root, q, 0.1)
        bass(t, bar, root, [(0, 2), (2, 2)], "sine", 0.27)
        arp(t, bar, root, q, 0.5, 0.14, order=(0, 1, 2, 1, 2, 1, 0, 2))
    motif = [(0, 72, 1), (1, 76, 1), (2, 79, 2), (4, 77, 1), (5, 76, 1), (6, 72, 2)]
    for bar in range(4, 16, 2):
        melody(t, bar, motif, 0.17)
    return t.finish(0.3, 0.75)


def combat():
    t = Track(132, 16)
    prog = [(D, "m"), (D, "m"), (D - 4, "M"), (D - 2, "M")]
    for bar in range(16):
        root, q = prog[bar % 4]
        drums(t, bar, (0, 1.5, 2, 3.5), (1, 3), 0.5)
        bass(t, bar, root + 12, [(i * 0.5, 0.4) for i in range(8)], "saw", 0.13)
        if bar % 2 == 1:
            for midi in chord_tones(root + 12, q):
                t.put(bar * 4 + 3, tone(midi, 0.4 * t.beat, "saw", 0.06, (0.005, 0.1, 0.5, 0.1)))
    for bar in range(8, 16, 2):
        melody(t, bar, [(0, 74, 0.5), (0.5, 77, 0.5), (1, 81, 1), (2, 79, 0.5), (2.5, 77, 0.5), (3, 74, 1)], 0.11, "square")
    return t.finish(0.2, 0.5)


def gameover():
    t = Track(54, 4)
    for i, midi in enumerate((69, 67, 64, 57)):
        t.put(i * 1.0, tone(midi, 2.0 * t.beat, "tri", 0.3, (0.02, 0.3, 0.6, 0.6)))
    for midi in (45, 52):
        t.put(0, tone(midi, 15 * t.beat, "sine", 0.28, (0.1, 0.5, 0.6, 1.5)))
    return t.finish(0.4, 1.0)


def main():
    for name, make in (("title", title), ("outpost", outpost), ("factory", factory), ("dump", dump), ("river", river),
                       ("story", story), ("finale", finale), ("combat", combat), ("gameover", gameover)):
        write(name, make())


if __name__ == "__main__":
    main()
