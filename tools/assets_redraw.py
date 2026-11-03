"""Hand-drawn sprites in the third-party pack's style: dark outline, three-tone
shading lit from the top left. Replaces the generic placeholders for the two
repair machines, the battery and the glass items, then snaps to the pack palette.

Runs last from generate_assets.py (after restyle_art.py).
"""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_assets import SPRITES, Canvas, hexc  # noqa: E402
from pngio import read_png, write_png  # noqa: E402
import restyle_art  # noqa: E402

OUT = hexc("#2a2030")
STEEL_D, STEEL, STEEL_L = hexc("#4a4a5c"), hexc("#7a7a8e"), hexc("#a8a8ba")
RUST_D, RUST, RUST_L = hexc("#5a2e2c"), hexc("#8a4a3a"), hexc("#b0644a")
BLUE_D, BLUE, BLUE_L = hexc("#2f4e7a"), hexc("#4a78a8"), hexc("#86b4d4")
CYAN, WHITE = hexc("#9fe0e8"), hexc("#e8e0e0")
GREEN, GREEN_L = hexc("#5aa040"), hexc("#8ccf5a")
YELLOW, RED, ORANGE = hexc("#e8c040"), hexc("#c04040"), hexc("#d8782c")
GLASS, GLASS_L, GLASS_D = hexc("#a8cfd8"), hexc("#dff4f6"), hexc("#6f9cb0")


def shade(c, x0, y0, x1, y1, dark, mid, light):
    """A box lit from the top left: light left and top edges, dark right and bottom."""
    c.rect(x0, y0, x1, y1, mid)
    c.rect(x0, y0, x0 + 2, y1, light)
    c.rect(x0, y0, x1, y0 + 1, light)
    c.rect(x1 - 2, y0, x1, y1, dark)
    c.rect(x0, y1 - 1, x1, y1, dark)


def treatment_unit(fixed):
    body = (BLUE_D, BLUE, BLUE_L) if fixed else (RUST_D, RUST, RUST_L)
    c = Canvas(32, 32)
    shade(c, 3, 27, 29, 31, STEEL_D, STEEL, STEEL_L)  # base plate
    shade(c, 7, 9, 23, 27, *body)  # tank
    shade(c, 6, 6, 24, 10, *body)  # tank cap
    c.rect(23, 16, 29, 19, STEEL)  # outlet pipe
    c.rect(26, 19, 29, 27, STEEL)
    c.rect(23, 16, 29, 17, STEEL_L)
    c.circle(14, 17, 3.2, WHITE)  # gauge
    c.circle(14, 17, 2.2, STEEL_D)
    if fixed:
        c.line(14, 17, 16, 15, CYAN)
        c.rect(24, 6, 27, 9, GREEN_L)  # status lamp
        c.rect(26, 24, 28, 27, CYAN)  # clean water in the outlet
        c.px(8, 12, CYAN)
        c.px(9, 14, CYAN)
    else:
        c.line(14, 17, 12, 19, RED)
        c.rect(24, 6, 27, 9, RED)
        c.line(9, 11, 15, 24, OUT)  # crack
        c.line(10, 11, 16, 24, RUST_D)
        c.rect(27, 28, 29, 30, hexc("#6f9a5a"))  # dirty drip
        c.px(28, 26, hexc("#6f9a5a"))
    c.outline(OUT)
    return c


def generator(fixed):
    body = (STEEL_D, STEEL, STEEL_L) if fixed else (RUST_D, RUST, RUST_L)
    c = Canvas(32, 28)
    shade(c, 3, 12, 25, 25, *body)  # engine block
    shade(c, 21, 3, 25, 12, STEEL_D, STEEL_D, STEEL)  # exhaust stack
    c.rect(20, 2, 26, 4, STEEL_D)
    shade(c, 25, 14, 30, 25, hexc("#a05a1c"), ORANGE, hexc("#f0a050"))  # fuel tank
    c.circle(10, 19, 4.6, STEEL_D)  # fan housing
    c.circle(10, 19, 3.0, body[1])
    c.rect(9, 16, 11, 23, STEEL_D)  # fan blades
    c.rect(7, 18, 14, 20, STEEL_D)
    c.px(10, 19, body[2])
    c.rect(15, 14, 22, 17, hexc("#2a2030"))  # control panel
    c.px(16, 15, GREEN_L if fixed else RED)
    c.px(18, 15, YELLOW if fixed else STEEL_D)
    c.px(20, 15, GREEN_L if fixed else STEEL_D)
    c.rect(4, 25, 8, 27, STEEL_D)
    c.rect(20, 25, 24, 27, STEEL_D)
    if fixed:
        c.rect(22, 0, 24, 2, hexc("#c8c8d4"))  # a puff of exhaust
    else:
        c.line(5, 13, 12, 22, OUT)  # crack
        c.px(23, 8, RUST_L)
    c.outline(OUT)
    return c


