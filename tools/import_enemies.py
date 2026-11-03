#!/usr/bin/env python3
"""Copies the pack's zombie animations into assets/sprites/enemies/ and writes
data/enemy_sprites.json (frame counts and sizes) so Enemy can build its
animations. Run from game/:  python3 tools/import_enemies.py
Needs art_src/ (not in git). Frame counts come from the pack's "-SheetN" names.
"""
import json
import re
import shutil
import struct
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
PACK = ROOT / "art_src" / "lazystone" / "PostApocalypse_AssetPack_v1.1.2" / "Enemies"
OUT = ROOT / "assets" / "sprites" / "enemies"
DIRECTIONS = {"Down": "down", "Up": "up", "Side": "right", "Side-left": "left"}
ANIMATIONS = {"idle": "Idle", "walk": "Walk", "attack": "First-Attack", "death": "First-Death"}
TYPES = {"walker": "Zombie_Axe", "runner": "Zombie_Small", "brute": "Zombie_Big"}


def find(folder, direction, animation):
    pattern = re.compile(rf"^{folder}_{re.escape(direction)}_{re.escape(animation)}-Sheet(\d+)\.png$", re.IGNORECASE)
    for path in sorted((PACK / folder).glob("*.png")):
        match = pattern.match(path.name)
        if match:
            return path, int(match.group(1))
    return None, 0


def size_of(path):
    with open(path, "rb") as handle:
        return struct.unpack(">II", handle.read(24)[16:24])


def main():
    manifest = {}
    for enemy_id, folder in TYPES.items():
        target = OUT / enemy_id
        target.mkdir(parents=True, exist_ok=True)
        entry = {"animations": {}}
        canvas_w = canvas_h = 0
        for anim_key, pack_anim in ANIMATIONS.items():
            for pack_dir, our_dir in DIRECTIONS.items():
                path, frames = find(folder, pack_dir, pack_anim)
                if path is None and anim_key == "death":
                    # Only the side views have death sheets; up and down reuse them.
                    path, frames = find(folder, "Side" if our_dir in ("up", "right") else "Side-left", pack_anim)
                if path is None:
                    raise SystemExit(f"missing {folder} {pack_dir} {pack_anim}")
                destination = target / f"{anim_key}_{our_dir}.png"
                shutil.copyfile(path, destination)
                width, height = size_of(path)
                frame_w = width // frames
                canvas_w, canvas_h = max(canvas_w, frame_w), max(canvas_h, height)
                entry["animations"][f"{anim_key}_{our_dir}"] = {
                    "file": f"res://assets/sprites/enemies/{enemy_id}/{anim_key}_{our_dir}.png",
                    "frames": frames, "frame_w": frame_w, "frame_h": height,
                }
        entry["canvas"] = [canvas_w, canvas_h]
        manifest[enemy_id] = entry
    (ROOT / "data" / "enemy_sprites.json").write_text(json.dumps(manifest, indent="\t") + "\n")
    print("imported", ", ".join(manifest), "->", OUT)


if __name__ == "__main__":
    main()
