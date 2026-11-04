#!/usr/bin/env python3
"""Pixel art for rooms, dungeons and mining:
- item icons (16x16): copper ore, iron ore, crystal shard, coal, rusty key,
  metro key, pickaxe, rune battery, and a folded note;
- puzzle stations (16x24): fuse box, wall safe, radio console, valve panel,
  notice board, conveyor console, compost mixer, workbench, signal lamp;
- breakables (16x16 / 16x20): cracked walls for each interior tileset and ore
  veins (copper, iron, crystal, coal);
- a ladder hole and a note on the floor.
Run from game/.
"""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pngio import read_png, write_png  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
OUTLINE = "#2c1d35"


def rgb(code):
    if not isinstance(code, str):
        return np.asarray(code, np.int32)
    code = code.lstrip("#")
    return np.array([int(code[i:i + 2], 16) for i in (0, 2, 4)], np.int32)


def blank(w=16, h=16):
    return np.zeros((h, w, 4), np.uint8)


def px(img, x, y, colour):
    if 0 <= x < img.shape[1] and 0 <= y < img.shape[0]:
        img[y, x, :3] = np.clip(rgb(colour) if isinstance(colour, str) else colour, 0, 255)
        img[y, x, 3] = 255


def rect(img, x0, y0, x1, y1, colour):
    img[y0:y1, x0:x1, :3] = np.clip(rgb(colour) if isinstance(colour, str) else colour, 0, 255)
    img[y0:y1, x0:x1, 3] = 255


def outline(img):
    """A one-pixel dark outline round every shape, like the rest of the art."""
    alpha = img[:, :, 3] > 0
    grown = alpha.copy()
    grown[1:, :] |= alpha[:-1, :]
    grown[:-1, :] |= alpha[1:, :]
    grown[:, 1:] |= alpha[:, :-1]
    grown[:, :-1] |= alpha[:, 1:]
    edge = grown & ~alpha
    img[edge, :3] = rgb(OUTLINE)
    img[edge, 3] = 255
    return img


def from_rows(rows, colours, w=16, h=16):
    img = blank(w, h)
    oy = (h - len(rows)) // 2
    for y, row in enumerate(rows):
        ox = (w - len(row)) // 2
        for x, ch in enumerate(row):
            if ch in colours:
                px(img, ox + x, oy + y, colours[ch])
    return outline(img)


# ------------------------------------------------------------------ item icons

ROCK = {"r": "#6a6058", "R": "#8a8078", "d": "#4a4038"}


def ore(fleck, shine):
    colours = dict(ROCK, o=fleck, s=shine)
    return from_rows([
        "....RRRR....",
        "..RRrrrrRr..",
        ".RrroorrrRr.",
        ".Rrosorrrrr.",
        "Rrrrrrrooddr",
        "Rrdrrrrosodr",
        "rrddrrrooddr",
        ".rrrrddrrdd.",
        "..ddddddddd.",
    ], colours, 14, 14)


def crystal():
    return from_rows([
        ".....c.....",
        "....cCc..c.",
        "....cCc.cCc",
        "...cCWCccCc",
        "...cCWCcCc.",
        "..ccCCCcCc.",
        "..cCCCCCc..",
        "..dddddddd.",
    ], {"c": "#3aa8c8", "C": "#7fe0ff", "W": "#e8ffff", "d": "#4a4038"}, 14, 12)


def coal():
    return from_rows([
        "...kkkk...",
        ".kkKkkkkk.",
        "kkKkkkkKkk",
        "kkkkkkkkkk",
        ".kkkKkkkk.",
        "..kkkkkk..",
    ], {"k": "#2a2a30", "K": "#5a5a68"}, 12, 10)


def key(metal, shine):
    return from_rows([
        ".mmm.......",
        "m...m......",
        "m...mmmmmmm",
        "m...m..m.m.",
        ".mmm...m.m.",
    ], {"m": metal, "s": shine}, 14, 9)


def pickaxe():
    img = blank()
    for i in range(10):  # the handle, corner to corner
        px(img, 3 + i, 13 - i, "#8a5a2c")
        px(img, 4 + i, 13 - i, "#6a4020")
    for x, y in ((5, 3), (6, 2), (7, 2), (8, 2), (9, 2), (10, 3), (11, 4), (12, 5), (13, 7), (4, 4), (3, 5)):
        px(img, x, y, "#b8bcc8")
        px(img, x, y + 1, "#7a7e8a")
    return outline(img)


def battery_cell():
    return from_rows([
        "..pp..",
        ".PPPP.",
        ".PwwP.",
        ".PwwP.",
        ".PwwP.",
        ".PPPP.",
    ], {"p": "#c8c8d0", "P": "#7a4ab0", "w": "#c890ff"}, 10, 12)


