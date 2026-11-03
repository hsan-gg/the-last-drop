#!/usr/bin/env python3
"""Draws the cast of characters from the player's own sheet, so everyone shares
one chibi style: each NPC recolours hair, skin and clothes, then adds what makes
them themselves (a beard, glasses, a straw hat, goggles, a robot's visor). The
accessories are cut from each frame's silhouette, so they follow the walk bob.

Writes assets/sprites/npcs/<id>.png with the player sheet's layout (rows down,
up, left, right; 6 idle then 6 walk frames of 16x18). Run from game/.
"""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pngio import read_png, write_png  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
SHEET = read_png(str(ROOT / "assets/sprites/player.png"))
W, H = 16, 18
FACINGS = ["down", "up", "left", "right"]
# The player's palette, by role.
ROLES = {
    "outline": "#2c1d35", "hair_dark": "#452c34", "hair_light": "#704f48",
    "skin": "#e6c2b0", "skin_shade": "#ba868f", "jacket": "#404351",
    "shirt": "#43735b", "trim_light": "#9eafad", "trim_dark": "#728591",
}


def rgb(code):
    code = code.lstrip("#")
    return np.array([int(code[i:i + 2], 16) for i in (0, 2, 4)], np.uint8)


def recolour(sheet, mapping):
    out = sheet.copy()
    for role, colour in mapping.items():
        source = rgb(ROLES[role])
        match = np.all(sheet[:, :, :3] == source, axis=2) & (sheet[:, :, 3] > 0)
        out[match, :3] = rgb(colour)
    return out


