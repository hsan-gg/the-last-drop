#!/usr/bin/env python3
"""Generates the placeholder pixel art for The Last Drop (numpy + stdlib only).

Run from the game/ folder:  python3 tools/generate_assets.py
Output goes to assets/. Replace any PNG with hand-made art of the same size
and the game picks it up unchanged.
"""
import random
import struct
import zlib
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parent.parent
SPRITES = ROOT / "assets" / "sprites"
TILESETS = ROOT / "assets" / "tilesets"

TILE = 16


def hexc(value, alpha=255):
    value = value.lstrip("#")
    return (int(value[0:2], 16), int(value[2:4], 16), int(value[4:6], 16), alpha)


# Palette: dusk oranges against teal, the colours of the concept dossier.
OUTLINE = hexc("#14181f")
INK = hexc("#1b2530")
TEAL = hexc("#1b8f86")
TEAL_LIGHT = hexc("#5fd0c4")
ORANGE = hexc("#f08a24")
ORANGE_DARK = hexc("#b5601a")
RUST = hexc("#8a4a2b")
RUST_DARK = hexc("#5e3220")
STEEL = hexc("#7b8794")
STEEL_DARK = hexc("#4a5460")
STEEL_LIGHT = hexc("#aab4be")
WHITE = hexc("#e8eef2")
YELLOW = hexc("#f2c94c")
RED = hexc("#c0392b")
GREEN = hexc("#7bc043")
SKIN = hexc("#e0a878")
BROWN = hexc("#6b4428")
BROWN_LIGHT = hexc("#8c5e3a")
JACKET = hexc("#3b5a78")
JACKET_DARK = hexc("#2a4058")
JEANS = hexc("#33415c")
CLEAR = (0, 0, 0, 0)


