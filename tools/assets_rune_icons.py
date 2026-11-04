#!/usr/bin/env python3
"""Draws the three rune icons (12x12 each, one strip): an Ember flame in three
layers, a Scatter shell with its brass cap, and a Tide wave curling over.
Writes assets/sprites/icons/runes.png. Run from game/.
"""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pngio import write_png  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SIZE = 12

# One character per pixel; '.' is transparent.
EMBER = [
    "......o.....",
    ".....oo.....",
    ".....oOo....",
    "....oOOo..o.",
    "...oOOyOo.o.",
    "..oOOyyOOoo.",
    "..oOyyyyOOo.",
    ".oOyywwyyOo.",
    ".oOyywwyyOo.",
    ".oOOyyyyOOo.",
    "..ooOOOOoo..",
    "....oooo....",
]
SCATTER = [
    "............",
    "....kkkk....",
    "...kRRRrk...",
    "...kRRRrk...",
    "...kRRRrk...",
    "...kRRRrk...",
    "...kRRRrk...",
    "...kRRRrk...",
    "...kGGGgk...",
    "...kGGGgk...",
    "...kggggk...",
    "....kkkk....",
]
TIDE = [
    "............",
    "....bbbb....",
    "..bbWWWBb...",
    ".bWWbbbBBb..",
    ".bWb...bBb..",
    "..b...bBBb..",
    "......bBb.b.",
    ".b...bBBbbB.",
    "bBbbbBBBBBBb",
    "bBBBBBBBBBBb",
    ".bBBbbBBbbb.",
    "..bb..bb....",
]
COLOURS = {
    "o": "#8a2a14", "O": "#e8541c", "y": "#ffb030", "w": "#fff4c0",
    "k": "#2a1a20", "R": "#c8402c", "r": "#8a2a24", "G": "#f0c850", "g": "#b08a30",
    "b": "#1a4a6a", "B": "#3aa8d8", "W": "#d8f6ff",
}


def draw(rows):
    icon = np.zeros((SIZE, SIZE, 4), np.uint8)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in COLOURS:
                code = COLOURS[ch].lstrip("#")
                icon[y, x, :3] = [int(code[i:i + 2], 16) for i in (0, 2, 4)]
                icon[y, x, 3] = 255
    return icon


def main():
    strip = np.concatenate([draw(EMBER), draw(SCATTER), draw(TIDE)], axis=1)
    write_png(str(ROOT / "assets/sprites/icons/runes.png"), strip)
    print("wrote assets/sprites/icons/runes.png")


if __name__ == "__main__":
    main()