def battery():
    c = Canvas(16, 16)
    shade(c, 4, 4, 13, 15, BLUE_D, BLUE, BLUE_L)
    c.rect(6, 2, 11, 4, STEEL_L)  # terminal
    c.rect(4, 8, 13, 11, ORANGE)  # label band
    c.rect(4, 8, 13, 9, hexc("#f0a050"))
    c.px(6, 9, OUT)
    c.px(7, 9, OUT)
    c.px(10, 9, OUT)
    c.px(9, 8, OUT)
    c.px(9, 10, OUT)
    c.px(8, 9, ORANGE)
    c.rect(12, 13, 15, 15, GREEN)  # leaking ooze
    c.px(14, 15, GREEN_L)
    c.px(13, 12, GREEN)
    c.outline(OUT)
    return c


def glass_jar():
    c = Canvas(16, 16)
    c.rect(4, 2, 12, 5, STEEL)  # lid
    c.rect(4, 2, 12, 3, STEEL_L)
    c.rect(5, 5, 11, 7, GLASS)  # neck
    c.rect(3, 7, 13, 15, GLASS)
    c.rect(4, 8, 6, 14, GLASS_L)  # highlight
    c.rect(11, 8, 13, 15, GLASS_D)
    c.rect(3, 14, 13, 15, GLASS_D)
    c.outline(OUT)
    return c


def glass_shard():
    c = Canvas(16, 16)
    for y in range(3, 14):
        half = (y - 3) // 2 + 1
        c.rect(6 - half, y, 6 + half + 1, y + 1, GLASS)
    c.line(6, 4, 6, 11, GLASS_L)
    c.line(5, 7, 4, 11, GLASS_L)
    c.line(7, 9, 9, 13, GLASS_D)
    c.rect(10, 9, 14, 11, GLASS)
    c.rect(11, 11, 14, 13, GLASS_D)
    c.px(11, 9, GLASS_L)
    c.outline(OUT)
    return c


def charcoal():
    c = Canvas(16, 16)
    black, ash = hexc("#2c2830"), hexc("#5a5560")
    for x0, y0, x1, y1 in ((3, 8, 9, 14), (8, 5, 14, 12), (6, 2, 11, 7)):
        shade(c, x0, y0, x1, y1, hexc("#1c1820"), black, ash)
    c.px(5, 10, ORANGE)
    c.px(11, 8, ORANGE)
    c.px(8, 4, hexc("#f0a050"))
    c.outline(OUT)
    return c


def sand_sack():
    c = Canvas(16, 16)
    tan, tan_l, tan_d = hexc("#c8a860"), hexc("#e0c888"), hexc("#8a6a34")
    shade(c, 3, 5, 13, 15, tan_d, tan, tan_l)
    c.rect(5, 2, 11, 5, tan)  # tied neck
    c.rect(4, 4, 12, 5, tan_d)
    c.rect(4, 8, 12, 9, tan_d)
    c.rect(5, 11, 11, 12, tan_d)
    c.px(7, 6, tan_l)
    c.outline(OUT)
    return c


def kettle():
    c = Canvas(16, 16)
    shade(c, 3, 6, 12, 14, STEEL_D, STEEL, STEEL_L)
    c.rect(5, 4, 10, 6, STEEL)  # lid
    c.rect(7, 2, 8, 4, STEEL_L)
    c.rect(12, 8, 15, 10, STEEL)  # spout
    c.rect(1, 7, 3, 12, STEEL_D)  # handle
    c.px(5, 9, WHITE)
    c.outline(OUT)
    return c


