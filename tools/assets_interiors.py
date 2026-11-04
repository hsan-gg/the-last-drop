#!/usr/bin/env python3
"""Tile atlases for the insides of things: homes, offices, scrap shacks, labs,
the old metro and the mines. Same 20-column layout as the outdoor regions
(so the map characters and collision rules stay the same), read for rooms:

 0-2 floor   3 floor clutter   4 wall top*   5 water*    6 rug
 7 tiled floor   8 runner/rails   9 counter*   10 shelf*   11 table*
 12 doormat/plate   13 shadowed floor   14 toxic spill   15 bed/stalagmite*
 16 wall face*   17 stove/machine*   18 debris   19 crates/boulder*   (* solid)

Writes assets/tilesets/<name>_tiles.png. Run from game/.
"""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pngio import write_png  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
T = 16


def rgb(code):
    code = code.lstrip("#")
    return np.array([int(code[i:i + 2], 16) for i in (0, 2, 4)], np.int32)


def tile(colour, noise=5, seed=0):
    r = np.random.default_rng(seed)
    t = np.zeros((T, T, 4), np.uint8)
    n = r.integers(-noise, noise + 1, size=(T, T))
    c = rgb(colour)
    for i in range(3):
        t[:, :, i] = np.clip(c[i] + n, 0, 255)
    t[:, :, 3] = 255
    return t


def rect(t, x0, y0, x1, y1, colour):
    t[y0:y1, x0:x1, :3] = np.clip(rgb(colour) if isinstance(colour, str) else colour, 0, 255)
    t[y0:y1, x0:x1, 3] = 255


def floorboards(colour, seed):
    t = tile(colour, 4, seed)
    r = np.random.default_rng(seed)
    for y in range(0, T, 4):
        rect(t, 0, y + 3, T, y + 4, rgb(colour) - 34)
        joint = int(r.integers(2, 14))
        rect(t, joint, y, joint + 1, y + 3, rgb(colour) - 26)
        rect(t, 0, y, T, y + 1, rgb(colour) + 10)
    return t


