#!/usr/bin/env python3
"""Generates data/maps/*.txt, the ASCII level layouts, and checks reachability.

Run from the game/ folder:  python3 tools/generate_maps.py
After generation the .txt files are the source of truth; edit them by hand.

Tile characters (see world/map_builder.gd):
  . ground   , dead grass   # wall   ~ water    : concrete   = path
  r rubble   C crate        F fence  P pipe     M metal floor D dark floor
  T toxic    t dead tree    B barrel S rack
  b plastic bags (walkable)   H garbage heap
Decor markers (set dressing, data/areas.json gives each its sprite):
  d dumpster  e bench  f fire barrel  x box  y tire  z hydrant  k AC unit
  g trash bag  h open box
Pickup markers (hidden finds, data/areas.json names the item): p q j
Water test points: m n o
Generator N (lights the region) and lamps L.   Enemies: Y walker  Q runner  R brute.   Chests: c l (areas.json gives each its loot)
Marker characters (entities, placed by data/areas.json; the floor shows beneath):
  @ spawn  $ scrap pile  W water  U treatment unit  V recording
  ^ gate   G generator   K terminal  1 2 3 numbered scrap piles
"""
import random
import sys
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MAPS = ROOT / "data" / "maps"

BLOCKING = set("#~CFPtBSH")
MARKERS = set("@$WUV^GK123defxyzkghpqjmnoYQRclNLJAOZEIXaisuvw456789")
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


def place_decor(grid, ch, x, y, floor="."):
    """Puts a decor marker on the free floor cell nearest (x, y), keeping a
    walkable neighbour so the reachability check still holds."""
    for radius in range(0, 6):
        for dy in range(-radius, radius + 1):
            for dx in range(-radius, radius + 1):
                px, py = x + dx, y + dy
                if 1 <= px < grid.w - 1 and 1 <= py < grid.h - 1 and grid.get(px, py) == floor:
                    grid.put(px, py, ch)
                    return
    raise ValueError(f"no free cell for decor {ch} near {(x, y)}")


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
    for ch, x, y in (("f", 10, 10), ("d", 14, 22), ("e", 22, 6), ("x", 17, 21), ("z", 24, 10), ("g", 31, 23), ("y", 5, 23)):
        place_decor(grid, ch, x, y)
    for ch, x, y in (("Y", 28, 5), ("Y", 12, 3)):
        place_decor(grid, ch, x, y)
    place_decor(grid, "c", 9, 15, floor=":")
    for ch, x, y in (("N", 22, 4), ("L", 17, 8), ("L", 24, 15), ("L", 32, 20), ("L", 14, 4)):
        place_decor(grid, ch, x, y)
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
    grid.put(10, 22, "J")  # the gate back to the outpost
    grid.put(10, 13, "$")
    grid.put(27, 12, "G")
    grid.put(18, 3, "K")
    grid.put(33, 2, "^")

    # Scuffed floor so the hall does not look tiled.
    for y in range(8, 23):
        for x in range(1, 35):
            if grid.get(x, y) == "M" and rng.random() < 0.05:
                grid.put(x, y, "D")
    for ch, x, y in (("x", 20, 18), ("x", 21, 18), ("y", 8, 16), ("k", 30, 14), ("h", 6, 21), ("g", 25, 21)):
        place_decor(grid, ch, x, y, floor="M")
    for ch, x, y in (("Y", 9, 10), ("Q", 28, 17), ("Q", 6, 18), ("R", 29, 5)):
        place_decor(grid, ch, x, y, floor="M")
    place_decor(grid, "c", 4, 20, floor="M")
    place_decor(grid, "N", 30, 3, floor="D")
    for x, y in ((8, 12), (26, 19), (14, 20), (32, 10)):
        place_decor(grid, "L", x, y, floor="M")
    return grid


