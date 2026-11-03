"""Draws the 9x9 quest-category icons used by the tracker and the quest board:
sort (a bin with arrows), combat (a sword), explore (a flag), learn (a book),
puzzle (a cog), goal (a star) and done (a tick). Run from the game folder."""
import pathlib
import sys

import numpy as np

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from pngio import write_png  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
OUT = (26, 18, 32, 255)

ICONS = {
    "sort": ("#7bc043", [
        ".........",
        "..aaaaa..",
        ".ooooooo.",
        "..aaaaa..",
        "..a.a.a..",
        "..a.a.a..",
        "..a.a.a..",
        "..aaaaa..",
        ".........",
    ]),
    "combat": ("#d8dce8", [
        ".......aa",
        "......aa.",
        ".....aa..",
        "....aa...",
        ".o.aa....",
        "..oa.....",
        "..oo.....",
        ".o..o....",
        "o........",
    ]),
    "explore": ("#f2b45a", [
        ".o.......",
        ".oaaaa...",
        ".oaaaaaa.",
        ".oaaaa...",
        ".o.......",
        ".o.......",
        ".o.......",
        ".o.......",
        "ooo......",
    ]),
    "learn": ("#7fd0e8", [
        ".........",
        ".aaa.aaa.",
        "aaaaoaaaa",
        "aaaaoaaaa",
        "aaaaoaaaa",
        "aaaaoaaaa",
        "aaaaoaaaa",
        ".ooo.ooo.",
        ".........",
    ]),
    "puzzle": ("#c8b8e8", [
        "...a.a...",
        "..aaaaa..",
        ".aaa.aaa.",
        "aaa...aaa",
        ".aa...aa.",
        "aaa...aaa",
        ".aaa.aaa.",
        "..aaaaa..",
        "...a.a...",
    ]),
    "goal": ("#f2d16b", [
        "....a....",
        "....a....",
        "...aaa...",
        "aaaaaaaaa",
        ".aaaaaaa.",
        "..aaaaa..",
        "..aa.aa..",
        ".aa...aa.",
        ".a.....a.",
    ]),
    "done": ("#8fd27a", [
        ".........",
        ".......aa",
        "......aa.",
        ".....aa..",
        "aa..aa...",
        ".aaaa....",
        "..aa.....",
        ".........",
        ".........",
    ]),
}


def hexc(code):
    code = code.lstrip("#")
    return tuple(int(code[i:i + 2], 16) for i in (0, 2, 4)) + (255,)


def main():
    out_dir = ROOT / "assets/sprites/icons"
    out_dir.mkdir(parents=True, exist_ok=True)
    for name, (color, rows) in ICONS.items():
        px = np.zeros((9, 9, 4), np.uint8)
        fill = hexc(color)
        shade = tuple(int(c * 0.6) for c in fill[:3]) + (255,)
        for y, row in enumerate(rows):
            for x, ch in enumerate(row):
                if ch == "a":
                    px[y, x] = fill
                elif ch == "o":
                    px[y, x] = shade
        write_png(str(out_dir / f"quest_{name}.png"), px)
    print(f"drew {len(ICONS)} quest icons")


if __name__ == "__main__":
    main()
