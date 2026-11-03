"""Placeholder art for chapter 2, The Great Dump: eight items, the compost bin,
two tiles (garbage heap, plastic bags) and the shelter roof repair sprites.

Called from generate_assets.main(); it extends the tileset so the original
eighteen columns keep their positions.
"""
import random

from generate_assets import (
    BROWN, BROWN_LIGHT, GREEN, INK, JACKET, ORANGE, ORANGE_DARK, RED, RUST,
    RUST_DARK, SPRITES, STEEL, STEEL_DARK, STEEL_LIGHT, TEAL, TEAL_LIGHT, TILE,
    TILE_BUILDERS, TILESETS, WHITE, YELLOW, Canvas, bin_icon, hexc, speckled,
)

GROUND = hexc("#4d4540")
BAG_BLACK = hexc("#23262e")
BAG_GREY = hexc("#3c4250")


def item_phone():
    c = Canvas(16, 16)
    c.rect(5, 2, 12, 14, STEEL_DARK)
    c.rect(6, 3, 11, 11, hexc("#2c7f8a"))
    c.line(7, 4, 10, 8, hexc("#9fe3ea"))
    c.line(6, 9, 10, 5, hexc("#cdf4f6"))  # a crack across the screen
    c.rect(7, 12, 10, 13, STEEL_LIGHT)
    c.px(8, 2, INK)
    return c


