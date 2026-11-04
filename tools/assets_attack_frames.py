#!/usr/bin/env python3
"""Cleans the player's attack frames for a sword: the pack's sheet is a punch
with white speed lines, which fought with the drawn blade. The lines go; the
body keeps its lunge, and player/sword_swing.gd draws the sword and its smear
from the hand. Idempotent. Run from game/ after tools/import_art.py.
"""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pngio import read_png, write_png  # noqa: E402

SHEET = Path(__file__).resolve().parent.parent / "assets/sprites/player_attack.png"
SPEED_LINES = np.array([0xF0, 0xE8, 0xE9], np.uint8)


def main():
    sheet = read_png(str(SHEET))
    lines = np.all(sheet[:, :, :3] == SPEED_LINES, axis=2) & (sheet[:, :, 3] > 0)
    sheet[lines] = 0
    write_png(str(SHEET), sheet)
    print(f"removed {int(lines.sum())} speed-line pixels")


if __name__ == "__main__":
    main()