def checker(a, b, size=4):
    t = tile(a, 2)
    for y in range(0, T, size):
        for x in range(0, T, size):
            if (x // size + y // size) % 2:
                rect(t, x, y, x + size, y + size, b)
    return t


def stone_floor(colour, seed):
    t = tile(colour, 6, seed)
    rect(t, 0, 7, T, 8, rgb(colour) - 30)
    rect(t, 7, 0, 8, 7, rgb(colour) - 30)
    rect(t, 3, 8, 4, T, rgb(colour) - 30)
    rect(t, 12, 8, 13, T, rgb(colour) - 30)
    return t


def dirt(colour, seed, pebbles=0):
    t = tile(colour, 9, seed)
    r = np.random.default_rng(seed + 9)
    for _ in range(pebbles):
        x, y = int(r.integers(1, 14)), int(r.integers(1, 14))
        rect(t, x, y, x + 2, y + 1, rgb(colour) + 30)
        rect(t, x, y + 1, x + 2, y + 2, rgb(colour) - 30)
    return t


def wall_top(colour):
    t = tile(colour, 3)
    rect(t, 0, 0, T, 1, rgb(colour) + 24)
    rect(t, 0, T - 2, T, T, rgb(colour) - 24)
    return t


def wall_face(paper, trim, stripe=None):
    t = tile(paper, 3)
    if stripe:
        for x in range(0, T, 4):
            rect(t, x, 0, x + 1, 12, stripe)
    rect(t, 0, 12, T, 13, rgb(trim) + 20)
    rect(t, 0, 13, T, T, trim)
    rect(t, 0, 0, T, 1, rgb(paper) - 40)
    return t


def rock_face(colour, seed):
    t = tile(colour, 10, seed)
    r = np.random.default_rng(seed)
    for _ in range(5):
        x, y = int(r.integers(0, 14)), int(r.integers(0, 12))
        rect(t, x, y, x + 3, y + 1, rgb(colour) + 26)
        rect(t, x, y + 1, x + 3, y + 2, rgb(colour) - 30)
    rect(t, 0, T - 2, T, T, rgb(colour) - 40)
    return t


def water(colour, seed):
    t = tile(colour, 4, seed)
    rect(t, 2, 4, 7, 5, rgb(colour) + 40)
    rect(t, 9, 10, 14, 11, rgb(colour) + 40)
    return t


def rug(base, edge, motif):
    t = tile(base, 3)
    rect(t, 0, 0, T, 1, edge)
    rect(t, 0, T - 1, T, T, edge)
    rect(t, 6, 6, 10, 10, motif)
    rect(t, 7, 4, 9, 12, motif)
    return t


def runner(base, edge):
    t = tile(base, 3)
    rect(t, 0, 0, 2, T, edge)
    rect(t, 14, 0, T, T, edge)
    return t


def rails(floor, seed):
    t = dirt(floor, seed)
    for y in (2, 7, 12):
        rect(t, 0, y, T, y + 2, "#5a3a24")
    rect(t, 3, 0, 5, T, "#8a8a94")
    rect(t, 11, 0, 13, T, "#8a8a94")
    rect(t, 3, 0, 4, T, "#b8b8c4")
    rect(t, 11, 0, 12, T, "#b8b8c4")
    return t


def counter(top, front):
    t = tile(front, 3)
    rect(t, 0, 0, T, 6, top)
    rect(t, 0, 6, T, 7, rgb(top) - 40)
    rect(t, 2, 9, 7, 14, rgb(front) - 20)
    rect(t, 9, 9, 14, 14, rgb(front) - 20)
    rect(t, 4, 11, 5, 12, "#e0c070")
    rect(t, 11, 11, 12, 12, "#e0c070")
    return t


def shelf(wood, items):
    t = tile(wood, 3)
    for y in (4, 9, 14):
        rect(t, 0, y, T, y + 1, rgb(wood) - 40)
    r = np.random.default_rng(3)
    for row in range(3):
        x = 1
        while x < 14:
            w = int(r.integers(1, 3))
            h = int(r.integers(2, 4))
            rect(t, x, row * 5 + 4 - h, x + w, row * 5 + 4, items[int(r.integers(0, len(items)))])
            x += w + 1
    return t


def table(top, legs):
    t = np.zeros((T, T, 4), np.uint8)
    rect(t, 1, 3, 15, 10, top)
    rect(t, 1, 3, 15, 4, rgb(top) + 26)
    rect(t, 1, 10, 15, 11, rgb(top) - 40)
    rect(t, 2, 11, 4, 15, legs)
    rect(t, 12, 11, 14, 15, legs)
    rect(t, 6, 4, 9, 7, "#f0e8d0")
    return t


def bed(frame, sheet):
    t = np.zeros((T, T, 4), np.uint8)
    rect(t, 1, 1, 15, 15, frame)
    rect(t, 2, 2, 14, 6, "#f0f0e8")
    rect(t, 2, 6, 14, 14, sheet)
    rect(t, 2, 6, 14, 7, rgb(sheet) + 30)
    return t


def stalagmite(colour):
    t = np.zeros((T, T, 4), np.uint8)
    for y in range(2, T):
        half = (y - 1) // 2
        rect(t, 8 - half, y, 8 + half + 1, y + 1, rgb(colour) + (20 if y < 6 else 0))
    rect(t, 8, 2, 9, T, rgb(colour) + 30)
    return t


def stove(body, accent):
    t = tile(body, 3)
    rect(t, 0, 0, T, 4, rgb(body) + 20)
    rect(t, 3, 1, 6, 3, "#2a2a2a")
    rect(t, 10, 1, 13, 3, "#2a2a2a")
    rect(t, 3, 7, 13, 14, rgb(body) - 30)
    rect(t, 4, 8, 12, 9, accent)
    return t


def machine(body, light):
    t = tile(body, 4)
    rect(t, 2, 2, 14, 8, "#1a2028")
    rect(t, 3, 3, 7, 4, light)
    rect(t, 3, 5, 10, 6, rgb(light) - 60)
    rect(t, 10, 10, 13, 13, "#e0584a")
    return t


def debris(floor, bits, seed):
    t = tile(floor, 5, seed)
    r = np.random.default_rng(seed)
    for _ in range(6):
        x, y = int(r.integers(1, 14)), int(r.integers(1, 14))
        rect(t, x, y, x + int(r.integers(1, 3)), y + 1, bits[int(r.integers(0, len(bits)))])
    return t


def crates(wood):
    t = np.zeros((T, T, 4), np.uint8)
    for x0, y0, x1, y1 in ((0, 6, 9, 16), (8, 2, 16, 12)):
        rect(t, x0, y0, x1, y1, wood)
        rect(t, x0, y0, x1, y0 + 1, rgb(wood) + 30)
        rect(t, x0, y1 - 1, x1, y1, rgb(wood) - 40)
        rect(t, x0, (y0 + y1) // 2, x1, (y0 + y1) // 2 + 1, rgb(wood) - 30)
    return t


def boulder(colour):
    t = np.zeros((T, T, 4), np.uint8)
    for y in range(3, 15):
        half = 7 - abs(y - 9) // 2
        rect(t, 8 - half, y, 8 + half, y + 1, colour)
    rect(t, 4, 5, 9, 7, rgb(colour) + 30)
    rect(t, 3, 13, 13, 15, rgb(colour) - 40)
    return t


def toxic(floor):
    t = tile(floor, 4)
    for y in range(4, 13):
        half = 6 - abs(y - 8)
        rect(t, 8 - half - 1, y, 8 + half + 1, y + 1, "#6ac83a")
    rect(t, 5, 6, 7, 7, "#c8ff7a")
    return t


def doormat(colour):
    t = tile("#3a3030", 3)
    rect(t, 2, 4, 14, 12, colour)
    for x in range(3, 13, 2):
        rect(t, x, 5, x + 1, 11, rgb(colour) - 30)
    return t


def atlas(columns):
    """Cut-out furniture (tables, beds, crates, rocks) sits on the room's floor:
    a tile map draws one tile per cell, so nothing may be see-through."""
    assert len(columns) == 20
    floor = columns[0]
    solid = []
    for column in columns:
        if column[:, :, 3].min() < 255:
            alpha = column[:, :, 3:4] / 255.0
            merged = floor.copy()
            merged[:, :, :3] = (column[:, :, :3] * alpha + floor[:, :, :3] * (1 - alpha)).astype(np.uint8)
            column = merged
        solid.append(column)
    return np.concatenate(solid, axis=1)


def home():
    wood = "#8a5a3a"
    return atlas([
        floorboards(wood, 1), floorboards("#86563a", 2), floorboards("#8e5e3e", 3),
        debris(wood, ["#c8b8a0", "#6a4a2a"], 4), wall_top("#3a2a2a"), water("#3a6a8a", 5),
        rug("#7a2a3a", "#e0c070", "#e0c070"), checker("#c8c0b0", "#8a8478"), runner("#6a3a4a", "#d8b060"),
        counter("#c8a878", "#7a5a3a"), shelf("#6a4a2a", ["#c8402c", "#3a6aa8", "#e0c070", "#5a8a4a"]),
        table("#a87a4a", "#6a4a2a"), doormat("#8a6a3a"), floorboards("#5a3a2a", 6), toxic(wood),
        bed("#6a4a2a", "#4a7ab0"), wall_face("#c8b088", "#6a4a2a", "#b8a078"), stove("#5a5a60", "#e0584a"),
        debris(wood, ["#a0a0a0", "#c8b8a0"], 7), crates("#a07a4a"),
    ])


def office():
    floor = "#6a7078"
    return atlas([
        checker("#7a8088", "#6a7078"), checker("#78808a", "#68707a"), checker("#7c828a", "#6c7278"),
        debris(floor, ["#e8e8e0", "#a0a0a8"], 8), wall_top("#2a2e36"), water("#3a5a7a", 9),
        rug("#3a4a6a", "#8a9ab0", "#8a9ab0"), stone_floor("#8a8e94", 10), runner("#4a3a3a", "#8a8e94"),
        counter("#a0a4ac", "#5a5e66"), shelf("#4a4e56", ["#e8e8e0", "#c8c070", "#a0a0a8"]),
        table("#8a8e96", "#3a3e46"), doormat("#4a4e56"), checker("#4a5058", "#40464e"), toxic(floor),
        bed("#4a4e56", "#7a8a9a"), wall_face("#9aa0a8", "#3a3e46"), machine("#5a6068", "#5fe0d0"),
        debris(floor, ["#e8e8e0", "#5a5e66"], 11), crates("#7a6a4a"),
    ])


def shack():
    floor = "#6a5a48"
    return atlas([
        dirt(floor, 12, 2), dirt("#665644", 13, 3), dirt("#6e5e4c", 14, 1),
        debris(floor, ["#4a6a8a", "#8a3a2a", "#c8b8a0"], 15), wall_top("#3a2a24"), water("#4a5a4a", 16),
        rug("#5a6a3a", "#c8a040", "#c84a3a"), floorboards("#6a5a40", 17), runner("#4a4a5a", "#8a6a3a"),
        counter("#8a7a5a", "#5a4a3a"), shelf("#5a4a3a", ["#c8402c", "#4a8ac8", "#e0c040", "#8ac85a", "#c8c8c8"]),
        table("#7a6a4a", "#4a3a2a"), doormat("#7a5a3a"), dirt("#4a3e32", 18), toxic(floor),
        bed("#5a4a3a", "#8a6a4a"), wall_face("#6a6a78", "#4a3a2a", "#5a5a68"), stove("#4a4a50", "#f08a24"),
        debris(floor, ["#c8c8c8", "#4a6a8a", "#8a3a2a"], 19), crates("#8a6a40"),
    ])


def lab():
    floor = "#c8d0cc"
    return atlas([
        checker("#d0d8d4", "#c0c8c4"), checker("#ccd4d0", "#bcc4c0"), checker("#d4dcd8", "#c4ccc8"),
        debris(floor, ["#7a9a8a", "#e8f0ec"], 20), wall_top("#4a5a54"), water("#5ab0c8", 21),
        rug("#4a8a7a", "#e8f4ec", "#e8f4ec"), stone_floor("#b8c4bc", 22), runner("#5a9a8a", "#e8f4ec"),
        counter("#e8f0ec", "#8a9a94"), shelf("#7a8a84", ["#5fe0d0", "#7bc043", "#e8f0ec"]),
        table("#e0e8e4", "#7a8a84"), doormat("#5a9a8a"), checker("#9aa49e", "#8e9892"), toxic(floor),
        bed("#8a9a94", "#5ab0c8"), wall_face("#e8f0ec", "#7a8a84", "#d8e4dc"), machine("#8a9a94", "#7bc043"),
        debris(floor, ["#5a9a5a", "#7a9a8a"], 23), crates("#9a8a6a"),
    ])


def cave():
    floor = "#4a3e36"
    return atlas([
        dirt(floor, 24, 3), dirt("#463a32", 25, 4), dirt("#4e423a", 26, 2),
        dirt(floor, 27, 9), wall_top("#241c18"), water("#2a4a5a", 28),
        debris(floor, ["#4a7a4a", "#5a8a5a"], 29), stone_floor("#5a5048", 30), rails(floor, 31),
        counter("#7a5a3a", "#4a3a2a"), rock_face("#5a4e46", 32),
        table("#6a4a2a", "#3a2a1a"), floorboards("#5a4030", 33), dirt("#2e2622", 34), toxic(floor),
        stalagmite("#6a5e54"), rock_face("#4e443c", 35), machine("#4a4a50", "#f0a030"),
        debris(floor, ["#d8d0c0", "#6a6058"], 36), boulder("#6a6058"),
    ])


def metro():
    floor = "#5a5e60"
    return atlas([
        checker("#6a6e70", "#626668", 8), checker("#686c6e", "#606466", 8), checker("#6c7072", "#646869", 8),
        debris(floor, ["#e8e0c8", "#4a4e50"], 37), wall_top("#1e2224"), water("#2a3a3a", 38),
        rug("#2a5a8a", "#e0c040", "#e0c040"), stone_floor("#7a7e80", 39), rails("#3a3836", 40),
        counter("#8a8e90", "#4a4e50"), shelf("#3a3e40", ["#e0c040", "#c8402c", "#e8e8e0"]),
        table("#6a6e70", "#2a2e30"), doormat("#e0c040"), checker("#3a3e40", "#34383a"), toxic(floor),
        bed("#4a4e50", "#8a3a3a"), wall_face("#c8c4b0", "#2a5a8a", "#b8b4a0"), machine("#3a3e40", "#e0c040"),
        debris(floor, ["#c8c0a8", "#2a2e30"], 41), crates("#6a5a3a"),
    ])


def main():
    out = ROOT / "assets/tilesets"
    for name, build in (("home", home), ("office", office), ("shack", shack), ("lab", lab), ("cave", cave), ("metro", metro)):
        write_png(str(out / f"{name}_tiles.png"), build())
    print("wrote 6 interior atlases")


if __name__ == "__main__":
    main()
