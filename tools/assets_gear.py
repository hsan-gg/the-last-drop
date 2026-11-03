"""Icons for gear (assets/sprites/gear/) and the consumables, drawn in the same
style as the rest of the redrawn art: dark outline, three-tone shading.
Runs from generate_assets.py after assets_redraw.py.
"""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from generate_assets import SPRITES, Canvas, hexc  # noqa: E402
from assets_redraw import (  # noqa: E402
    BLUE, BLUE_D, BLUE_L, CYAN, GLASS, GLASS_D, GLASS_L, GREEN, ORANGE, OUT, RED, STEEL,
    STEEL_D, STEEL_L, WHITE, YELLOW, shade,
)
from pngio import read_png, write_png  # noqa: E402
import restyle_art  # noqa: E402

BROWN, BROWN_L, BROWN_D = hexc("#8a5a34"), hexc("#b0804c"), hexc("#5a3a24")


def sword_icon(blade, blade_light, guard, grip):
    c = Canvas(16, 16)
    for i in range(10):  # the blade runs up to the right
        c.rect(5 + i, 10 - i, 7 + i, 12 - i, blade)
        c.px(6 + i, 10 - i, blade_light)
    c.rect(3, 9, 8, 11, guard)  # crossguard
    c.rect(6, 7, 8, 12, guard)
    c.rect(2, 11, 4, 14, grip)
    c.px(1, 14, guard)
    c.outline(OUT)
    return c


def fists_icon():
    c = Canvas(16, 16)
    skin, skin_l, skin_d = hexc("#e0b48a"), hexc("#f0cfa8"), hexc("#a8744c")
    shade(c, 4, 6, 13, 13, skin_d, skin, skin_l)
    for x in (5, 7, 9, 11):
        c.rect(x, 4, x + 2, 7, skin)
        c.px(x, 4, skin_l)
    c.rect(3, 9, 5, 12, skin)
    c.outline(OUT)
    return c


def hard_hat():
    c = Canvas(16, 16)
    shade(c, 3, 5, 13, 12, hexc("#a08020"), YELLOW, hexc("#f4dc78"))
    c.rect(2, 11, 14, 13, hexc("#c0a020"))  # brim
    c.rect(7, 3, 9, 6, hexc("#c0a020"))  # ridge
    c.outline(OUT)
    return c


def welding_mask():
    c = Canvas(16, 16)
    shade(c, 3, 3, 13, 14, STEEL_D, STEEL, STEEL_L)
    c.rect(4, 7, 12, 10, hexc("#2a3a30"))  # tinted visor
    c.rect(5, 8, 8, 9, hexc("#5aa060"))
    c.px(5, 4, WHITE)
    c.outline(OUT)
    return c


def crash_helmet():
    c = Canvas(16, 16)
    shade(c, 2, 3, 14, 14, hexc("#8a2c2c"), RED, hexc("#e06060"))
    c.rect(4, 7, 14, 11, hexc("#2a2030"))  # visor
    c.rect(5, 8, 9, 9, CYAN)
    c.rect(7, 3, 9, 7, WHITE)  # racing stripe
    c.outline(OUT)
    return c


def cloth_wrap():
    c = Canvas(16, 16)
    tan, tan_l, tan_d = hexc("#c8a870"), hexc("#e0c898"), hexc("#8a6a3c")
    shade(c, 3, 2, 13, 14, tan_d, tan, tan_l)
    for y in (5, 8, 11):
        c.rect(3, y, 13, y + 1, tan_d)
    c.rect(7, 2, 9, 14, hexc("#a88850"))
    c.outline(OUT)
    return c


def tire_vest():
    c = Canvas(16, 16)
    shade(c, 2, 3, 14, 14, hexc("#2a2a32"), hexc("#46464f"), hexc("#6a6a76"))
    c.rect(6, 3, 10, 7, hexc("#14141a"))  # neck
    for x in (4, 7, 10, 12):
        c.rect(x, 9, x + 1, 13, hexc("#2a2a32"))  # tread
    c.outline(OUT)
    return c


