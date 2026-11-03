#!/usr/bin/env python3
"""Builds a tileset atlas for each later region, so each one feels like a
different world while the maps keep the same characters and collision.

Column order (and so map character meaning) matches tools/import_art.py:
 0-2 ground, 3 rubble, 4 wall*, 5 water*, 6 grass, 7 concrete, 8 path,
 9 pallet*, 10 fence*, 11 beam*, 12 plate floor, 13 dark floor, 14 toxic,
 15 stump*, 16 barrel*, 17 machine*, 18 trash, 19 heap*      (* solid)

Run from game/:  python3 tools/import_regions.py
"""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from import_art import PACK, TILE, crop, load, over, plate_floor, tinted  # noqa: E402
from pngio import write_png  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
rng = np.random.default_rng(42)


def solid(rgb, noise=6, seed=0):
    r = np.random.default_rng(seed)
    tile = np.zeros((TILE, TILE, 4), np.uint8)
    tile[:, :, 3] = 255
    blotch = np.repeat(np.repeat(r.integers(-noise, noise + 1, size=(8, 8)), 2, 0), 2, 1)
    for c in range(3):
        tile[:, :, c] = np.clip(rgb[c] + blotch, 0, 255)
    return tile


def shade(tile, amount):
    out = tile.copy()
    out[:, :, :3] = np.clip(out[:, :, :3].astype(int) + amount, 0, 255)
    return out


def cracks(tile, color, seed):
    """Dry-earth cracks: a few short jagged lines."""
    r = np.random.default_rng(seed)
    out = tile.copy()
    for _ in range(3):
        x, y = r.integers(1, 15, size=2)
        for _ in range(r.integers(3, 7)):
            out[y, x, :3] = color
            x = int(np.clip(x + r.choice([-1, 0, 1]), 0, 15))
            y = int(np.clip(y + r.choice([0, 1]), 0, 15))
    return out


def furrows(base, dark, light):
    out = base.copy()
    for y in (2, 7, 12):
        out[y:y + 2, :, :3] = dark
        out[y + 2, :, :3] = light
    return out