def note():
    img = blank()
    rect(img, 3, 3, 13, 14, "#e8e0c8")
    rect(img, 3, 3, 13, 4, "#f8f4e8")
    for y in (6, 8, 10, 12):
        rect(img, 5, y, 11 if y != 12 else 9, y + 1, "#7a6a5a")
    return outline(img)


# ------------------------------------------------------------------ stations

def station(w, h, body, draw):
    img = blank(w, h)
    rect(img, 1, 2, w - 1, h - 1, body)
    rect(img, 1, 2, w - 1, 3, rgb(body) + 30)
    rect(img, 1, h - 2, w - 1, h - 1, rgb(body) - 40)
    draw(img)
    return outline(img)


def fusebox(img):
    rect(img, 3, 5, 13, 18, "#1a2028")
    for i, c in enumerate(["#e0584a", "#7bc043", "#f2c94c", "#7bc043"]):
        rect(img, 4 + i * 2, 7, 5 + i * 2, 11, "#8a8e96")
        px(img, 4 + i * 2, 7 + (i % 2) * 3, c)
    rect(img, 4, 14, 12, 15, "#f2c94c")
    rect(img, 4, 16, 12, 17, "#2a2a2a")


def safe(img):
    rect(img, 3, 6, 13, 20, "#4a4e56")
    for a in range(12):
        import math
        x = int(8 + 3 * math.cos(a / 12 * 6.283))
        y = int(13 + 3 * math.sin(a / 12 * 6.283))
        px(img, x, y, "#c8c8d0")
    px(img, 8, 13, "#f2c94c")
    rect(img, 11, 11, 12, 16, "#8a8e96")


def radio(img):
    rect(img, 3, 6, 13, 13, "#2a3a2a")
    for x in range(4, 12, 2):
        rect(img, x, 7, x + 1, 12, "#4a6a4a")
    for i, c in enumerate(["#e0584a", "#7bc043", "#3aa0e0", "#f2c94c"]):
        rect(img, 3 + i * 3, 16, 5 + i * 3, 18, c)
    rect(img, 12, 1, 13, 6, "#8a8e96")


def valves(img):
    rect(img, 2, 8, 14, 10, "#5a7a9a")
    rect(img, 7, 4, 9, 20, "#5a7a9a")
    for x, y in ((4, 9), (12, 9), (8, 5), (8, 17)):
        rect(img, x - 1, y - 1, x + 2, y + 2, "#c8402c")
        px(img, x, y, "#f0a090")


def board(img):
    rect(img, 2, 4, 14, 18, "#8a6a3a")
    for x, y, c in ((3, 5, "#e8e0c8"), (8, 6, "#f2c94c"), (4, 11, "#e8e0c8"), (9, 12, "#a0d0e8")):
        rect(img, x, y, x + 4, y + 4, c)
        px(img, x + 2, y, "#c8402c")


def conveyor(img):
    rect(img, 3, 5, 13, 11, "#1a2028")
    rect(img, 4, 6, 8, 7, "#7bc043")
    rect(img, 4, 8, 11, 9, "#3a5a3a")
    for i in range(4):
        rect(img, 3 + i * 3, 14, 5 + i * 3, 16, ["#8a8e96", "#e0584a", "#3aa0e0", "#7bc043"][i])


def mixer(img):
    rect(img, 3, 6, 13, 20, "#5a4a3a")
    for y, c in ((8, "#a07040"), (11, "#7a9a3a"), (14, "#a07040"), (17, "#5a8ac8")):
        rect(img, 4, y, 12, y + 2, c)


def workbench(img):
    rect(img, 1, 8, 15, 11, "#a87a4a")
    rect(img, 1, 8, 15, 9, "#c89a6a")
    rect(img, 2, 11, 4, 22, "#6a4a2a")
    rect(img, 12, 11, 14, 22, "#6a4a2a")
    rect(img, 4, 5, 6, 8, "#8a8e96")
    rect(img, 9, 4, 13, 8, "#5a5e66")
    rect(img, 10, 5, 12, 6, "#e0584a")


def lamp_post(img):
    rect(img, 7, 6, 9, 22, "#4a4e56")
    rect(img, 4, 2, 12, 7, "#2a2e36")
    rect(img, 5, 3, 11, 6, "#f2c94c")


STATIONS = {
    "fusebox": (fusebox, "#5a5e66"), "safe": (safe, "#3a3e46"), "radio": (radio, "#4a3a2a"),
    "valves": (valves, "#3a4a5a"), "board": (board, "#5a4030"), "conveyor": (conveyor, "#4a4e56"),
    "mixer": (mixer, "#3a3028"), "workbench": (workbench, None), "lamp_post": (lamp_post, None),
}