def scrap_plate():
    c = Canvas(16, 16)
    shade(c, 2, 2, 14, 14, STEEL_D, STEEL, STEEL_L)
    shade(c, 4, 4, 12, 12, hexc("#5a5a6c"), hexc("#8a8a9e"), hexc("#b4b4c4"))
    for x, y in ((3, 3), (12, 3), (3, 12), (12, 12)):
        c.px(x, y, WHITE)  # rivets
    c.rect(7, 6, 9, 10, hexc("#a05a1c"))  # patch
    c.outline(OUT)
    return c


def riot_jacket():
    c = Canvas(16, 16)
    shade(c, 2, 3, 14, 14, BLUE_D, BLUE, BLUE_L)
    c.rect(2, 3, 4, 14, hexc("#2f4e7a"))  # sleeves
    c.rect(12, 3, 14, 14, hexc("#2f4e7a"))
    c.rect(7, 3, 9, 14, hexc("#14243c"))  # zip
    c.rect(4, 9, 12, 10, hexc("#d8782c"))  # strap
    c.outline(OUT)
    return c


def bandage():
    c = Canvas(16, 16)
    shade(c, 3, 5, 13, 12, hexc("#a8a8ba"), WHITE, hexc("#ffffff"))
    c.rect(7, 6, 9, 11, RED)
    c.rect(5, 8, 11, 9, RED)
    c.rect(3, 3, 13, 5, WHITE)
    c.outline(OUT)
    return c


def purified_water():
    c = Canvas(16, 16)
    c.rect(6, 2, 10, 4, STEEL)
    c.rect(5, 4, 11, 14, GLASS)
    c.rect(6, 5, 7, 13, GLASS_L)
    c.rect(5, 9, 11, 14, BLUE)
    c.rect(5, 9, 11, 10, CYAN)
    c.rect(10, 5, 11, 14, GLASS_D)
    c.outline(OUT)
    return c


def energy_bar():
    c = Canvas(16, 16)
    shade(c, 2, 5, 14, 12, hexc("#a05a1c"), ORANGE, hexc("#f0a050"))
    c.rect(2, 5, 3, 12, hexc("#d8c040"))
    c.rect(13, 5, 14, 12, hexc("#d8c040"))
    c.rect(5, 7, 10, 9, WHITE)
    c.px(11, 8, GREEN)
    c.outline(OUT)
    return c


GEAR = {
    "fists": fists_icon(),
    "rusty_sword": sword_icon(hexc("#b08060"), hexc("#d8a880"), hexc("#6a4a34"), hexc("#4a3020")),
    "scrap_blade": sword_icon(hexc("#a8b4c0"), hexc("#e0eaf0"), STEEL_D, hexc("#5a3a24")),
    "recycled_edge": sword_icon(hexc("#5ab4f0"), hexc("#b4e4ff"), STEEL, hexc("#2f4e7a")),
    "solar_saber": sword_icon(hexc("#f0c040"), hexc("#fff0a0"), hexc("#a05a1c"), hexc("#6a2a1c")),
    "hard_hat": hard_hat(),
    "welding_mask": welding_mask(),
    "crash_helmet": crash_helmet(),
    "cloth_wrap": cloth_wrap(),
    "tire_vest": tire_vest(),
    "scrap_plate": scrap_plate(),
    "riot_jacket": riot_jacket(),
}
CONSUMABLES = {"bandage": bandage(), "purified_water": purified_water(), "energy_bar": energy_bar()}


def build():
    named = [OUT, STEEL_D, STEEL, STEEL_L, BLUE_D, BLUE, BLUE_L, CYAN, WHITE, GREEN, YELLOW, RED, ORANGE, GLASS, GLASS_L, GLASS_D]
    palette = np.concatenate([restyle_art.pack_palette(), np.array([c[:3] for c in named], np.int32)])
    for name, canvas in GEAR.items():
        path = SPRITES / "gear" / f"{name}.png"
        canvas.save(path)
        write_png(path, restyle_art.snap(read_png(path), palette))
    for name, canvas in CONSUMABLES.items():
        path = SPRITES / "items" / f"{name}.png"
        canvas.save(path)
        write_png(path, restyle_art.snap(read_png(path), palette))
    print(f"drew {len(GEAR)} gear icons and {len(CONSUMABLES)} consumables")


if __name__ == "__main__":
    build()