def build_dump():
    """The Great Dump: three heap-ringed yards joined by lanes, the shelter site
    in the middle, a recording tucked in the north-west and the records terminal
    in the north-east. Spawn is south-west, where the factory gate lets out."""
    grid = Grid(46, 30, ".")
    rng = random.Random(21)
    grid.box(0, 0, 45, 29, "H")
    grid.box(1, 1, 44, 28, "H")

    # Heap ridges that divide the dump into yards, each with a gap to walk through.
    grid.fill(2, 17, 16, 18, "H")
    grid.fill(7, 17, 9, 18, ".")
    grid.fill(17, 11, 18, 27, "H")
    grid.fill(17, 21, 18, 22, ".")
    grid.fill(17, 11, 31, 12, "H")
    grid.fill(24, 11, 26, 12, ".")
    grid.fill(31, 2, 32, 12, "H")
    grid.fill(31, 7, 32, 8, ".")
    grid.fill(2, 8, 12, 9, "H")
    grid.fill(5, 8, 7, 9, ".")

    # Walked lanes so the way through reads at a glance.
    grid.fill(8, 19, 8, 27, "=")
    grid.fill(8, 20, 21, 21, "=")
    grid.fill(21, 14, 22, 21, "=")
    grid.fill(22, 13, 25, 14, "=")
    grid.fill(25, 5, 26, 13, "=")
    grid.fill(25, 5, 36, 6, "=")
    grid.fill(6, 10, 7, 16, "=")

    grid.put(4, 26, "@")
    grid.put(12, 28, "J")  # back to the factory
    grid.put(11, 23, "1")
    grid.put(22, 17, "2")
    grid.put(36, 9, "3")
    grid.put(24, 8, "U")
    grid.put(4, 4, "V")
    grid.put(40, 4, "K")

    reserved = set()
    for marker in "@123UVK":
        for x, y in grid.find(marker):
            reserved |= rect_cells(x, y, x, y, 2)
    for x0, y0, x1, y1 in ((8, 19, 8, 27), (8, 20, 21, 21), (21, 14, 22, 21), (22, 13, 25, 14), (25, 5, 26, 13), (25, 5, 36, 6), (6, 10, 7, 16)):
        reserved |= rect_cells(x0, y0, x1, y1, 1)
    scatter(grid, rng, reserved, [("b", 0.14), ("r", 0.07), ("H", 0.035), (",", 0.02)])
    for ch, x, y in (("d", 13, 25), ("d", 30, 18), ("d", 38, 22), ("e", 6, 13), ("f", 4, 22), ("f", 40, 12), ("x", 20, 24), ("x", 27, 6), ("y", 12, 13), ("z", 35, 4), ("g", 28, 22), ("g", 14, 4), ("p", 43, 3), ("q", 3, 27), ("j", 41, 27), ("^", 42, 15)):
        place_decor(grid, ch, x, y)
    for ch, x, y in (("Y", 22, 8), ("Y", 30, 16), ("Y", 14, 12), ("Q", 38, 24), ("Q", 8, 8), ("R", 36, 10), ("c", 43, 27), ("l", 3, 3), ("N", 43, 10), ("L", 10, 10), ("L", 26, 20), ("L", 34, 6), ("L", 8, 24)):
        place_decor(grid, ch, x, y)
    return grid