# ------------------------------------------------------------------ breakables

def cracked(wall_tile, seed):
    """The very wall tile of that place with a crack through it: a hidden
    room should only give itself away to someone looking closely."""
    r = np.random.default_rng(seed)
    img = wall_tile.copy()
    base = img[8, 8, :3].astype(np.int32)
    x, y = 8, 0
    while y < 16:  # a jagged crack down the middle, with a branch
        px(img, x, y, "#1a1210")
        px(img, x + 1, y, rgb(base) - 30)
        x = int(np.clip(x + r.choice([-1, 0, 1]), 3, 12))
        y += 1
    for i in range(5):
        px(img, 8 + i, 6 + i // 2, "#1a1210")
    return img


def vein(fleck, shine, seed):
    r = np.random.default_rng(seed)
    img = blank(16, 18)
    for y in range(3, 17):
        half = int(7 - abs(y - 10) * 0.55)
        rect(img, 8 - half, y, 8 + half, y + 1, "#6a5e54")
    rect(img, 3, 5, 9, 7, "#8a7e72")
    rect(img, 2, 15, 14, 17, "#4a4038")
    for _ in range(7):
        x, y = int(r.integers(4, 12)), int(r.integers(5, 14))
        rect(img, x, y, x + 2, y + 1, fleck)
        px(img, x, y, shine)
    return outline(img)


def hole():
    img = blank()
    for y in range(2, 15):
        half = int(6 - abs(y - 8) * 0.4)
        rect(img, 8 - half, y, 8 + half, y + 1, "#0a0808")
    for y in range(2, 15, 3):
        rect(img, 6, y, 10, y + 1, "#8a5a2c")
    rect(img, 5, 2, 6, 15, "#6a4020")
    rect(img, 10, 2, 11, 15, "#6a4020")
    return img


def bars(open_):
    img = blank()
    rect(img, 0, 0, 16, 2, "#3a3e46")
    rect(img, 0, 14, 16, 16, "#3a3e46")
    for x in range(1, 16, 3):
        if open_ and 4 <= x <= 11:
            continue
        rect(img, x, 2, x + 2, 14, "#8a8e96")
        rect(img, x, 2, x + 1, 14, "#b8bcc4")
    if not open_:
        rect(img, 6, 6, 10, 10, "#c8a040")
        px(img, 8, 8, "#2a1a10")
    return img


def main():
    items = ROOT / "assets/sprites/items"
    for name, icon in {
        "copper_ore": ore("#d8783a", "#ffc890"), "iron_ore": ore("#a85a3a", "#e0a080"),
        "crystal_shard": crystal(), "coal": coal(), "rusty_key": key("#a8783a", "#e0b070"),
        "metro_key": key("#3a8ad8", "#a0d0ff"), "pickaxe": pickaxe(), "rune_battery": battery_cell(),
        "note": note(),
    }.items():
        write_png(str(items / f"{name}.png"), icon)
    stations = ROOT / "assets/sprites/stations"
    stations.mkdir(parents=True, exist_ok=True)
    for name, (draw, body) in STATIONS.items():
        img = blank(16, 24) if body is None else None
        if body is None:
            draw(img)
            outline(img)
        else:
            img = station(16, 24, body, draw)
        write_png(str(stations / f"{name}.png"), img)
    breakables = ROOT / "assets/sprites/breakables"
    breakables.mkdir(parents=True, exist_ok=True)
    tilesets = ROOT / "assets/tilesets"
    for tileset in ("home", "office", "shack", "lab", "cave", "metro", "outpost", "factory", "industry"):
        atlas = read_png(str(tilesets / f"{tileset}_tiles.png"))
        for part, column in (("top", 4), ("face", 16)):
            wall = atlas[:, column * 16:(column + 1) * 16].copy()
            write_png(str(breakables / f"cracked_{tileset}_{part}.png"), cracked(wall, sum(map(ord, tileset)) + column))
    for name, (fleck, shine) in {"copper": ("#d8783a", "#ffc890"), "iron": ("#a85a3a", "#e0a080"),
                                 "crystal": ("#3aa8c8", "#e8ffff"), "coal": ("#1a1a20", "#5a5a68")}.items():
        write_png(str(breakables / f"vein_{name}.png"), vein(fleck, shine, len(name)))
    write_png(str(breakables / "hole.png"), hole())
    write_png(str(breakables / "bars_closed.png"), bars(False))
    write_png(str(breakables / "bars_open.png"), bars(True))
    print("drew icons, stations and breakables")


if __name__ == "__main__":
    main()