def stripes(base, a, b):
    out = base.copy()
    for y in range(TILE):
        for x in range(TILE):
            if 3 <= y <= 12:
                out[y, x, :3] = a if ((x + y) // 3) % 2 == 0 else b
    out[2, :, :3] = (40, 40, 44)
    out[13, :, :3] = (40, 40, 44)
    return out


def grate(base, line):
    out = base.copy()
    for i in range(0, TILE, 4):
        out[i, :, :3] = line
        out[:, i, :3] = line
    return out


def liquid(rgb, highlight, seed):
    tile = solid(rgb, 4, seed)
    r = np.random.default_rng(seed)
    for _ in range(3):
        y, x = r.integers(1, 15), r.integers(0, 10)
        tile[y, x:x + 5, :3] = highlight
    return tile


def hay_bale():
    tile = solid((176, 140, 70), 8, 3)
    tile[:2, :, 3] = 0
    for y in range(2, TILE):
        if y % 4 == 0:
            tile[y, :, :3] = (140, 104, 46)
    tile[2:, 4, :3] = (120, 90, 40)
    tile[2:, 11, :3] = (120, 90, 40)
    return tile


def corn_heap(base):
    out = base.copy()
    r = np.random.default_rng(9)
    for x in range(1, TILE, 2):
        top = int(r.integers(1, 6))
        out[top:TILE - 1, x, :3] = (150, 128, 70)
        out[top, x, :3] = (190, 160, 90)
        out[top + 2:TILE - 1:3, x + (1 if x < 15 else 0), :3] = (120, 98, 52)
    return out


def planter(base):
    out = base.copy()
    out[8:16, 1:15, :3] = (120, 84, 56)
    out[8, 1:15, :3] = (150, 110, 76)
    for x, color in ((3, (230, 120, 140)), (6, (250, 220, 90)), (9, (140, 160, 240)), (12, (240, 240, 240))):
        out[4:8, x, :3] = (70, 130, 60)
        out[3:5, x - 1:x + 2, :3] = color
    return out


def pillar(base, light, dark):
    out = base.copy()
    out[:, 4:12, :3] = light
    out[:, 4, :3] = dark
    out[:, 11, :3] = dark
    out[0:2, 3:13, :3] = dark
    return out


def build(name, tiles):
    assert len(tiles) == 20, name
    sheet = np.concatenate([t[:, :, :4] for t in tiles], axis=1)
    write_png(ROOT / "assets" / "tilesets" / f"{name}_tiles.png", sheet)
    print(f"{name}: 20 tiles")


def fields():
    ground_sheet = load("Tiles/Background_Bleak-Yellow_TileSet.png")
    soil = tinted(crop(ground_sheet, 0, 0), (170, 128, 74), 0.45)
    a = cracks(soil, (96, 70, 40), 1)
    b = cracks(shade(soil, -6), (96, 70, 40), 2)
    c = cracks(shade(soil, 5), (110, 80, 46), 3)
    rubble = tinted(crop(ground_sheet, 3, 1), (150, 110, 70), 0.4)
    wall = tinted(crop(load("Tiles/Brick-Wall_TileSet.png"), 0, 1), (130, 92, 56), 0.55)
    ditch = liquid((96, 104, 84), (140, 150, 120), 4)
    dry_grass = over(soil, load("Objects/Nature/Bleak-Yellow/Grass_1_Bleak-Yellow.png"))
    packed = shade(tinted(soil, (200, 170, 120), 0.4), 10)
    rows = furrows(soil, (110, 78, 44), (176, 136, 84))
    fence = over(soil, crop(load("Tiles/Wire-Fence/Wire-Fence_TileSet.png"), 1, 1))
    post = pillar(soil, (120, 86, 52), (80, 56, 34))
    boards = plate_floor((140, 104, 66), seed=21)
    shadow = shade(soil, -34)
    blight = tinted(over(soil, load("Objects/Nature/Flowers_Mashrooms_Other-nature-stuff/Puddles-And-Water-Anim/Puddle_On-Dry-Ground_3.png")), (120, 80, 140), 0.5)
    stump = over(soil, load("Objects/Nature/Flowers_Mashrooms_Other-nature-stuff/Stump_1.png"))
    barrel = over(soil, load("Objects/Barrel_rust_red_2.png"))
    tire = over(soil, load("Objects/Tire_2_Grass_Bleak-Yellow.png"))
    cardboard = over(soil, load("Objects/Cardboard_2.png"))
    build("fields", [a, b, c, rubble, wall, ditch, dry_grass, packed, rows, hay_bale(), fence, post,
                     boards, shadow, blight, stump, barrel, tire, cardboard, corn_heap(shade(soil, -10))])


def industry():
    floor = plate_floor((64, 64, 72), seed=5)
    a, b, c = floor, plate_floor((60, 60, 70), seed=6), plate_floor((70, 66, 70), seed=7)
    slag = tinted(crop(load("Tiles/Background_Bleak-Yellow_TileSet.png"), 3, 1), (70, 56, 50), 0.6)
    wall = tinted(crop(load("Tiles/Buildings/Buildings_dark_TileSet.png"), 5, 4), (60, 56, 66), 0.2)
    sludge = liquid((34, 30, 38), (120, 70, 140), 8)
    sludge[4, 3:9, :3] = (70, 140, 120)
    weeds = over(floor, tinted(load("Objects/Nature/Bleak-Yellow/Grass_2_Bleak-Yellow.png"), (150, 90, 50), 0.5))
    grating = grate(solid((84, 84, 92), 3, 9), (40, 40, 46))
    walkway = stripes(floor, (220, 180, 40), (40, 36, 30))
    crate = over(floor, load("Objects/Pallet_2.png"))
    fence = over(floor, crop(load("Tiles/Iron-Fence_TileSet.png"), 1, 1))
    beam = over(shade(floor, -20), load("Objects/Iron-beam.png"), dy=5)
    plate = plate_floor((96, 92, 104), seed=12)
    dark = shade(floor, -26)
    acid = liquid((70, 200, 80), (200, 255, 140), 10)
    pipe = over(floor, np.repeat(np.repeat(load("Objects/Exhaust-pipe.png"), 1, 0), 1, 1))
    hazard_barrel = over(floor, tinted(load("Objects/Barrel_blue_1.png"), (230, 190, 40), 0.65))
    machine = over(dark, load("Objects/Refrigerator.png")[:, 6:22])
    plates = over(floor, load("Objects/Metal-Plates.png")[7:23, 1:17])
    heap = tinted(crop(load("Tiles/Garbage_TileSet.png"), 1, 0), (70, 66, 80), 0.45)
    build("industry", [a, b, c, slag, wall, sludge, weeds, grating, walkway, crate, fence, beam,
                       plate, dark, acid, pipe, hazard_barrel, machine, plates, heap])


def sanctuary():
    green = load("Tiles/Background_Green_TileSet.png")
    a, b, c = crop(green, 0, 0), crop(green, 1, 0), crop(green, 3, 0)
    pebbles = crop(green, 12, 14)
    white = load("Tiles/Buildings/Buildings_white_TileSet.png")
    wall = crop(white, 5, 4)
    water = liquid((70, 150, 190), (190, 240, 250), 11)
    fern = over(a, load("Objects/Nature/Green/Grass_2_Green.png"))
    stone = shade(tinted(crop(green, 8, 0), (226, 222, 210), 0.6), 8)
    moss_path = tinted(crop(green, 4, 0), (170, 190, 150), 0.35)
    fence = over(a, tinted(crop(load("Tiles/Iron-Fence_TileSet.png"), 1, 1), (80, 120, 90), 0.3))
    column = pillar(a, (226, 226, 220), (170, 170, 164))
    tiles_white = plate_floor((210, 210, 204), seed=15)
    moss = tinted(plate_floor((150, 160, 140), seed=16), (90, 130, 80), 0.35)
    pool = liquid((90, 180, 210), (220, 250, 255), 12)
    stump = over(a, load("Objects/Nature/Green/Bush_1_Green.png"))
    urn = over(a, tinted(load("Objects/Barrel_blue_2.png"), (210, 210, 200), 0.6))
    console = over(tiles_white, tinted(load("Objects/Refrigerator.png")[:, 6:22], (170, 220, 230), 0.35))
    leaves = over(a, load("Objects/Nature/Green/Grass_1_Green.png"))
    hedge = over(a, load("Objects/Nature/Green/Bush_2_Green.png"))
    build("sanctuary", [a, b, c, pebbles, wall, water, fern, stone, moss_path, planter(a), fence, column,
                        tiles_white, moss, pool, stump, urn, console, leaves, hedge])


def main():
    fields()
    industry()
    sanctuary()


if __name__ == "__main__":
    main()
