#!/usr/bin/env python3
"""Draws the buildings you can walk into, one look per region, so each world
has its own architecture: the Outpost's brick cottage and plank shed, the
Factory's concrete office, the Dump's patchwork scrap shacks, the River's
stilt boathouse, the Fields' farmhouse and red barn, the Industry's bunker and
mine mouth, the Sanctuary's white stone lab, and the metro stairs under the
Outpost.

Walls, roofs and stonework are procedural pixel textures; doors, windows,
awnings and vents come from the Post-Apocalypse pack (art_src/, see
CREDITS.md). Every sprite is a whole number of tiles; its door sits at the
bottom centre, which is where the map places the building's marker.

Writes assets/sprites/buildings/<look>.png. Run from game/.
"""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pngio import read_png, write_png  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
PACK = ROOT / "art_src/lazystone/PostApocalypse_AssetPack_v1.1.2/Objects"
OUT = ROOT / "assets/sprites/buildings"
TILE = 16


def rgb(code):
    code = code.lstrip("#")
    return np.array([int(code[i:i + 2], 16) for i in (0, 2, 4)], np.int32)


def canvas(w, h):
    return np.zeros((h, w, 4), np.uint8)


def fill(img, x0, y0, x1, y1, colour):
    img[y0:y1, x0:x1, :3] = np.clip(colour, 0, 255)
    img[y0:y1, x0:x1, 3] = 255


def paste(img, sprite, x, y):
    h, w = sprite.shape[:2]
    x0, y0 = max(x, 0), max(y, 0)
    x1, y1 = min(x + w, img.shape[1]), min(y + h, img.shape[0])
    if x1 <= x0 or y1 <= y0:
        return
    part = sprite[y0 - y:y1 - y, x0 - x:x1 - x]
    alpha = part[:, :, 3:4] / 255.0
    target = img[y0:y1, x0:x1]
    target[:, :, :3] = (part[:, :, :3] * alpha + target[:, :, :3] * (1 - alpha)).astype(np.uint8)
    target[:, :, 3] = np.maximum(target[:, :, 3], part[:, :, 3])


def pack(name):
    for folder in ("", "Buildings", "Windows"):
        path = PACK / folder / name
        if path.exists():
            return read_png(str(path))
    raise FileNotFoundError(name)


# ------------------------------------------------------------------ textures

def bricks(w, h, base, mortar, seed):
    r = np.random.default_rng(seed)
    tex = canvas(w, h)
    fill(tex, 0, 0, w, h, rgb(mortar))
    b = rgb(base)
    for row, y in enumerate(range(0, h, 4)):
        offset = 4 if row % 2 else 0
        for x in range(-offset, w, 8):
            tone = b + r.integers(-14, 15)
            fill(tex, max(x, 0), y, min(x + 7, w), min(y + 3, h), tone)
            fill(tex, max(x, 0), y, min(x + 7, w), min(y + 1, h), tone + 16)
    return tex


def planks(w, h, base, seed, vertical=False):
    r = np.random.default_rng(seed)
    tex = canvas(w, h)
    b = rgb(base)
    step = 4
    for i, p in enumerate(range(0, w if vertical else h, step)):
        tone = b + r.integers(-12, 13)
        if vertical:
            fill(tex, p, 0, min(p + step, w), h, tone)
            fill(tex, p, 0, p + 1, h, tone - 30)
        else:
            fill(tex, 0, p, w, min(p + step, h), tone)
            fill(tex, 0, p + step - 1, w, min(p + step, h), tone - 30)
            for nail in range(3 + i % 5, w, 13):
                fill(tex, nail, p + 1, nail + 1, p + 2, tone - 40)
    return tex