def build_river():
    """The Dead River: a river band splits the map, crossed by one bridge. The
    south bank has two heaps and three water test points; the north bank has the
    filter plant in a fenced yard, its console, the recording and a water point."""
    grid = Grid(46, 30, ".")
    rng = random.Random(33)
    grid.box(0, 0, 45, 29, "H")
    grid.box(1, 1, 44, 28, "H")

    grid.fill(2, 13, 43, 17, "~")  # the river
    grid.fill(22, 8, 24, 21, "=")  # bridge and its approaches
    grid.fill(22, 22, 24, 22, "=")
    grid.fill(15, 24, 21, 24, "=")  # path from the spawn side
    grid.fill(4, 24, 14, 24, "=")

    grid.box(30, 3, 43, 9, "F")  # the plant yard, open on its west side
    grid.fill(30, 6, 30, 7, ".")
    grid.fill(25, 6, 29, 7, "=")

    grid.put(4, 26, "@")
    grid.put(12, 28, "J")  # back to the dump
    grid.put(40, 1, "^")  # upstream to the fields
    grid.put(11, 22, "1")
    grid.put(31, 24, "2")
    grid.put(8, 19, "m")
    grid.put(27, 19, "n")
    grid.put(39, 19, "o")
    grid.put(36, 6, "U")
    grid.put(41, 6, "K")
    grid.put(6, 5, "V")
    grid.put(34, 11, "W")

    reserved = set()
    for marker in "@12mnoUKVW":
        for x, y in grid.find(marker):
            reserved |= rect_cells(x, y, x, y, 2)
    for x0, y0, x1, y1 in ((22, 8, 24, 22), (15, 24, 21, 24), (4, 24, 14, 24), (25, 6, 29, 7), (30, 3, 43, 9)):
        reserved |= rect_cells(x0, y0, x1, y1, 1)
    scatter(grid, rng, reserved, [("b", 0.08), ("r", 0.07), (",", 0.06), ("t", 0.02)])
    for ch, x, y in (("f", 10, 11), ("d", 18, 20), ("e", 14, 7), ("x", 20, 26), ("y", 36, 26), ("z", 28, 10), ("g", 38, 25), ("g", 5, 11), ("f", 40, 22)):
        place_decor(grid, ch, x, y)
    for ch, x, y in (("Y", 16, 20), ("Y", 36, 20), ("Q", 20, 10), ("Q", 12, 6), ("R", 26, 5), ("c", 4, 9), ("l", 38, 8), ("N", 40, 12), ("L", 14, 10), ("L", 30, 11), ("L", 10, 22), ("L", 36, 22)):
        place_decor(grid, ch, x, y)
    return grid


def build_fields():
    """The Silent Fields: dead crop plots in rows, an irrigation ditch with two
    crossings, greenhouse frames, Lena's farmhouse yard with the compost bin and
    the soil terminal, and a blighted corner where the Husks rise."""
    grid = Grid(48, 30, ".")
    rng = random.Random(41)
    grid.box(0, 0, 47, 29, "#")
    grid.box(1, 1, 46, 28, "#")
    grid.fill(2, 12, 45, 13, "~")  # the irrigation ditch
    grid.fill(10, 12, 12, 13, ":")  # crossings
    grid.fill(33, 12, 35, 13, ":")
    for x0, y0 in ((4, 4), (16, 4), (4, 17), (16, 17)):  # crop plots
        for row in range(0, 6, 2):
            grid.fill(x0, y0 + row, x0 + 8, y0 + row, "=")
    for x0, y0, x1, y1 in ((27, 3, 33, 8), (38, 17, 44, 23)):  # greenhouse frames
        grid.box(x0, y0, x1, y1, "F")
        grid.fill(x0, y0 + 2, x0, y0 + 3, ".")
    grid.box(36, 3, 45, 9, "#")  # the farmhouse yard
    grid.fill(36, 6, 36, 7, ".")
    grid.fill(28, 22, 33, 26, "T")  # the blighted corner
    grid.fill(30, 24, 31, 24, ".")
    grid.put(4, 26, "@")
    grid.put(12, 28, "J")
    grid.put(44, 1, "^")
    grid.put(9, 23, "1")
    grid.put(22, 10, "2")
    grid.put(39, 5, "U")
    grid.put(43, 5, "K")
    grid.put(41, 8, "W")
    grid.put(25, 20, "V")
    reserved = set()
    for marker in "@J^12UKWV":
        for x, y in grid.find(marker):
            reserved |= rect_cells(x, y, x, y, 2)
    for x0, y0, x1, y1 in ((36, 3, 45, 9), (10, 12, 12, 13), (33, 12, 35, 13), (27, 3, 33, 8), (38, 17, 44, 23), (28, 22, 33, 26)):
        reserved |= rect_cells(x0, y0, x1, y1, 1)
    scatter(grid, rng, reserved, [(",", 0.12), ("C", 0.025), ("r", 0.04), ("t", 0.015), ("b", 0.02)])
    for ch, x, y in (("Y", 20, 8), ("Y", 8, 20), ("Y", 30, 20), ("Y", 40, 14), ("Q", 26, 15), ("Q", 14, 25), ("Y", 34, 26)):
        place_decor(grid, ch, x, y)
    for ch, x, y in (("a", 38, 11), ("i", 24, 9), ("8", 42, 21), ("c", 4, 3), ("N", 22, 26), ("L", 10, 15), ("L", 30, 15), ("L", 40, 15), ("L", 20, 24), ("f", 22, 16)):
        place_decor(grid, ch, x, y)
    return grid