def paint_tin():
    c = Canvas(16, 16)
    shade(c, 4, 5, 12, 15, hexc("#8a2c2c"), RED, hexc("#e06060"))
    c.rect(3, 4, 13, 6, STEEL_L)
    c.rect(3, 14, 13, 15, STEEL)
    c.rect(5, 8, 11, 11, WHITE)
    c.px(8, 9, RED)
    c.rect(11, 12, 13, 15, hexc("#c04040"))  # drip
    c.px(12, 15, hexc("#c04040"))
    c.outline(OUT)
    return c


def sample_kit():
    c = Canvas(16, 20)
    c.rect(7, 8, 9, 19, hexc("#6a4a34"))  # post
    shade(c, 2, 1, 14, 10, hexc("#9c9ca8"), WHITE, hexc("#f4f0f0"))  # card
    c.rect(4, 3, 7, 8, GREEN)
    c.rect(7, 3, 10, 8, YELLOW)
    c.rect(10, 3, 13, 8, RED)
    c.rect(5, 19, 11, 20, hexc("#4a3a2c"))
    c.outline(OUT)
    return c


def sword():
    c = Canvas(16, 5)
    c.rect(0, 1, 3, 4, hexc("#6a4a34"))  # grip
    c.rect(3, 0, 5, 5, STEEL_D)  # guard
    c.rect(5, 1, 15, 4, STEEL_L)  # blade
    c.rect(5, 1, 15, 2, WHITE)
    c.px(15, 2, STEEL_L)
    c.outline(OUT)
    return c


def chest(opened):
    c = Canvas(16, 14)
    wood, wood_l, wood_d = hexc("#8a5a34"), hexc("#b0804c"), hexc("#5a3a24")
    shade(c, 1, 6, 15, 14, wood_d, wood, wood_l)  # body
    if opened:
        shade(c, 1, 1, 15, 6, wood_d, wood_d, wood)  # lid thrown back
        c.rect(3, 6, 13, 8, hexc("#2a2030"))  # dark inside
        c.rect(5, 6, 11, 7, YELLOW)  # glint of loot
    else:
        shade(c, 1, 2, 15, 8, wood_d, wood, wood_l)  # lid
        c.rect(7, 6, 10, 9, YELLOW)  # lock
        c.px(8, 7, OUT)
    c.rect(1, 8, 15, 9, STEEL_D)  # band
    c.outline(OUT)
    return c


def bolt():
    c = Canvas(9, 11)
    for x0, y0, x1, y1 in ((4, 0, 7, 2), (3, 2, 6, 4), (2, 4, 7, 6), (4, 6, 6, 8), (3, 8, 5, 10)):
        c.rect(x0, y0, x1, y1, YELLOW)
    c.rect(2, 4, 5, 5, hexc("#fff0a0"))
    c.outline(OUT)
    return c


def build():
    named = [OUT, STEEL_D, STEEL, STEEL_L, RUST_D, RUST, RUST_L, BLUE_D, BLUE, BLUE_L, CYAN, WHITE,
             GREEN, GREEN_L, YELLOW, RED, ORANGE, GLASS, GLASS_L, GLASS_D]
    # The drawings use these colours on purpose, so they join the pack palette and survive snapping.
    palette = np.concatenate([restyle_art.pack_palette(), np.array([c[:3] for c in named], np.int32)])
    drawings = {
        "treatment_unit_broken": treatment_unit(False),
        "treatment_unit_fixed": treatment_unit(True),
        "generator_broken": generator(False),
        "generator_fixed": generator(True),
        "items/battery": battery(),
        "items/glass_jar": glass_jar(),
        "items/glass_shard": glass_shard(),
        "items/charcoal": charcoal(),
        "items/sand_sack": sand_sack(),
        "items/kettle": kettle(),
        "items/paint_tin": paint_tin(),
        "sample_kit": sample_kit(),
        "sword": sword(),
        "ui_bolt": bolt(),
        "chest_closed": chest(False),
        "chest_open": chest(True),
    }
    for name, canvas in drawings.items():
        path = SPRITES / f"{name}.png"
        canvas.save(path)
        write_png(path, restyle_art.snap(read_png(path), palette))
    print(f"redrew {len(drawings)} sprites")


if __name__ == "__main__":
    build()