def item_fluorescent_tube():
    c = Canvas(16, 16)
    for i in range(12):
        c.rect(2 + i, 10 - i // 2, 5 + i, 12 - i // 2, hexc("#e8eef2"))
    c.rect(2, 9, 4, 13, STEEL)
    c.rect(13, 3, 15, 7, STEEL)
    c.px(7, 7, YELLOW)
    c.px(9, 6, YELLOW)
    return c


def item_food_scraps():
    c = Canvas(16, 16)
    c.circle(7, 9, 4.5, hexc("#c0392b"))
    c.rect(6, 3, 8, 5, GREEN)
    c.rect(8, 2, 11, 4, hexc("#5a9a2a"))
    c.circle(11, 11, 2.5, hexc("#e8a33a"))
    c.px(6, 8, hexc("#e0584a"))
    c.px(12, 10, hexc("#f2c94c"))
    return c


def item_cardboard():
    c = Canvas(16, 16)
    c.rect(2, 4, 14, 13, hexc("#b98b54"))
    c.rect(2, 4, 14, 6, hexc("#d1a56a"))
    c.rect(7, 4, 9, 13, hexc("#9c7242"))
    c.rect(3, 9, 6, 11, WHITE)
    c.px(4, 10, INK)
    return c


def item_glass_jar():
    c = Canvas(16, 16)
    c.rect(4, 3, 12, 5, STEEL)
    c.rect(4, 5, 12, 14, hexc("#bfe6ee"))
    c.rect(5, 6, 7, 13, WHITE)
    c.rect(10, 9, 12, 14, hexc("#8fc9d6"))
    return c


def item_textile_scrap():
    c = Canvas(16, 16)
    c.rect(2, 4, 13, 13, JACKET)
    c.rect(2, 4, 13, 6, hexc("#4f7aa0"))
    for x in range(3, 13, 3):
        c.rect(x, 7, x + 1, 13, hexc("#33506c"))
    c.line(3, 13, 6, 15, JACKET)
    c.line(9, 13, 12, 15, JACKET)
    return c


def item_tin_can():
    c = Canvas(16, 16)
    c.rect(4, 4, 12, 14, STEEL)
    c.rect(4, 4, 6, 14, STEEL_LIGHT)
    c.rect(4, 7, 12, 11, hexc("#c0392b"))
    c.rect(4, 3, 12, 5, STEEL_LIGHT)
    c.rect(4, 13, 12, 15, STEEL_DARK)
    return c


def item_greasy_pizza_box():
    c = Canvas(16, 16)
    c.rect(2, 4, 14, 13, hexc("#c9a46a"))
    c.rect(2, 4, 14, 5, hexc("#dcb87c"))
    c.circle(7, 9, 2.6, hexc("#7a4a22"))
    c.circle(11, 10, 1.8, hexc("#7a4a22"))
    c.px(5, 12, hexc("#f2c94c"))
    return c


ITEM_BUILDERS = {
    "phone": item_phone,
    "fluorescent_tube": item_fluorescent_tube,
    "food_scraps": item_food_scraps,
    "cardboard": item_cardboard,
    "glass_jar": item_glass_jar,
    "textile_scrap": item_textile_scrap,
    "tin_can": item_tin_can,
    "greasy_pizza_box": item_greasy_pizza_box,
}


def mark_compost(c):
    c.rect(11, 9, 13, 18, GREEN)
    for i in range(4):
        c.rect(7 + i, 11 + i, 11, 12 + i, hexc("#5a9a2a"))
        c.rect(13, 10 + i, 17 - i, 11 + i, hexc("#7bc043"))


def tile_heap(rng):
    t = speckled(BAG_GREY, rng, 6)
    for _ in range(14):
        x, y = rng.randrange(0, 13), rng.randrange(0, 13)
        t.rect(x, y, x + rng.randint(2, 4), y + rng.randint(2, 4), rng.choice([BAG_BLACK, BAG_GREY, STEEL_DARK, RUST_DARK]))
    for _ in range(6):
        t.rect(rng.randrange(1, 14), rng.randrange(1, 14), rng.randrange(2, 15), rng.randrange(2, 15), rng.choice([TEAL, ORANGE_DARK, hexc("#5a7fa0")]))
    t.rect(0, 0, TILE, 2, hexc("#4a5160"))
    return t


def tile_bags(rng):
    t = speckled(GROUND, rng, 4)
    for _ in range(4):
        x, y = rng.randrange(1, 11), rng.randrange(1, 11)
        t.rect(x, y, x + 4, y + 3, rng.choice([BAG_BLACK, BAG_GREY]))
        t.rect(x + 1, y, x + 3, y + 1, hexc("#5a6070"))
    t.rect(rng.randrange(2, 13), rng.randrange(2, 13), 13, 13, STEEL_LIGHT)
    return t


def shelter(broken):
    c = Canvas(32, 32)
    wall = RUST_DARK if broken else hexc("#6b7480")
    c.rect(3, 12, 29, 30, wall)
    c.rect(5, 16, 27, 30, INK)
    c.rect(13, 20, 19, 30, hexc("#3a2a22"))
    if broken:
        c.line(2, 12, 16, 4, RUST)
        c.line(16, 4, 20, 10, RUST)
        c.rect(22, 8, 30, 12, RUST)
        c.px(10, 24, RED)
    else:
        c.rect(2, 8, 30, 13, STEEL)
        c.rect(2, 8, 30, 10, STEEL_LIGHT)
        c.rect(9, 3, 13, 8, ORANGE)
        c.rect(13, 22, 19, 30, hexc("#7bc043"))
        c.rect(26, 20, 29, 24, YELLOW)
    c.outline()
    return c


def build():
    for name, builder in ITEM_BUILDERS.items():
        canvas = builder()
        canvas.outline()
        canvas.save(SPRITES / "items" / f"{name}.png")

    bin_icon(hexc("#6b4a28"), hexc("#4a3219"), mark_compost).save(SPRITES / "bins" / "compost.png")
    shelter(True).save(SPRITES / "shelter_broken.png")
    shelter(False).save(SPRITES / "shelter_fixed.png")

    rng = random.Random(1234)
    builders = list(TILE_BUILDERS) + [tile_heap, tile_bags]
    sheet = Canvas(TILE * len(builders), TILE)
    for index, builder in enumerate(builders):
        sheet.blit(builder(rng), index * TILE, 0)
    sheet.save(TILESETS / "outpost_tiles.png")
