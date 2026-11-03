"""Pixel art for the errands between areas: the three parts you carry (radio
valve, seed tin, filter cartridge) and the three places that need them, each
in a "waiting" and a "done" state. Letters map to the palette below; '.' is
clear. Run from the game folder."""
import pathlib
import sys

import numpy as np

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from pngio import write_png  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
PALETTE = {
    "k": "#1a1220", "g": "#4a4a56", "G": "#7a7a8c", "w": "#c8c8d8", "W": "#f4ead6",
    "y": "#f2c23a", "Y": "#ffe27a", "o": "#d8782c", "b": "#6a4a30", "B": "#8a6a40",
    "s": "#3a2a20", "e": "#5aa040", "E": "#9be04a", "c": "#5fb0d0", "C": "#bff4ff",
    "r": "#c83c3c", "t": "#2a3a44", "m": "#3e6aa0",
}

ART = {
    "items/radio_valve": [
        "................",
        "......kkkk......",
        ".....kCCCCk.....",
        "....kCWCCCCk....",
        "....kCCCCCCk....",
        "....kCoYoCCk....",
        "....kCCoCCCk....",
        "....kCCoCCCk....",
        "....kCCCCCCk....",
        ".....kCCCCk.....",
        ".....kggggk.....",
        "....kgGGGGgk....",
        "....kggggggk....",
        ".....k.k.k......",
        ".....k.k.k......",
        "................",
    ],
    "items/seed_tin": [
        "................",
        "................",
        "....kkkkkkkk....",
        "...kwwwwwwwwk...",
        "...kGGGGGGGGk...",
        "...kyyyyyyyyk...",
        "...kyyeEeyyyk...",
        "...kyeEeEeyyk...",
        "...kyyeEeyyyk...",
        "...kyyyeyyyyk...",
        "...kyyyyyyyyk...",
        "...kGGGGGGGGk...",
        "....kkkkkkkk....",
        "................",
        "................",
        "................",
    ],
    "items/filter_cartridge": [
        "................",
        ".....kkkkkk.....",
        "....kwwwwwwk....",
        "....kGGGGGGk....",
        "....kssssssk....",
        "....kstststk....",
        "....ksssssk.....",
        "....kstststk....",
        "....kssssssk....",
        "....kstststk....",
        "....kssssssk....",
        "....kGGGGGGk....",
        "....kwwwwwwk....",
        ".....kkcckk.....",
        ".......cc.......",
        "................",
    ],
    "request_radio": [
        ".......kk.......",
        "......kggk......",
        ".......kk.......",
        "......kggk......",
        ".....kg..gk.....",
        ".....kg..gk.....",
        "....kg.kk.gk....",
        "....kg.kk.gk....",
        "...kg..kk..gk...",
        "...kg..kk..gk...",
        "..kg...kk...gk..",
        "..kkkkkkkkkkkk..",
        "..kGGGGGGGGGGk..",
        "..kGtttttttGGk..",
        "..kGtkkkkktGGk..",
        "..kGtttttttGGk..",
        "..kGGGGGGGGGGk..",
        "..kbbbbbbbbbbk..",
        "..kkkkkkkkkkkk..",
    ],
    "request_radio_done": [
        ".......kk.......",
        "......krrk......",
        ".......kk.......",
        "......kggk......",
        ".....kg..gk.....",
        ".....kg..gk.....",
        "....kg.kk.gk....",
        "....kg.kk.gk....",
        "...kg..kk..gk...",
        "...kg..kk..gk...",
        "..kg...kk...gk..",
        "..kkkkkkkkkkkk..",
        "..kGGGGGGGGGGk..",
        "..kGtEtEtEtGGk..",
        "..kGtkkkkktGGk..",
        "..kGtCCCCCtGGk..",
        "..kGGGGGGGGGGk..",
        "..kbbbbbbbbbbk..",
        "..kkkkkkkkkkkk..",
    ],
    "request_garden": [
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
        "................",
        ".kkkkkkkkkkkkkk.",
        ".kBBBBBBBBBBBBk.",
        ".kBsssssssssBBk.",
        ".kBsbsbsbsbsBBk.",
        ".kBsssssssssBBk.",
        ".kbbbbbbbbbbbbk.",
        ".kkkkkkkkkkkkkk.",
    ],
    "request_garden_done": [
        "................",
        "................",
        "....E.....E.....",
        "...EeE...EeE.E..",
        "....e..E..e.EeE.",
        "..E.e.EeE.e..e..",
        ".EeEe..e..e..e..",
        "..e.e..e..e..e..",
        "..e.e..e..e..e..",
        "..e.e..e..e..e..",
        ".kkkkkkkkkkkkkk.",
        ".kBBBBBBBBBBBBk.",
        ".kBsssssssssBBk.",
        ".kBsbsbsbsbsBBk.",
        ".kBsssssssssBBk.",
        ".kbbbbbbbbbbbbk.",
        ".kkkkkkkkkkkkkk.",
    ],
    "request_fountain": [
        "................",
        "......kkkk......",
        ".....kGGGGk.....",
        ".....kGkkGk.....",
        "......kGGk......",
        "......kGGk......",
        "......kGGk......",
        "....kkkGGkkk....",
        "...kGGGGGGGGk...",
        "..kGgggggggGGk..",
        "..kGgsssssgGGk..",
        "..kGgggggggGGk..",
        "...kGGGGGGGGk...",
        "....kkGGGGkk....",
        "......kGGk......",
        ".....kGGGGk.....",
        "....kkkkkkkk....",
    ],
    "request_fountain_done": [
        "......C..C......",
        "......kkkk.C....",
        ".....kGGGGk.....",
        ".....kGccGk.....",
        "......kGGk......",
        "......kGGk......",
        "......kGGk......",
        "....kkkGGkkk....",
        "...kGGGGGGGGk...",
        "..kGcCcccCcGGk..",
        "..kGccCcccCGGk..",
        "..kGcccCcccGGk..",
        "...kGGGGGGGGk...",
        "....kkGGGGkk....",
        "......kGGk......",
        ".....kGGGGk.....",
        "....kkkkkkkk....",
    ],
}


def hexc(code):
    code = code.lstrip("#")
    return tuple(int(code[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def main():
    for name, rows in ART.items():
        width = max(len(row) for row in rows)
        px = np.zeros((len(rows), width, 4), np.uint8)
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch != ".":
                    px[y, x] = hexc(PALETTE[ch])
        path = ROOT / "assets/sprites" / f"{name}.png"
        path.parent.mkdir(parents=True, exist_ok=True)
        write_png(str(path), px)
    print(f"drew {len(ART)} errand sprites")


if __name__ == "__main__":
    main()
