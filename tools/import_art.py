#!/usr/bin/env python3
"""Builds the game's world art from the third-party packs in art_src/ (not in git;
see CREDITS.md for the licences). Run from game/:  python3 tools/import_art.py

Writes the tileset atlas (same column order as generate_assets.py, so map
characters and collision are unchanged) and the player sheet. Everything else
in assets/ still comes from generate_assets.py until it is replaced.
"""
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pngio import read_png, write_png  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
PACK = ROOT / "art_src" / "lazystone" / "PostApocalypse_AssetPack_v1.1.2"
CRAFTPIX = ROOT / "art_src" / "craftpix_zombie" / "craftpix-net-794432-free-urban-zombie-survival-pixel-art-minigame-kit"
# Props cut from the CraftPix city sheet: name -> (x, y, width, height) in pixels.
DECOR = {
    "dumpster": (193, 162, 46, 28),
    "bench": (240, 135, 32, 23),
    "ac_unit": (160, 139, 16, 15),
    "trash_bag_a": (274, 146, 12, 12),
    "trash_bag_b": (290, 145, 13, 13),
    "fence": (242, 162, 44, 28),
    "box_open": (176, 160, 16, 16),
    "box_closed": (176, 178, 16, 13),
    "hydrant": (195, 192, 10, 16),
    "tire": (209, 194, 14, 14),
    "fire": (274, 194, 12, 13),
}
TILE = 16


def load(relative):
    return read_png(PACK / relative)


def crop(image, col, row, w=1, h=1):
    return image[row * TILE:(row + h) * TILE, col * TILE:(col + w) * TILE].copy()


def over(base, sprite, dx=None, dy=None):
    """Alpha-composite a sprite onto a copy of base, centred and bottom-aligned by default."""
    out = base.copy()
    h, w = sprite.shape[:2]
    dx = (TILE - w) // 2 if dx is None else dx
    dy = TILE - h if dy is None else dy
    for y in range(h):
        for x in range(w):
            ty, tx = y + dy, x + dx
            if 0 <= ty < TILE and 0 <= tx < TILE and sprite[y, x, 3] > 0:
                alpha = sprite[y, x, 3] / 255.0
                out[ty, tx, :3] = (sprite[y, x, :3] * alpha + out[ty, tx, :3] * (1 - alpha)).astype(np.uint8)
                out[ty, tx, 3] = 255
    return out


def tinted(tile, rgb, strength):
    out = tile.copy()
    for channel in range(3):
        out[:, :, channel] = (out[:, :, channel] * (1 - strength) + rgb[channel] * strength).astype(np.uint8)
    return out


def build_tileset():
    ground_sheet = load("Tiles/Background_Bleak-Yellow_TileSet.png")
    ground_a, ground_b, ground_c = crop(ground_sheet, 0, 0), crop(ground_sheet, 2, 0), crop(ground_sheet, 5, 0)
    rubble = crop(ground_sheet, 3, 1)
    concrete = crop(ground_sheet, 5, 8)
    path = crop(ground_sheet, 8, 0)
    dark = tinted(concrete, (30, 30, 44), 0.45)
    brick = tinted(crop(load("Tiles/Brick-Wall_TileSet.png"), 0, 1), (110, 84, 84), 0.3)
    puddle = load("Objects/Nature/Flowers_Mashrooms_Other-nature-stuff/Puddles-And-Water-Anim/Puddle_On-Dry-Ground_3.png")
    garbage = load("Tiles/Garbage_TileSet.png")
    obj = lambda name: load("Objects/" + name)

    water = over(ground_a, puddle)
    water = np.where((np.abs(water[:, :, :3].astype(int) - ground_a[:, :, :3].astype(int)).sum(axis=2) > 0)[..., None], tinted(water, (40, 120, 150), 0.55), water)
    water = tinted(water, (40, 110, 140), 0.35)
    toxic = tinted(over(ground_a, puddle), (110, 200, 60), 0.55)

    tiles = [
        ground_a, ground_b, ground_c,
        rubble, brick, water,
        over(ground_a, obj("Nature/Bleak-Yellow/Grass_2_Bleak-Yellow.png")),
        concrete, path,
        over(ground_a, obj("Pallet_1.png")),
        over(ground_a, crop(load("Tiles/Wire-Fence/Wire-Fence_TileSet.png"), 1, 1)),
        over(dark, obj("Iron-beam.png"), dy=5),
        tinted(concrete, (76, 70, 86), 0.3),
        dark, toxic,
        over(ground_a, load("Objects/Nature/Flowers_Mashrooms_Other-nature-stuff/Stump_1.png")),
        over(ground_a, obj("Barrel_rust_red_1.png")),
        over(dark, obj("Washing-machine.png")),
        over(ground_a, obj("Trash-bag_1.png")),
        crop(garbage, 1, 0),
    ]
    sheet = np.concatenate(tiles, axis=1)
    write_png(ROOT / "assets" / "tilesets" / "outpost_tiles.png", sheet)
    print("tileset:", len(tiles), "tiles")


def build_props():
    garbage = load("Tiles/Garbage_TileSet.png")
    write_png(ROOT / "assets" / "sprites" / "scrap_pile.png", crop(garbage, 0, 0, 2, 2))
    print("props written")


def build_decor():
    if not CRAFTPIX.exists():
        return
    sheet = read_png(CRAFTPIX / "City_Tileset" / "PSD" / "Tile.png")
    for name, (x, y, w, h) in DECOR.items():
        write_png(ROOT / "assets" / "sprites" / "decor" / f"{name}.png", sheet[y:y + h, x:x + w].copy())
    print("decor:", len(DECOR), "props")


def player_frame(sheet_path, index, width):
    sheet = load(sheet_path)
    frame = sheet[:, index * width:(index + 1) * width]
    cell = np.zeros((TILE, TILE, 4), np.uint8)
    h = frame.shape[0]
    if h > TILE:  # run frames are 17px tall: drop the empty top row
        frame = frame[h - TILE:]
        h = TILE
    cell[TILE - h:, (TILE - width) // 2:(TILE - width) // 2 + width] = frame
    return cell


def build_player():
    rows = []
    for direction in ("down", "up", "side-left", "side"):
        idle = f"Character/Main/Idle/Character_{direction}_idle-Sheet6.png"
        run = f"Character/Main/Run/Character_{direction}_run-Sheet6.png"
        width = 13
        cells = [player_frame(idle, 0, width), player_frame(run, 1, width), player_frame(run, 4, width)]
        rows.append(np.concatenate(cells, axis=1))
    write_png(ROOT / "assets" / "sprites" / "player.png", np.concatenate(rows, axis=0))
    print("player sheet written")


def build_all():
    build_tileset()
    build_player()
    build_props()
    build_decor()


if __name__ == "__main__":
    build_all()