def build_industry():
    """The Forgotten Industry: a smoky plant of walkways and grating between
    sheds, sludge channels and acid pools. The grid hall holds the solar array
    and the control console; the Slag Golem waits in the furnace yard."""
    grid = Grid(50, 32, ".")
    rng = random.Random(53)
    grid.box(0, 0, 49, 31, "#")
    grid.box(1, 1, 48, 30, "#")
    grid.fill(2, 15, 47, 16, "=")  # the main walkway
    grid.fill(24, 2, 25, 29, "=")
    grid.fill(2, 9, 20, 9, "~")  # sludge channels
    grid.fill(30, 22, 47, 22, "~")
    grid.fill(12, 9, 13, 9, ":")
    grid.fill(38, 22, 39, 22, ":")
    grid.box(30, 3, 45, 12, "#")  # the grid hall
    grid.fill(31, 4, 44, 11, "M")
    grid.fill(30, 7, 30, 8, "=")
    grid.box(4, 20, 18, 28, "F")  # the furnace yard, fenced
    grid.fill(11, 20, 12, 20, ".")
    for x0, y0, x1, y1 in ((6, 3, 9, 6), (14, 3, 17, 6)):
        grid.fill(x0, y0, x1, y1, "S")
    for x, y in ((36, 26), (41, 26), (44, 18), (20, 12)):
        grid.fill(x, y, x + 1, y + 1, "T")
    grid.put(3, 13, "@")
    grid.put(1, 22, "J")
    grid.put(47, 1, "^")
    grid.put(8, 12, "1")
    grid.put(28, 27, "2")
    grid.put(34, 6, "U")
    grid.put(41, 6, "K")
    grid.put(44, 10, "V")
    grid.put(11, 24, "G")
    reserved = set()
    for marker in "@J^12UKVG":
        for x, y in grid.find(marker):
            reserved |= rect_cells(x, y, x, y, 2)
    for x0, y0, x1, y1 in ((2, 15, 47, 16), (24, 2, 25, 29), (30, 3, 45, 12), (4, 20, 18, 28), (12, 9, 13, 9), (38, 22, 39, 22)):
        reserved |= rect_cells(x0, y0, x1, y1, 1)
    scatter(grid, rng, reserved, [(":", 0.08), ("B", 0.03), ("t", 0.025), ("C", 0.025), ("b", 0.04), ("H", 0.02)])
    for ch, x, y in (("Y", 20, 5), ("Y", 36, 18), ("Y", 44, 27), ("Q", 14, 13), ("Q", 30, 26), ("R", 22, 24), ("R", 40, 14)):
        place_decor(grid, ch, x, y)
    for ch, x, y in (("a", 28, 12), ("i", 10, 17), ("9", 46, 28), ("c", 3, 3), ("l", 16, 26), ("N", 27, 20), ("L", 8, 17), ("L", 20, 17), ("L", 34, 17), ("L", 44, 17), ("f", 21, 27)):
        place_decor(grid, ch, x, y)
    return grid