def frames(sheet):
    for row in range(4):
        for column in range(sheet.shape[1] // W):
            yield FACINGS[row], sheet[row * H:(row + 1) * H, column * W:(column + 1) * W]


def top_row(frame):
    rows = np.where(frame[:, :, 3].any(axis=1))[0]
    return int(rows[0]) if len(rows) else 0


def put(frame, x, y, colour):
    if 0 <= x < W and 0 <= y < H:
        frame[y, x, :3] = rgb(colour)
        frame[y, x, 3] = 255


def where(frame, role_colour, rows):
    colour = rgb(role_colour)
    ys, xs = np.where(np.all(frame[:, :, :3] == colour, axis=2) & (frame[:, :, 3] > 0))
    return [(x, y) for x, y in zip(xs, ys) if rows[0] <= y <= rows[1]]


# ------------------------------------------------------------------ accessories
# Each works on one frame in place; `top` is the frame's head top row (bob-aware).

def beard(colour):
    def draw(frame, facing, top, skin):
        if facing == "up":
            return
        for x, y in where(frame, skin, (top + 8, top + 10)):
            put(frame, x, y, colour)
    return draw


def glasses(colour):
    def draw(frame, facing, top, _skin):
        if facing == "up":
            return
        y = top + 6
        xs = [x for x in range(W) if frame[y, x, 3] > 0]
        if not xs:
            return
        left, right = min(xs) + 1, max(xs) - 1
        span = range(left, right + 1) if facing == "down" else (range(left, left + 5) if facing == "left" else range(right - 4, right + 1))
        for x in span:
            put(frame, x, y, colour)
    return draw


def hat(colour, brim, wide=False):
    def draw(frame, facing, top, _skin):
        for y in range(max(top - 1, 0), top + 3):
            xs = [x for x in range(W) if frame[min(y + 1, H - 1), x, 3] > 0]
            if xs:
                for x in range(min(xs), max(xs) + 1):
                    put(frame, x, y, colour)
        y = top + 3
        xs = [x for x in range(W) if frame[y, x, 3] > 0]
        if xs:
            extra = 2 if wide else 1
            for x in range(min(xs) - extra, max(xs) + extra + 1):
                put(frame, x, y, brim)
    return draw


def band(colour):
    def draw(frame, _facing, top, _skin):
        y = top + 2
        xs = [x for x in range(W) if frame[y, x, 3] > 0]
        if xs:
            for x in range(min(xs), max(xs) + 1):
                put(frame, x, y, colour)
    return draw


def bun(colour):
    def draw(frame, _facing, top, _skin):
        for dx in (-1, 0, 1):
            put(frame, 7 + dx, max(top - 1, 0), colour)
        put(frame, 7, max(top - 2, 0), colour)
    return draw


def visor(colour, glow):
    def draw(frame, facing, top, skin):
        if facing == "up":
            return
        for x, y in where(frame, skin, (top + 5, top + 7)):
            put(frame, x, y, colour)
        for x, y in where(frame, ROLES["outline"], (top + 6, top + 7)):
            if 2 < x < 14 and frame[y, x - 1, 3] > 0 and frame[y, x + 1, 3] > 0:
                put(frame, x, y, glow)
    return draw


def antenna(colour, tip):
    def draw(frame, _facing, top, _skin):
        put(frame, 8, max(top - 1, 0), colour)
        put(frame, 8, max(top - 2, 0), colour)
        put(frame, 8, max(top - 3, 0), tip)
    return draw


def vest_stripe(colour):
    def draw(frame, facing, top, _skin):
        y = top + 12
        xs = [x for x in range(W) if frame[y, x, 3] > 0]
        if xs:
            for x in range(min(xs) + 1, max(xs)):
                put(frame, x, y, colour)
    return draw


# ------------------------------------------------------------------ the cast

CAST = {
    "tobi": ({"hair_dark": "#8a8a8e", "hair_light": "#b8b8bc", "skin": "#d8a888", "skin_shade": "#a87a6a",
              "jacket": "#5a4434", "shirt": "#8a6a3a", "trim_light": "#c8b080", "trim_dark": "#8a7050"},
             [beard("#e8e8e8"), hat("#6a5440", "#4a3a2c")]),
    "mira": ({"hair_dark": "#b8501c", "hair_light": "#e07a30", "jacket": "#6a3a5a", "shirt": "#d86a8a",
              "trim_light": "#f0c0d0", "trim_dark": "#b08aa0"},
             [band("#40c0e0")]),
    "halden": ({"hair_dark": "#9a9a9a", "hair_light": "#cfcfcf", "skin": "#f0d2c0", "jacket": "#d8d8e0",
                "shirt": "#e8e8f0", "trim_light": "#ffffff", "trim_dark": "#a0a0b0"},
               [glasses("#2a2a3a")]),
    "nana_ru": ({"hair_dark": "#d8d8d8", "hair_light": "#f4f4f4", "skin": "#9a6a4a", "skin_shade": "#7a4e38",
                 "jacket": "#5a3a6a", "shirt": "#8a5aa0", "trim_light": "#e0c070", "trim_dark": "#b09040"},
                [bun("#f4f4f4")]),
    "kip": ({"hair_dark": "#1a1a22", "hair_light": "#33333c", "skin": "#c89070", "skin_shade": "#9a6a54",
             "jacket": "#7a2a2a", "shirt": "#c84a3a", "trim_light": "#f0e0a0", "trim_dark": "#c0a060"},
            [band("#e0c040")]),
    "osei": ({"hair_dark": "#1a1416", "hair_light": "#2a2024", "skin": "#7a4a34", "skin_shade": "#5a3424",
              "jacket": "#2a4a6a", "shirt": "#3a6a9a", "trim_light": "#a0c8e0", "trim_dark": "#6a90b0"},
             [hat("#d8b878", "#b89858", wide=True), beard("#2a2024")]),
    "lena": ({"hair_dark": "#c8a040", "hair_light": "#f0d070", "jacket": "#3a5a8a", "shirt": "#5a7ab0",
              "trim_light": "#d8c8a0", "trim_dark": "#a89870"},
             [hat("#e0c070", "#c0a050", wide=True)]),
    "jory": ({"hair_dark": "#5a3a24", "hair_light": "#7a5434", "skin": "#e0b494", "jacket": "#4a5a2a",
              "shirt": "#6a8a3a", "trim_light": "#c0c890", "trim_dark": "#909860"},
             [band("#a04a3a")]),
    "vex": ({"hair_dark": "#2a2024", "hair_light": "#4a3a3a", "skin": "#d0a080", "jacket": "#3a3a40",
             "shirt": "#e0782c", "trim_light": "#f0f060", "trim_dark": "#c0c040"},
            [band("#8a8a90"), vest_stripe("#f0f060"), beard("#3a2a2a")]),
    "unit7": ({"hair_dark": "#6a7080", "hair_light": "#9aa0b0", "skin": "#8a90a0", "skin_shade": "#6a7080",
               "jacket": "#4a5060", "shirt": "#e0a030", "trim_light": "#c0c8d0", "trim_dark": "#8a90a0"},
              [visor("#1a2a34", "#5fe0ff"), antenna("#8a90a0", "#ff5040")]),
    "warden": ({"hair_dark": "#3a6a4a", "hair_light": "#5a9a6a", "skin": "#9ab0a0", "skin_shade": "#7a9080",
                "jacket": "#4a6a5a", "shirt": "#6a9a7a", "trim_light": "#b0e0c0", "trim_dark": "#80b090"},
               [visor("#10262a", "#7affd0"), antenna("#5a9a6a", "#7affd0")]),
}


def build(npc_id, mapping, extras):
    sheet = recolour(SHEET, mapping)
    skin = mapping.get("skin", ROLES["skin"])
    for facing, frame in frames(sheet):
        top = top_row(frame)
        for draw in extras:
            draw(frame, facing, top, skin)
    out_dir = ROOT / "assets/sprites/npcs"
    out_dir.mkdir(parents=True, exist_ok=True)
    write_png(str(out_dir / f"{npc_id}.png"), sheet)


def main():
    for npc_id, (mapping, extras) in CAST.items():
        build(npc_id, mapping, extras)
    print(f"drew {len(CAST)} characters")


if __name__ == "__main__":
    main()