class Canvas:
    def __init__(self, width, height, fill=CLEAR):
        self.w, self.h = width, height
        self.a = np.zeros((height, width, 4), dtype=np.uint8)
        self.a[:, :] = fill

    def px(self, x, y, c):
        if 0 <= x < self.w and 0 <= y < self.h:
            self.a[y, x] = c

    def rect(self, x0, y0, x1, y1, c):
        """Fill [x0, x1) x [y0, y1)."""
        x0, y0 = max(x0, 0), max(y0, 0)
        x1, y1 = min(x1, self.w), min(y1, self.h)
        if x1 > x0 and y1 > y0:
            self.a[y0:y1, x0:x1] = c

    def circle(self, cx, cy, r, c):
        for y in range(int(cy - r) - 1, int(cy + r) + 2):
            for x in range(int(cx - r) - 1, int(cx + r) + 2):
                if (x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2 <= r * r:
                    self.px(x, y, c)

    def line(self, x0, y0, x1, y1, c):
        steps = max(abs(x1 - x0), abs(y1 - y0), 1)
        for i in range(steps + 1):
            self.px(round(x0 + (x1 - x0) * i / steps), round(y0 + (y1 - y0) * i / steps), c)

    def outline(self, c=OUTLINE):
        solid = self.a[:, :, 3] > 0
        grown = solid.copy()
        grown[1:, :] |= solid[:-1, :]
        grown[:-1, :] |= solid[1:, :]
        grown[:, 1:] |= solid[:, :-1]
        grown[:, :-1] |= solid[:, 1:]
        edge = grown & ~solid
        self.a[edge] = c

    def blit(self, other, x, y):
        for j in range(other.h):
            for i in range(other.w):
                if other.a[j, i, 3] > 0:
                    self.px(x + i, y + j, other.a[j, i])

    def save(self, path):
        path.parent.mkdir(parents=True, exist_ok=True)
        raw = b"".join(b"\x00" + self.a[y].tobytes() for y in range(self.h))

        def chunk(kind, data):
            body = kind + data
            return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

        png = (
            b"\x89PNG\r\n\x1a\n"
            + chunk(b"IHDR", struct.pack(">IIBBBBB", self.w, self.h, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9))
            + chunk(b"IEND", b"")
        )
        path.write_bytes(png)


def jitter(base, rng, amount):
    delta = rng.randint(-amount, amount)
    return tuple(max(0, min(255, base[i] + delta)) for i in range(3)) + (255,)


def speckled(base, rng, amount=6, speckle=None, density=0.08):
    tile = Canvas(TILE, TILE)
    for y in range(TILE):
        for x in range(TILE):
            tile.px(x, y, jitter(base, rng, amount))
    if speckle:
        for _ in range(int(TILE * TILE * density)):
            tile.px(rng.randrange(TILE), rng.randrange(TILE), speckle)
    return tile


# ---------------------------------------------------------------- tiles
GROUND = hexc("#4d4540")
GROUND_LIGHT = hexc("#625850")
GROUND_DARK = hexc("#3a332f")


def tile_ground_a(rng):
    return speckled(GROUND, rng, 5, GROUND_DARK, 0.06)


def tile_ground_b(rng):
    t = speckled(GROUND, rng, 4)
    for _ in range(4):
        x, y = rng.randrange(1, 14), rng.randrange(1, 14)
        t.rect(x, y, x + 2, y + 1, GROUND_LIGHT)
        t.px(x, y + 1, GROUND_DARK)
    return t


def tile_ground_c(rng):
    t = speckled(GROUND, rng, 4, GROUND_DARK, 0.04)
    x, y = rng.randrange(2, 6), rng.randrange(3, 12)
    for _ in range(9):
        t.px(x, y, GROUND_DARK)
        x += rng.choice([1, 1, 0])
        y += rng.choice([-1, 0, 1])
    return t


def tile_rubble(rng):
    t = speckled(GROUND, rng, 4)
    colours = [TEAL, STEEL, ORANGE_DARK, STEEL_LIGHT, RUST, hexc("#5a7fa0")]
    for _ in range(9):
        x, y = rng.randrange(1, 14), rng.randrange(1, 14)
        c = rng.choice(colours)
        t.rect(x, y, x + rng.randint(1, 3), y + rng.randint(1, 2), c)
    return t


def tile_wall(rng):
    t = Canvas(TILE, TILE, hexc("#2e2724"))
    for row in range(4):
        y = row * 4
        offset = 4 if row % 2 else 0
        for bx in range(-1, 3):
            x = bx * 8 + offset
            t.rect(x + 1, y + 1, x + 8, y + 4, jitter(hexc("#6d5448"), rng, 10))
            t.rect(x + 1, y + 1, x + 8, y + 2, hexc("#85685a"))
    return t


def tile_water(rng):
    t = speckled(hexc("#3d5d52"), rng, 5)
    for _ in range(5):
        x, y = rng.randrange(0, 12), rng.randrange(1, 15)
        t.rect(x, y, x + rng.randint(3, 5), y + 1, hexc("#5b8372"))
    for _ in range(2):
        x, y = rng.randrange(1, 13), rng.randrange(1, 15)
        t.rect(x, y, x + 2, y + 1, hexc("#7a5d86"))
    return t


def tile_grass(rng):
    t = speckled(GROUND, rng, 4)
    for _ in range(7):
        x, y = rng.randrange(1, 15), rng.randrange(3, 15)
        c = rng.choice([hexc("#8b7a3a"), hexc("#6e6330"), hexc("#a08a42")])
        t.line(x, y, x + rng.choice([-1, 0, 1]), y - 2, c)
    return t


def tile_concrete(rng):
    t = speckled(hexc("#6a6b6c"), rng, 4)
    t.rect(0, 0, TILE, 1, hexc("#7c7d7e"))
    t.rect(0, 0, 1, TILE, hexc("#7c7d7e"))
    t.rect(0, 15, TILE, 16, hexc("#55565a"))
    t.rect(15, 0, 16, TILE, hexc("#55565a"))
    return t


def tile_path(rng):
    return speckled(hexc("#8d7650"), rng, 5, hexc("#a38b60"), 0.07)


def tile_crate(_rng):
    t = Canvas(TILE, TILE, hexc("#8a6038"))
    t.rect(0, 0, TILE, 2, hexc("#a77a4a"))
    t.rect(0, 14, TILE, TILE, hexc("#5e3f22"))
    t.rect(0, 0, 2, TILE, hexc("#6e4a2a"))
    t.rect(14, 0, TILE, TILE, hexc("#6e4a2a"))
    t.line(2, 2, 13, 13, hexc("#5e3f22"))
    t.line(13, 2, 2, 13, hexc("#5e3f22"))
    t.rect(7, 7, 9, 9, hexc("#d9b36b"))
    return t


def tile_fence(rng):
    t = speckled(GROUND, rng, 4)
    for x in (2, 8, 14):
        t.rect(x - 1, 2, x + 1, 15, hexc("#5a4a3c"))
        t.rect(x - 1, 2, x, 15, hexc("#76624f"))
    t.line(0, 5, 15, 5, STEEL_DARK)
    t.line(0, 10, 15, 10, STEEL_DARK)
    return t


def tile_pipe(rng):
    t = speckled(GROUND, rng, 4)
    t.rect(0, 5, TILE, 12, STEEL_DARK)
    t.rect(0, 5, TILE, 7, STEEL)
    t.rect(0, 6, TILE, 7, STEEL_LIGHT)
    t.rect(6, 4, 8, 13, STEEL_DARK)
    return t


def tile_metal(rng):
    t = speckled(hexc("#434b55"), rng, 3)
    t.rect(0, 0, TILE, 1, hexc("#59626d"))
    t.rect(0, 15, TILE, 16, hexc("#2f353d"))
    for x, y in ((2, 2), (13, 2), (2, 13), (13, 13)):
        t.px(x, y, hexc("#7a8591"))
    return t


def tile_dark_floor(rng):
    return speckled(hexc("#2d3037"), rng, 3, hexc("#22252b"), 0.08)


def tile_toxic(rng):
    t = tile_dark_floor(rng)
    t.circle(8, 8, 5.5, hexc("#3f6b2a"))
    t.circle(7, 7, 3.2, hexc("#6fae3a"))
    t.px(6, 6, hexc("#b9e36e"))
    t.px(10, 9, hexc("#b9e36e"))
    return t


def tile_tree(rng):
    t = speckled(GROUND, rng, 4)
    t.rect(7, 7, 10, 15, hexc("#2d2420"))
    t.rect(7, 7, 8, 15, hexc("#47372f"))
    t.line(8, 8, 3, 2, hexc("#2d2420"))
    t.line(9, 9, 13, 3, hexc("#2d2420"))
    t.line(8, 6, 8, 1, hexc("#2d2420"))
    t.line(4, 4, 2, 4, hexc("#2d2420"))
    t.line(12, 5, 14, 6, hexc("#2d2420"))
    return t


def tile_barrel(rng):
    t = speckled(GROUND, rng, 4)
    t.rect(3, 2, 13, 14, RUST)
    t.rect(3, 2, 13, 4, hexc("#a8623a"))
    t.rect(3, 6, 13, 7, RUST_DARK)
    t.rect(3, 10, 13, 11, RUST_DARK)
    t.rect(3, 2, 4, 14, hexc("#a8623a"))
    t.rect(12, 2, 13, 14, RUST_DARK)
    t.circle(8, 8, 1.6, YELLOW)
    return t


def tile_rack(_rng):
    t = Canvas(TILE, TILE, hexc("#2d3037"))
    t.rect(1, 1, 15, 15, STEEL_DARK)
    for y in (1, 8):
        t.rect(1, y, 15, y + 1, STEEL)
    t.rect(2, 3, 7, 8, hexc("#9a6b3b"))
    t.rect(8, 4, 14, 8, hexc("#7d8a96"))
    t.rect(2, 10, 9, 15, hexc("#b5601a"))
    t.rect(10, 10, 14, 15, hexc("#5a6b7a"))
    return t


TILE_BUILDERS = [
    tile_ground_a, tile_ground_b, tile_ground_c, tile_rubble, tile_wall, tile_water,
    tile_grass, tile_concrete, tile_path, tile_crate, tile_fence, tile_pipe,
    tile_metal, tile_dark_floor, tile_toxic, tile_tree, tile_barrel, tile_rack,
]


def build_tileset():
    rng = random.Random(1234)
    sheet = Canvas(TILE * len(TILE_BUILDERS), TILE)
    for index, builder in enumerate(TILE_BUILDERS):
        sheet.blit(builder(rng), index * TILE, 0)
    sheet.save(TILESETS / "outpost_tiles.png")


# ---------------------------------------------------------------- player
def draw_player(direction, frame):
    """One 16x16 frame. direction: down, up, left, right. frame: 0 idle, 1/2 walk."""
    c = Canvas(16, 16)
    step = {0: (0, 0), 1: (-1, 1), 2: (1, -1)}[frame]
    bob = 1 if frame else 0

    # legs
    if direction in ("down", "up"):
        c.rect(5, 11 + max(step[0], 0), 7, 15, JEANS)
        c.rect(9, 11 + max(step[1], 0), 11, 15, JEANS)
        c.rect(5, 14, 7, 15, BROWN)
        c.rect(9, 14, 11, 15, BROWN)
        if frame:
            c.rect(5, 15 if step[0] < 0 else 14, 7, 15, BROWN)
    else:
        c.rect(6 + step[0], 11, 9 + step[0], 15, JEANS)
        c.rect(7 + step[1], 11, 10 + step[1], 15, hexc("#2a3650"))
        c.rect(6 + step[0], 14, 10 + step[0], 15, BROWN)

    # torso
    top = 6 + bob
    c.rect(4, top, 12, 12, JACKET)
    c.rect(4, top, 12, top + 1, hexc("#4f729a"))
    c.rect(4, 11, 12, 12, JACKET_DARK)
    # arms
    if direction in ("down", "up"):
        c.rect(3, top + 1, 4, 11, JACKET_DARK)
        c.rect(12, top + 1, 13, 11, JACKET_DARK)
    else:
        arm_x = 7 + (step[0] if frame else 0)
        c.rect(arm_x, top + 2, arm_x + 2, 11, JACKET_DARK)

    # backpack (the dossier's brown backpack)
    if direction == "up":
        c.rect(4, top, 12, 12, BROWN)
        c.rect(4, top, 12, top + 1, BROWN_LIGHT)
        c.rect(6, top + 3, 10, 12, hexc("#563620"))
    elif direction == "left":
        c.rect(9, top, 13, 12, BROWN)
        c.rect(9, top, 13, top + 1, BROWN_LIGHT)
    elif direction == "right":
        c.rect(3, top, 7, 12, BROWN)
        c.rect(3, top, 7, top + 1, BROWN_LIGHT)

    # head
    head_y = 1 + bob
    c.rect(5, head_y, 11, head_y + 6, SKIN)
    hair = hexc("#5a3a22")
    if direction == "down":
        c.rect(5, head_y, 11, head_y + 2, hair)
        c.rect(5, head_y, 6, head_y + 3, hair)
        c.rect(10, head_y, 11, head_y + 3, hair)
        c.px(6, head_y + 3, INK)
        c.px(9, head_y + 3, INK)
    elif direction == "up":
        c.rect(5, head_y, 11, head_y + 5, hair)
        c.rect(5, head_y + 5, 11, head_y + 6, SKIN)
    else:
        c.rect(5, head_y, 11, head_y + 2, hair)
        c.rect(5 if direction == "left" else 9, head_y, 7 if direction == "left" else 11, head_y + 4, hair)
        eye_x = 6 if direction == "left" else 9
        c.px(eye_x, head_y + 3, INK)

    c.outline()
    return c


def build_player():
    sheet = Canvas(48, 64)
    for row, direction in enumerate(("down", "up", "left", "right")):
        for frame in range(3):
            sheet.blit(draw_player(direction, frame), frame * 16, row * 16)
    sheet.save(SPRITES / "player.png")


# ----------------------------------------------------------------- items
def item_battery():
    c = Canvas(16, 16)
    c.rect(4, 4, 12, 14, TEAL)
    c.rect(4, 4, 6, 14, TEAL_LIGHT)
    c.rect(6, 2, 10, 4, STEEL_LIGHT)
    c.rect(4, 8, 12, 10, INK)
    c.px(8, 6, YELLOW)
    c.rect(7, 11, 9, 13, YELLOW)
    c.px(13, 12, GREEN)
    c.px(13, 13, GREEN)
    c.px(14, 14, GREEN)
    return c


def item_chemical_can():
    c = Canvas(16, 16)
    c.rect(4, 4, 12, 14, RED)
    c.rect(4, 4, 6, 14, hexc("#e0584a"))
    c.rect(5, 2, 11, 4, STEEL)
    c.rect(9, 1, 12, 2, STEEL_LIGHT)
    c.rect(5, 7, 11, 12, YELLOW)
    c.circle(8, 9, 1.6, INK)
    c.px(7, 11, INK)
    c.px(9, 11, INK)
    return c


def item_plastic_bottle():
    c = Canvas(16, 16)
    c.rect(6, 1, 10, 3, hexc("#3a78c0"))
    c.rect(7, 3, 9, 5, hexc("#a9d6f0"))
    c.rect(5, 5, 11, 14, hexc("#a9d6f0"))
    c.rect(5, 5, 7, 14, WHITE)
    c.rect(5, 8, 11, 10, hexc("#3a78c0"))
    return c


def item_scrap_metal():
    c = Canvas(16, 16)
    c.rect(2, 4, 14, 12, STEEL)
    c.rect(2, 4, 14, 6, STEEL_LIGHT)
    c.rect(2, 11, 14, 12, STEEL_DARK)
    c.px(3, 5, STEEL_DARK)
    c.px(12, 5, STEEL_DARK)
    c.px(3, 10, STEEL_DARK)
    c.px(12, 10, STEEL_DARK)
    c.line(6, 6, 9, 10, RUST)
    return c


def item_pipe_section():
    c = Canvas(16, 16)
    c.rect(1, 5, 15, 12, STEEL)
    c.rect(1, 5, 15, 7, STEEL_LIGHT)
    c.rect(1, 11, 15, 12, STEEL_DARK)
    for x in (3, 11):
        c.rect(x, 4, x + 2, 13, STEEL_DARK)
    c.rect(1, 6, 2, 11, INK)
    return c


def item_copper_wire():
    c = Canvas(16, 16)
    c.circle(8, 8, 6, ORANGE_DARK)
    c.circle(8, 8, 4.2, ORANGE)
    c.circle(8, 8, 2, ORANGE_DARK)
    c.circle(8, 8, 1, INK)
    c.line(13, 11, 15, 14, ORANGE)
    return c


def item_glass_shard():
    c = Canvas(16, 16)
    pale = hexc("#bfe6ee")
    for y in range(3, 14):
        width = (y - 3) // 2 + 1
        c.rect(7 - width // 2, y, 7 - width // 2 + width + 1, y + 1, pale)
    c.line(7, 4, 7, 10, WHITE)
    c.line(11, 9, 14, 13, hexc("#9acdd8"))
    return c


ITEM_BUILDERS = {
    "battery": item_battery,
    "chemical_can": item_chemical_can,
    "plastic_bottle": item_plastic_bottle,
    "scrap_metal": item_scrap_metal,
    "pipe_section": item_pipe_section,
    "copper_wire": item_copper_wire,
    "glass_shard": item_glass_shard,
}


def build_items():
    for name, builder in ITEM_BUILDERS.items():
        canvas = builder()
        canvas.outline()
        canvas.save(SPRITES / "items" / f"{name}.png")


# ------------------------------------------------------------------ bins
def bin_icon(body, lid, mark):
    c = Canvas(24, 24)
    c.rect(4, 7, 20, 22, body)
    c.rect(4, 7, 8, 22, tuple(min(255, v + 25) for v in body[:3]) + (255,))
    c.rect(3, 4, 21, 7, lid)
    c.rect(10, 2, 14, 4, lid)
    mark(c)
    c.outline()
    return c


def mark_general(c):
    for x in (8, 12, 16):
        c.rect(x, 10, x + 1, 19, STEEL_DARK)


def mark_hazard(c):
    for i in range(7):
        c.rect(12 - i, 10 + i, 13 + i, 11 + i, YELLOW)
    c.rect(11, 13, 13, 17, INK)
    c.px(11, 18, INK)
    c.px(12, 18, INK)


def mark_recovery(c):
    c.circle(12, 15, 4.5, WHITE)
    c.circle(12, 15, 2.5, TEAL)
    c.rect(11, 9, 14, 11, WHITE)


def build_bins():
    bin_icon(STEEL, STEEL_DARK, mark_general).save(SPRITES / "bins" / "general.png")
    bin_icon(hexc("#9b3b30"), hexc("#6c2820"), mark_hazard).save(SPRITES / "bins" / "hazardous.png")
    bin_icon(TEAL, hexc("#126b64"), mark_recovery).save(SPRITES / "bins" / "recovery.png")


# ----------------------------------------------------------------- props
def scatter_pile(w, h, rng):
    c = Canvas(w, h)
    colours = [STEEL, STEEL_DARK, RUST, TEAL, ORANGE_DARK, STEEL_LIGHT, hexc("#5a7fa0"), BROWN]
    for y in range(h):
        span = (y + 1) / h
        half = int(span * w / 2) - 1
        for x in range(w // 2 - half, w // 2 + half + 1):
            c.px(x, y, rng.choice(colours))
    for _ in range(w):
        x, y = rng.randrange(w), rng.randrange(h)
        if c.a[y, x, 3]:
            c.px(x, y, rng.choice([STEEL_LIGHT, YELLOW, ORANGE]))
    c.outline()
    return c


def machine(w, h, body, accent, light):
    c = Canvas(w, h)
    c.rect(2, 6, w - 2, h - 2, body)
    c.rect(2, 6, w - 2, 9, tuple(min(255, v + 25) for v in body[:3]) + (255,))
    c.rect(4, 11, w - 12, h - 6, INK)
    c.rect(5, 12, w - 13, h - 7, accent)
    c.rect(w - 9, 12, w - 5, 16, light)
    c.rect(w - 9, 18, w - 5, 20, STEEL_LIGHT)
    c.rect(4, 0, 8, 7, STEEL_DARK)
    c.rect(w - 10, 2, w - 6, 7, STEEL_DARK)
    c.outline()
    return c


def build_props():
    rng = random.Random(7)
    scatter_pile(28, 20, rng).save(SPRITES / "scrap_pile.png")

    machine(32, 32, RUST, hexc("#5a2a22"), RED).save(SPRITES / "treatment_unit_broken.png")
    machine(32, 32, STEEL, hexc("#2c7f8a"), GREEN).save(SPRITES / "treatment_unit_fixed.png")
    machine(32, 28, RUST_DARK, hexc("#3a2a22"), RED).save(SPRITES / "generator_broken.png")
    machine(32, 28, hexc("#6b7480"), hexc("#b5601a"), GREEN).save(SPRITES / "generator_fixed.png")

    for name, base, shine in (("water_dirty", hexc("#46604a"), hexc("#7a5d86")), ("water_clean", hexc("#3a86c0"), hexc("#a9e0f5"))):
        c = Canvas(48, 28)
        c.circle(24, 14, 13, base)
        c.rect(6, 6, 42, 22, base)
        for _ in range(10):
            x, y = rng.randrange(8, 38), rng.randrange(7, 21)
            c.rect(x, y, x + rng.randint(3, 6), y + 1, shine)
        c.outline()
        c.save(SPRITES / f"{name}.png")

    recorder = Canvas(16, 16)
    recorder.rect(3, 4, 13, 13, STEEL_DARK)
    recorder.rect(3, 4, 13, 6, STEEL)
    recorder.rect(5, 7, 11, 11, INK)
    recorder.circle(6.5, 9, 1.2, ORANGE)
    recorder.circle(9.5, 9, 1.2, ORANGE)
    recorder.px(11, 5, RED)
    recorder.outline()
    recorder.save(SPRITES / "recorder.png")

    for name, glow in (("terminal_off", hexc("#1b2a33")), ("terminal_on", hexc("#3fe0c0"))):
        t = Canvas(20, 28)
        t.rect(2, 2, 18, 22, STEEL_DARK)
        t.rect(2, 2, 18, 4, STEEL)
        t.rect(4, 5, 16, 16, glow)
        if name == "terminal_on":
            for y in (7, 10, 13):
                t.rect(5, y, 15, y + 1, hexc("#c8fff4"))
        t.rect(6, 18, 14, 20, INK)
        t.rect(6, 22, 14, 27, STEEL_DARK)
        t.outline()
        t.save(SPRITES / f"{name}.png")

    gate = Canvas(32, 32)
    gate.rect(3, 6, 6, 32, hexc("#5a4a3c"))
    gate.rect(26, 6, 29, 32, hexc("#5a4a3c"))
    gate.rect(6, 12, 26, 14, STEEL_DARK)
    gate.rect(6, 22, 26, 24, STEEL_DARK)
    for x in range(8, 26, 4):
        gate.rect(x, 12, x + 1, 24, STEEL)
    gate.rect(13, 2, 19, 8, ORANGE)
    gate.rect(15, 3, 17, 7, INK)
    gate.outline()
    gate.save(SPRITES / "gate.png")

    arrow = Canvas(16, 16)
    arrow.rect(7, 6, 9, 14, ORANGE)
    for i in range(5):
        arrow.rect(8 - i, 2 + i, 9 + i, 3 + i, ORANGE)
    arrow.outline()
    arrow.save(SPRITES / "arrow_up.png")


# -------------------------------------------------------------------- ui
def build_ui():
    drop = Canvas(9, 11)
    drop.circle(4.5, 7, 3.6, hexc("#3aa0e0"))
    for i in range(5):
        drop.rect(4 - i // 2, 1 + i, 5 + i // 2, 2 + i, hexc("#3aa0e0"))
    drop.px(3, 6, WHITE)
    drop.px(3, 7, WHITE)
    drop.outline()
    drop.save(SPRITES / "ui_drop.png")

    heart = Canvas(11, 10)
    for cx in (3, 7):
        heart.circle(cx, 3, 2.6, hexc("#e0584a"))
    for i in range(5):
        heart.rect(1 + i, 4 + i, 10 - i, 5 + i, hexc("#e0584a"))
    heart.px(2, 2, WHITE)
    heart.outline()
    heart.save(SPRITES / "ui_heart.png")

    icon = Canvas(32, 32, hexc("#12303a"))
    icon.circle(16, 17, 9, hexc("#3aa0e0"))
    for i in range(10):
        icon.rect(16 - i // 2, 3 + i, 17 + i // 2, 4 + i, hexc("#3aa0e0"))
    icon.circle(13, 15, 2, WHITE)
    icon.save(ROOT / "icon.png")


def main():
    build_tileset()
    build_player()
    build_items()
    build_bins()
    build_props()
    build_ui()
    import assets_chapter2

    assets_chapter2.build()
    print("assets written to", ROOT / "assets")


if __name__ == "__main__":
    main()
