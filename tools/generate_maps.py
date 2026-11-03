#!/usr/bin/env python3
"""Generates data/maps/*.txt, the ASCII level layouts, and checks reachability.

Run from the game/ folder:  python3 tools/generate_maps.py
After generation the .txt files are the source of truth; edit them by hand.

Tile characters (see world/map_builder.gd):
  . ground   , dead grass   # wall   ~ water    : concrete   = path
  r rubble   C crate        F fence  P pipe     M metal floor D dark floor
  T toxic    t dead tree    B barrel S rack
Marker characters (entities, placed by data/areas.json; the floor shows beneath):
  @ spawn  $ scrap pile  W water  U treatment unit  V recording
  ^ gate   G generator   K terminal
"""
import random
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MAPS = ROOT / "data" / "maps"

BLOCKING = set("#~CFPtBS")
MARKERS = set("@$WUV^GK")
# Markers that block movement; the spawn marker does not.
BLOCKING_MARKERS = MARKERS - {"@"}


class Grid:
    def __init__(self, width, height, fill):
        self.w, self.h = width, height
        self.cells = [[fill] * width for _ in range(height)]

    def put(self, x, y, ch):
        self.cells[y][x] = ch

    def get(self, x, y):
        return self.cells[y][x]

    def fill(self, x0, y0, x1, y1, ch):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.put(x, y, ch)

    def box(self, x0, y0, x1, y1, ch):
        for x in range(x0, x1 + 1):
            self.put(x, y0, ch)
            self.put(x, y1, ch)
        for y in range(y0, y1 + 1):
            self.put(x0, y, ch)
            self.put(x1, y, ch)

    def find(self, ch):
        return [(x, y) for y in range(self.h) for x in range(self.w) if self.cells[y][x] == ch]

    def text(self):
        return "\n".join("".join(row) for row in self.cells) + "\n"


def reachable_from(grid, start):
    seen = {start}
    queue = deque([start])
    while queue:
        x, y = queue.popleft()
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            nx, ny = x + dx, y + dy
            if not (0 <= nx < grid.w and 0 <= ny < grid.h) or (nx, ny) in seen:
                continue
            ch = grid.get(nx, ny)
            if ch in BLOCKING or ch in BLOCKING_MARKERS:
                continue
            seen.add((nx, ny))
            queue.append((nx, ny))
    return seen


def check_reachable(name, grid):
    spawn = grid.find("@")
    assert len(spawn) == 1, f"{name}: need exactly one spawn"
    seen = reachable_from(grid, spawn[0])
    for marker in BLOCKING_MARKERS:
        for x, y in grid.find(marker):
            neighbours = [(x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)]
            assert any(n in seen for n in neighbours), f"{name}: marker {marker} at {(x, y)} is unreachable"


def scatter(grid, rng, reserved, choices):
    for y in range(1, grid.h - 1):
        for x in range(1, grid.w - 1):
            if (x, y) in reserved or grid.get(x, y) != ".":
                continue
            roll = rng.random()
            threshold = 0.0
            for ch, probability in choices:
                threshold += probability
                if roll < threshold:
                    grid.put(x, y, ch)
                    break


def rect_cells(x0, y0, x1, y1, margin=0):
    return {(x, y) for y in range(y0 - margin, y1 + margin + 1) for x in range(x0 - margin, x1 + margin + 1)}


def build_outpost():
    grid = Grid(40, 26, ".")
    rng = random.Random(42)
    grid.box(0, 0, 39, 25, "#")

    # Main path north to the gate, plus branches to the shelter and the water yard.
    grid.fill(19, 2, 20, 22, "=")
    grid.fill(12, 17, 18, 18, "=")
    grid.fill(21, 12, 26, 13, "=")

    # Shelter in the west: walls, concrete floor, a door on the east side.
    grid.box(3, 13, 11, 21, "#")
    grid.fill(4, 14, 10, 20, ":")
    grid.fill(11, 17, 11, 18, ":")
    grid.put(6, 17, "@")

    # Water yard in the east, fenced, with a gap on the west side.
    grid.box(27, 8, 37, 17, "F")
    grid.fill(27, 12, 27, 13, "=")
    grid.put(34, 12, "W")
    grid.put(30, 12, "U")

    grid.put(23, 19, "$")
    grid.put(8, 6, "V")
    grid.put(19, 1, "^")
    grid.put(20, 1, "=")

    for x, y in ((14, 5), (15, 5), (14, 6), (30, 20), (31, 20), (30, 21)):
        grid.put(x, y, "C" if y < 10 else "B")
    for x, y in ((6, 5), (11, 6), (7, 9), (10, 3), (24, 5), (35, 22)):
        grid.put(x, y, "t")

    reserved = set()
    reserved |= rect_cells(3, 13, 11, 21, 1)
    reserved |= rect_cells(27, 8, 37, 17, 1)
    reserved |= rect_cells(19, 1, 20, 22, 1)
    reserved |= rect_cells(12, 12, 26, 18, 0)
    for marker in "@$WUV":
        for x, y in grid.find(marker):
            reserved |= rect_cells(x, y, x, y, 2)
    scatter(grid, rng, reserved, [(",", 0.10), ("r", 0.06), ("t", 0.012)])

    # A ring of rubble around the scrap pile sells the "buried in waste" setting.
    for dy in range(-3, 4):
        for dx in range(-4, 5):
            x, y = 23 + dx, 19 + dy
            if grid.get(x, y) == "." and rng.random() < 0.55:
                grid.put(x, y, "r")
    return grid


def build_factory():
    grid = Grid(36, 24, "M")
    rng = random.Random(7)
    grid.box(0, 0, 35, 23, "#")
    grid.fill(1, 1, 34, 7, "D")

    grid.fill(3, 1, 12, 1, "P")
    grid.fill(22, 1, 32, 1, "P")
    for y in (5, 7):
        grid.fill(4, y, 8, y, "S")
        grid.fill(27, y, 31, y, "S")

    for x, y in ((3, 12), (3, 13), (4, 13), (31, 17), (32, 17), (32, 18)):
        grid.put(x, y, "B")
    for x, y in ((24, 19), (25, 19)):
        grid.put(x, y, "C")
    for x, y in ((13, 15), (14, 15), (13, 16), (22, 10), (23, 10), (9, 19), (10, 19)):
        grid.put(x, y, "T")

    grid.put(18, 21, "@")
    grid.put(10, 13, "$")
    grid.put(27, 12, "G")
    grid.put(18, 3, "K")

    # Scuffed floor so the hall does not look tiled.
    for y in range(8, 23):
        for x in range(1, 35):
            if grid.get(x, y) == "M" and rng.random() < 0.05:
                grid.put(x, y, "D")
    return grid


def main():
    MAPS.mkdir(parents=True, exist_ok=True)
    for name, builder in (("outpost", build_outpost), ("factory", build_factory)):
        grid = builder()
        check_reachable(name, grid)
        (MAPS / f"{name}.txt").write_text(grid.text())
        print(f"{name}: {grid.w}x{grid.h} ok, every interactable is reachable")


if __name__ == "__main__":
    main()
