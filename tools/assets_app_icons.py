#!/usr/bin/env python3
"""Draws the home-screen icons for the installable web app (PWA) and the
Apple touch icon from the 32x32 game icon: scaled up by whole pixels so it
stays crisp, centred on the night-teal backdrop with room to spare, so the
round and squircle masks phones cut icons with never clip the drop.

Run from game/. Writes assets/app/icon_<size>.png.
"""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pngio import read_png, scaled, write_png  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
BACKDROP = (18, 48, 58, 255)  # the icon's own background, so the tile reads as one piece
# size -> whole-pixel scale of the 32 px icon (about 75% of the tile).
SIZES = {144: 3, 180: 4, 192: 4, 512: 12}


def tile(icon, size, factor):
    canvas = np.zeros((size, size, 4), dtype=np.uint8)
    canvas[:, :] = BACKDROP
    big = scaled(icon, factor)
    top = (size - big.shape[0]) // 2
    left = (size - big.shape[1]) // 2
    region = canvas[top:top + big.shape[0], left:left + big.shape[1]]
    alpha = big[:, :, 3:4].astype(np.float32) / 255.0
    region[:, :, :3] = (big[:, :, :3] * alpha + region[:, :, :3] * (1.0 - alpha)).astype(np.uint8)
    return canvas


def main():
    icon = read_png(ROOT / "icon.png")
    out = ROOT / "assets" / "app"
    out.mkdir(parents=True, exist_ok=True)
    for size, factor in SIZES.items():
        write_png(out / f"icon_{size}.png", tile(icon, size, factor))
        print(f"assets/app/icon_{size}.png")


if __name__ == "__main__":
    main()