def build_sanctuary():
    """The Last Sanctuary: lawns and water channels around a white stone
    research hall. The atrium holds the power core, the archive and Ines's
    last recording; friends you helped wait in the garden."""
    grid = Grid(44, 30, ".")
    rng = random.Random(61)
    grid.box(0, 0, 43, 29, "#")
    grid.box(1, 1, 42, 28, "#")
    grid.fill(2, 18, 41, 18, "~")  # the channel
    grid.fill(20, 18, 23, 18, ":")
    grid.fill(21, 19, 22, 26, ":")  # the avenue to the hall
    grid.fill(21, 11, 22, 17, ":")
    grid.box(8, 3, 35, 11, "#")  # the research hall
    grid.fill(9, 4, 34, 10, "M")
    grid.fill(21, 11, 22, 11, ":")
    for x in (12, 18, 26, 31):  # columns in the atrium
        grid.put(x, 5, "P")
        grid.put(x, 9, "P")
    for x0, y0 in ((4, 21), (30, 21), (4, 13), (34, 13)):  # garden beds
        grid.fill(x0, y0, x0 + 6, y0 + 2, "=")
    grid.fill(14, 14, 16, 15, "~")
    grid.fill(27, 14, 29, 15, "~")
    grid.put(21, 26, "@")
    grid.put(13, 28, "J")
    grid.put(13, 7, "U")
    grid.put(22, 6, "K")
    grid.put(31, 7, "V")
    grid.put(16, 7, "w")
    grid.put(28, 7, "1")  # the storeroom heap
    reserved = set()
    for marker in "@JUKVw1":
        for x, y in grid.find(marker):
            reserved |= rect_cells(x, y, x, y, 2)
    for x0, y0, x1, y1 in ((8, 3, 35, 11), (20, 18, 23, 18), (21, 11, 22, 26)):
        reserved |= rect_cells(x0, y0, x1, y1, 1)
    scatter(grid, rng, reserved, [(",", 0.12), ("t", 0.03), ("b", 0.04), ("C", 0.015)])
    for ch, x, y in (("Y", 8, 24), ("Y", 34, 25), ("Y", 12, 15), ("Y", 32, 15), ("Y", 27, 8)):
        place_decor(grid, ch, x, y)
    for ch, x, y in (("a", 14, 24), ("o", 28, 24), ("i", 18, 22), ("c", 40, 3), ("N", 39, 26), ("L", 10, 20), ("L", 33, 20), ("L", 19, 13), ("L", 25, 13)):
        place_decor(grid, ch, x, y)
    return grid


# Errands between areas: a part found in one area (A, O, Z) is wanted in
# another (E, I, X), so the gates back get used.
CROSS_AREA = {
    "outpost": (("E", 12, 6, "."), ("I", 30, 18, "."), ("a", 9, 15, "."), ("i", 16, 9, ".")),
    "factory": (("A", 8, 6, "M"), ("X", 24, 14, "M"), ("s", 14, 17, "M"), ("5", 30, 18, "M")),
    "dump": (("O", 22, 14, "."), ("u", 9, 22, "."), ("v", 16, 18, "."), ("6", 40, 6, ".")),
    "river": (("Z", 30, 24, "."), ("w", 26, 25, "."), ("7", 8, 4, ".")),
}


# The rail cart network: a cart a few steps from each region's start.
CARTS = {"outpost": (10, 17, "."), "factory": (22, 21, "M"), "dump": (8, 24, "."), "river": (8, 24, "."),
         "fields": (8, 24, "."), "industry": (6, 13, "."), "sanctuary": (26, 26, ".")}


def add_cross_area(name, grid):
    for ch, x, y, floor in CROSS_AREA.get(name, ()):
        place_decor(grid, ch, x, y, floor=floor)
    if name in CARTS:
        x, y, floor = CARTS[name]
        place_decor(grid, "4", x, y, floor=floor)


def main():
    MAPS.mkdir(parents=True, exist_ok=True)
    names = set(sys.argv[1:])
    builders = (("outpost", build_outpost), ("factory", build_factory), ("dump", build_dump), ("river", build_river),
                ("fields", build_fields), ("industry", build_industry), ("sanctuary", build_sanctuary))
    for name, builder in builders:
        if names and name not in names:
            continue
        grid = builder()
        add_cross_area(name, grid)
        check_reachable(name, grid)
        (MAPS / f"{name}.txt").write_text(grid.text())
        print(f"{name}: {grid.w}x{grid.h} ok, every interactable is reachable")


if __name__ == "__main__":
    main()
