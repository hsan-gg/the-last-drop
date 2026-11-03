"""Restyles the generated placeholder sprites (items, bins, machines, props) to
match the third-party pack: every pixel is snapped to the pack's own palette,
and a few items are replaced by the pack's props where they fit.

Runs after generate_assets.py and import_art.py (generate_assets calls it).
Needs art_src/ (see CREDITS.md); does nothing without it.
"""
import sys
from collections import Counter
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
from pngio import read_png, write_png  # noqa: E402

ROOT = Path(__file__).resolve().parent.parent
PACK = ROOT / "art_src" / "lazystone" / "PostApocalypse_AssetPack_v1.1.2"
SPRITES = ROOT / "assets" / "sprites"
PALETTE_SIZE = 56
GENERATED = [
    *sorted((SPRITES / "items").glob("*.png")),
    *sorted((SPRITES / "bins").glob("*.png")),
    *(SPRITES / f"{name}.png" for name in (
        "treatment_unit_broken", "treatment_unit_fixed", "generator_broken", "generator_fixed",
        "shelter_broken", "shelter_fixed", "terminal_off", "terminal_on", "recorder", "gate",
        "water_dirty", "water_clean", "arrow_up",
    )),
]
# Items the pack already draws well: item id -> (pack file, canvas size).
REPLACEMENTS = {
    "chemical_can": "Objects/Barrel_rust_red_1.png",
    "cardboard": "Objects/Cardboard_1.png",
    "greasy_pizza_box": "Objects/Cardboard_2.png",
    "tin_can": "UI/Inventory/Objects/Icon_Canned-food.png",
}


# Blues and light colours that the most-used palette lacks (glass, water, clean-state lights).
EXTRA_PALETTE_SOURCES = ["Objects/Barrel_blue_1.png", "Objects/Vending-machine_Blue.png", "UI/Inventory/Objects/Icon_Canned-soup.png"]


def pack_palette():
    counts = Counter()
    for path in (PACK / "Objects").glob("*.png"):
        pixels = read_png(path).reshape(-1, 4)
        for r, g, b, a in pixels[pixels[:, 3] == 255]:
            counts[(int(r), int(g), int(b))] += 1
    colors = [color for color, _ in counts.most_common(PALETTE_SIZE)]
    for source in EXTRA_PALETTE_SOURCES:
        pixels = read_png(PACK / source).reshape(-1, 4)
        for r, g, b, a in pixels[pixels[:, 3] == 255]:
            if (int(r), int(g), int(b)) not in colors:
                colors.append((int(r), int(g), int(b)))
    return np.array(colors, np.int32)


def snap(image, palette):
    out = image.copy()
    opaque = image[:, :, 3] > 0
    rgb = image[:, :, :3].astype(np.int32)
    flat = rgb.reshape(-1, 1, 3) - palette.reshape(1, -1, 3)
    nearest = np.argmin((flat ** 2).sum(axis=2), axis=1).reshape(image.shape[:2])
    out[:, :, :3] = np.where(opaque[..., None], palette[nearest], rgb).astype(np.uint8)
    out[:, :, 3] = np.where(opaque, 255, 0)
    return out


def on_canvas(sprite, size=16):
    canvas = np.zeros((size, size, 4), np.uint8)
    h, w = sprite.shape[:2]
    canvas[size - h:, (size - w) // 2:(size - w) // 2 + w] = sprite[:size, :size]
    return canvas


def stain_greasy_box():
    """The pizza box is the pack's cardboard plus dark grease spots, so it reads differently."""
    path = SPRITES / "items" / "greasy_pizza_box.png"
    box = read_png(path)
    grease = np.array([66, 40, 40, 255], np.uint8)
    for x, y in ((6, 8), (7, 8), (7, 9), (9, 7), (10, 7), (10, 8), (8, 10)):
        if box[y, x, 3] > 0:
            box[y, x] = grease
    write_png(path, box)


def build():
    palette = pack_palette()
    for path in GENERATED:
        if path.exists():
            write_png(path, snap(read_png(path), palette))
    for item_id, source in REPLACEMENTS.items():
        write_png(SPRITES / "items" / f"{item_id}.png", on_canvas(read_png(PACK / source)))
    stain_greasy_box()
    print(f"restyled {len(GENERATED)} sprites to the pack palette ({len(palette)} colours)")


if __name__ == "__main__":
    build()