def concrete(w, h, base, seed, panel=16):
    r = np.random.default_rng(seed)
    tex = canvas(w, h)
    b = rgb(base)
    noise = r.integers(-7, 8, size=(h, w))
    tex[:, :, 0] = np.clip(b[0] + noise, 0, 255)
    tex[:, :, 1] = np.clip(b[1] + noise, 0, 255)
    tex[:, :, 2] = np.clip(b[2] + noise, 0, 255)
    tex[:, :, 3] = 255
    for x in range(panel, w, panel):
        fill(tex, x, 0, x + 1, h, b - 26)
    for y in range(panel, h, panel):
        fill(tex, 0, y, w, y + 1, b - 26)
    for _ in range(max(w * h // 300, 2)):  # rust and water stains running down
        x, y = int(r.integers(0, w)), int(r.integers(0, h // 2))
        fill(tex, x, y, x + 1, min(y + int(r.integers(4, 12)), h), b - 34 + np.array([14, 0, -8]))
    return tex


def corrugated(w, h, base, seed, patches=()):
    r = np.random.default_rng(seed)
    tex = canvas(w, h)
    b = rgb(base)
    for x in range(w):
        tone = b + (18 if x % 3 == 0 else (-16 if x % 3 == 2 else 0))
        fill(tex, x, 0, x + 1, h, tone)
    for colour in patches:  # scrap sheets of other colours patched on
        pw, ph = int(r.integers(8, 18)), int(r.integers(6, 14))
        px, py = int(r.integers(0, max(w - pw, 1))), int(r.integers(0, max(h - ph, 1)))
        c = rgb(colour)
        for x in range(px, px + pw):
            tone = c + (18 if x % 3 == 0 else (-16 if x % 3 == 2 else 0))
            fill(tex, x, py, x + 1, py + ph, tone)
        fill(tex, px, py, px + pw, py + 1, c - 40)
    for _ in range(w * h // 120):  # rust spots
        x, y = int(r.integers(0, w)), int(r.integers(0, h))
        fill(tex, x, y, x + 2, y + 1, rgb("#8a4a2a"))
    return tex


def shingles(w, h, base, seed):
    r = np.random.default_rng(seed)
    tex = canvas(w, h)
    b = rgb(base)
    for row, y in enumerate(range(0, h, 4)):
        depth = -int(18 * (1 - y / max(h, 1)))  # rows further up the slope are darker
        offset = 3 if row % 2 else 0
        for x in range(-offset, w, 6):
            tone = b + depth + r.integers(-10, 11)
            fill(tex, max(x, 0), y, min(x + 6, w), min(y + 4, h), tone)
            fill(tex, max(x, 0), min(y + 3, h - 1), min(x + 6, w), min(y + 4, h), tone - 34)
            fill(tex, max(x, 0), y, max(x, 0) + 1, min(y + 4, h), tone - 22)
    return tex


def stone(w, h, base, seed):
    r = np.random.default_rng(seed)
    tex = canvas(w, h)
    b = rgb(base)
    fill(tex, 0, 0, w, h, b - 40)
    for row, y in enumerate(range(0, h, 7)):
        offset = 6 if row % 2 else 0
        for x in range(-offset, w, 12):
            tone = b + r.integers(-8, 9)
            fill(tex, max(x, 0), y, min(x + 11, w), min(y + 6, h), tone)
            fill(tex, max(x, 0), y, min(x + 11, w), min(y + 1, h), tone + 14)
    return tex


# ------------------------------------------------------------------ building

def building(spec):
    w, h = spec["tiles"][0] * TILE, spec["tiles"][1] * TILE
    img = canvas(w, h)
    seed = spec.get("seed", 1)
    roof_h = spec.get("roof", h // 2)
    inset = 2
    wall_top = roof_h - 2
    base_h = 3

    # Walls
    wall = spec["wall"](w - inset * 2, h - wall_top, seed)
    paste(img, wall, inset, wall_top)
    corner = rgb(spec.get("corner", "#2c1d35"))
    fill(img, inset, wall_top, inset + 2, h, corner)
    fill(img, w - inset - 2, wall_top, w - inset, h, corner)
    fill(img, inset, h - base_h, w - inset, h, rgb(spec.get("base", "#4a4048")))
    fill(img, inset, h - base_h, w - inset, h - base_h + 1, rgb(spec.get("base", "#4a4048")) + 20)

    # Roof: overhangs the walls, a ridge on top, a deep shadow under the eave.
    roof = spec["roof_tex"](w, roof_h, seed + 7)
    paste(img, roof, 0, 0)
    fill(img, 0, 0, w, 2, rgb(spec.get("ridge", "#d8c8a8")))
    fill(img, 0, roof_h - 2, w, roof_h, rgb("#1a1018"))
    fill(img, inset, roof_h, w - inset, roof_h + 2, rgb("#000000") + 30)
    img[roof_h:roof_h + 2, inset:w - inset, :3] = (img[roof_h:roof_h + 2, inset:w - inset, :3] * 0.55).astype(np.uint8)

    # Windows either side of the door, with a warm glow behind the glass.
    door = pack(spec.get("door", "Door_1_Beige.png"))
    window = pack(spec.get("window", "Window_3_wood.png")) if spec.get("window") != "none" else None
    wall_h = h - roof_h
    if window is not None:
        wy = roof_h + max((wall_h - base_h - window.shape[0]) // 2 - 1, 2)
        spots = spec.get("windows", [w // 4, 3 * w // 4])
        for cx in spots:
            x = cx - window.shape[1] // 2
            fill(img, x + 2, wy + 2, x + window.shape[1] - 2, wy + window.shape[0] - 2, rgb("#f0c060"))
            paste(img, window, x, wy)
    for extra in spec.get("extras", []):
        extra(img, w, h, roof_h)
    if door is not None:
        dx = w // 2 - door.shape[1] // 2
        dy = h - door.shape[0] - 1
        fill(img, dx - 1, dy - 1, dx + door.shape[1] + 1, h - 1, rgb("#1a1018"))
        paste(img, door, dx, dy)
        fill(img, dx - 2, h - 2, dx + door.shape[1] + 2, h, rgb(spec.get("step", "#6a6070")))
    return img


# ------------------------------------------------------------------ extras

def chimney(colour="#7a4a3a", x_frac=0.75):
    def draw(img, w, _h, roof_h):
        x = int(w * x_frac)
        brick = bricks(8, roof_h // 2 + 4, colour, "#3a2a2a", 5)
        paste(img, brick, x, 0)
        fill(img, x - 1, 0, x + 9, 2, rgb("#2a2020"))
    return draw


def sign(colour="#8a6a3a"):
    def draw(img, w, _h, roof_h):
        fill(img, w // 2 - 10, roof_h + 2, w // 2 + 10, roof_h + 7, rgb(colour))
        fill(img, w // 2 - 10, roof_h + 2, w // 2 + 10, roof_h + 3, rgb(colour) + 30)
        for x in range(w // 2 - 7, w // 2 + 8, 3):
            fill(img, x, roof_h + 4, x + 2, roof_h + 5, rgb("#2a1a14"))
    return draw


def pasted(name, x_frac, y_from_roof):
    def draw(img, w, _h, roof_h):
        sprite = pack(name)
        paste(img, sprite, int(w * x_frac) - sprite.shape[1] // 2, roof_h + y_from_roof)
    return draw


def on_roof(name, x_frac, y):
    def draw(img, w, _h, _roof_h):
        sprite = pack(name)
        paste(img, sprite, int(w * x_frac) - sprite.shape[1] // 2, y)
    return draw


def flower_box(x_frac):
    def draw(img, w, h, _roof_h):
        x = int(w * x_frac) - 7
        y = h - 12
        fill(img, x, y, x + 14, y + 3, rgb("#6a4a2a"))
        for i, c in enumerate(["#e0584a", "#f2c94c", "#7bc043", "#e0584a", "#7bc043"]):
            fill(img, x + 1 + i * 3, y - 2, x + 3 + i * 3, y, rgb(c))
    return draw


def hazard_stripe():
    def draw(img, w, h, _roof_h):
        y = h - 7
        for x in range(2, w - 2):
            fill(img, x, y, x + 1, y + 2, rgb("#f2c94c") if (x // 3) % 2 == 0 else rgb("#2a2a2a"))
    return draw


def moss(seed):
    def draw(img, w, _h, roof_h):
        r = np.random.default_rng(seed)
        for _ in range(w // 2):
            x, y = int(r.integers(0, w)), int(r.integers(0, roof_h))
            fill(img, x, y, x + int(r.integers(1, 4)), y + 1, rgb("#5a9a5a") + int(r.integers(-20, 20)))
    return draw


def stilts():
    def draw(img, w, h, _roof_h):
        for x in (4, w - 7):
            fill(img, x, h - 6, x + 3, h, rgb("#4a3020"))
    return draw


# ------------------------------------------------------------------ looks

LOOKS = {
    "outpost_house": {
        "tiles": (5, 5), "roof": 38, "seed": 11,
        "wall": lambda w, h, s: bricks(w, h, "#9a5a44", "#5a3a34", s),
        "roof_tex": lambda w, h, s: shingles(w, h, "#7a4038", s), "ridge": "#a86050",
        "door": "Door_1_Beige.png", "window": "Window_15_Beige.png",
        "extras": [chimney(), flower_box(0.25)],
    },
    "outpost_shed": {
        "tiles": (4, 4), "roof": 28, "seed": 12,
        "wall": lambda w, h, s: planks(w, h, "#7a5a3a", s),
        "roof_tex": lambda w, h, s: corrugated(w, h, "#6a6a78", s), "ridge": "#9a9aa8",
        "door": "Door_2_Ajar_Beige.png", "window": "Window_5_Boarded-up_wood.png", "windows": [12],
    },
    "metro_stairs": {
        "tiles": (4, 3), "roof": 18, "seed": 13,
        "wall": lambda w, h, s: concrete(w, h, "#6a6a70", s, 8),
        "roof_tex": lambda w, h, s: concrete(w, h, "#4a4a52", s, 64), "ridge": "#2a6aa8",
        "door": "Door_6_Boarded-up_Metal.png", "window": "none", "extras": [sign("#2a6aa8")],
    },
    "factory_office": {
        "tiles": (6, 5), "roof": 30, "seed": 21,
        "wall": lambda w, h, s: concrete(w, h, "#8a8e9a", s),
        "roof_tex": lambda w, h, s: concrete(w, h, "#5a5e6a", s, 32), "ridge": "#a0a4b0",
        "door": "Door_4_Metal.png", "window": "Window_9_gray.png", "windows": [16, 32, 64, 80],
        "extras": [on_roof("Air-vent_1.png", 0.3, 6), on_roof("Air-vent_2_rusty.png", 0.75, 8), hazard_stripe()],
    },
    "dump_shack": {
        "tiles": (5, 4), "roof": 28, "seed": 31,
        "wall": lambda w, h, s: corrugated(w, h, "#7a6a50", s, ("#4a6a8a", "#8a3a2a", "#5a7a4a")),
        "roof_tex": lambda w, h, s: corrugated(w, h, "#8a4a2a", s, ("#6a6a78",)), "ridge": "#b06a40",
        "door": "Door_5_Rusty_Metal.png", "window": "Window_7_broken_gray.png", "windows": [14],
        "extras": [pasted("Awning_orange_1.png", 0.78, 2)],
    },
    "dump_hall": {
        "tiles": (6, 4), "roof": 26, "seed": 32,
        "wall": lambda w, h, s: corrugated(w, h, "#5a6a78", s, ("#7a6a50", "#4a5a3a")),
        "roof_tex": lambda w, h, s: corrugated(w, h, "#6a3a2a", s, ("#7a7a88", "#4a6a8a")), "ridge": "#9a5a3a",
        "door": "Door_4_Metal.png", "window": "Window_19_gray.png", "windows": [18, 78],
        "extras": [sign("#7a4a2a"), hazard_stripe()],
    },
    "river_boathouse": {
        "tiles": (5, 5), "roof": 36, "seed": 41,
        "wall": lambda w, h, s: planks(w, h, "#5a4a38", s, vertical=True),
        "roof_tex": lambda w, h, s: shingles(w, h, "#4a5a48", s), "ridge": "#7a8a68",
        "door": "Door_2_Ajar_Beige.png", "window": "Window_3_wood.png",
        "extras": [stilts(), moss(4)],
    },
    "fields_farmhouse": {
        "tiles": (6, 5), "roof": 38, "seed": 51,
        "wall": lambda w, h, s: planks(w, h, "#d8cfb8", s),
        "roof_tex": lambda w, h, s: shingles(w, h, "#8a3a2c", s), "ridge": "#c0604a",
        "door": "Door_1_Beige.png", "window": "Window_16_Beige.png",
        "extras": [chimney("#8a7a6a", 0.2), flower_box(0.75)],
    },
    "fields_barn": {
        "tiles": (6, 5), "roof": 34, "seed": 52,
        "wall": lambda w, h, s: planks(w, h, "#a83a2c", s, vertical=True),
        "roof_tex": lambda w, h, s: shingles(w, h, "#4a3a3a", s), "ridge": "#e8e0d0",
        "door": "Door_2_Ajar_Beige.png", "window": "Window_1_broken_wood.png", "windows": [20, 76],
    },
    "industry_bunker": {
        "tiles": (5, 4), "roof": 22, "seed": 61,
        "wall": lambda w, h, s: concrete(w, h, "#4a4a50", s),
        "roof_tex": lambda w, h, s: concrete(w, h, "#2a2a30", s, 24), "ridge": "#e0a030",
        "door": "Door_6_Boarded-up_Metal.png", "window": "Window_11_Boarded-up_gray.png", "windows": [16, 64],
        "extras": [hazard_stripe(), on_roof("Antenna_1.png", 0.8, 0)],
    },
    "mine_mouth": {
        "tiles": (4, 3), "roof": 22, "seed": 62,
        "wall": lambda w, h, s: stone(w, h, "#5a5048", s),
        "roof_tex": lambda w, h, s: stone(w, h, "#6a5e52", s), "ridge": "#7a6e60",
        "door": "Door_5_Rusty_Metal.png", "window": "none", "extras": [sign("#6a4a2a")],
    },
    "sanctuary_lab": {
        "tiles": (6, 5), "roof": 30, "seed": 71,
        "wall": lambda w, h, s: stone(w, h, "#d8dcd0", s),
        "roof_tex": lambda w, h, s: concrete(w, h, "#9ab0a0", s, 48), "ridge": "#e8f4ec",
        "door": "Door_4_Metal.png", "window": "Window_10_gray.png", "windows": [18, 78],
        "extras": [moss(8)], "corner": "#8a9a90", "base": "#7a8a80",
    },
}


def main():
    OUT.mkdir(parents=True, exist_ok=True)
    for look, spec in LOOKS.items():
        write_png(str(OUT / f"{look}.png"), building(spec))
    print(f"drew {len(LOOKS)} buildings into {OUT}")


if __name__ == "__main__":
    main()
