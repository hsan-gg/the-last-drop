#!/usr/bin/env python3
"""Stamps the walk-in buildings into the region maps (data/maps/<region>.txt).

A building covers its sprite's footprint with '%' (solid ground the building
stands on) and puts its marker on the door cell, bottom centre. For each one
this searches outward from a preferred door position for clear open ground
(no paths, walls, markers or water, and a clear step in front of the door, well
away from the spawn and the gates), then checks the door can be walked to from
the spawn. Idempotent: a building whose marker is already on the map is left.

Run from game/ after tools/assets_buildings.py.
"""
import sys
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MAPS = ROOT / "data" / "maps"
sys.path.insert(0, str(Path(__file__).resolve().parent))
from assets_buildings import LOOKS  # noqa: E402

OPEN = set(".,rbMD:")
# Small things a building may be built over (a dead tree, a crate; in the
# Fields, a dead crop row). Roads elsewhere are never built on.
CLEARABLE = set("tC")
CLEARABLE_IN = {"fields": set("tC=")}
# Where metal floor is the inside of a walled hall, nothing is built on it.
OPEN_IN = {"industry": set(".,rbD:"), "sanctuary": set(".,rbD:")}
SOLID = set("#~CFPtBSH%")

# region -> [(marker, look, preferred door (x, y))]
BUILDINGS = {
    "outpost": [("0", "outpost_house", (31, 23)), ("&", "outpost_shed", (6, 11)), ("*", "metro_stairs", (35, 5))],
    "factory": [("0", "factory_office", (11, 20))],
    "dump": [("0", "dump_hall", (38, 25)), ("&", "dump_shack", (5, 12))],
    "river": [("0", "river_boathouse", (40, 22))],
    "fields": [("0", "fields_farmhouse", (13, 15)), ("&", "fields_barn", (36, 27))],
    "industry": [("0", "industry_bunker", (40, 28)), ("&", "mine_mouth", (40, 27))],
    "sanctuary": [("0", "sanctuary_lab", (8, 26))],
}


def load(name):
    return [list(row) for row in (MAPS / f"{name}.txt").read_text().splitlines() if row]


def save(name, grid):
    (MAPS / f"{name}.txt").write_text("\n".join("".join(row) for row in grid) + "\n")


def find(grid, ch):
    return [(x, y) for y, row in enumerate(grid) for x, c in enumerate(row) if c == ch]


def span(look):
    w, h = LOOKS[look]["tiles"]
    left = -(w // 2) + (1 if w % 2 == 0 else 0)
    return range(left, left + w), range(-h + 1, 1)


def fits(grid, look, door, keep_away, clearable=CLEARABLE, open_ground=OPEN):
    xs, ys = span(look)
    x0, y0 = door
    height, width = len(grid), len(grid[0])
    for dy in list(ys) + [1, 2]:
        for dx in range(xs.start - 1, xs.stop + 1):
            x, y = x0 + dx, y0 + dy
            if not (1 <= x < width - 1 and 1 <= y < height - 1):
                return False
            inside = dx in xs and dy <= 0
            front = dy >= 1 and abs(dx) <= 1
            if inside and grid[y][x] not in open_ground and grid[y][x] not in clearable:
                return False
            if front and grid[y][x] not in open_ground:
                return False
    return all(abs(x0 - kx) + abs(y0 - ky) > 6 for kx, ky in keep_away)


def stamp(grid, look, door, marker):
    xs, ys = span(look)
    for dy in ys:
        for dx in xs:
            grid[door[1] + dy][door[0] + dx] = "%"
    grid[door[1]][door[0]] = marker


def reachable(grid, start):
    seen = {start}
    queue = deque([start])
    while queue:
        x, y = queue.popleft()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if (nx, ny) in seen or not (0 <= ny < len(grid) and 0 <= nx < len(grid[ny])):
                continue
            if grid[ny][nx] in OPEN or grid[ny][nx] in "=@T":
                seen.add((nx, ny))
                queue.append((nx, ny))
    return seen


def keeps_everything_reachable(grid, look, door, marker):
    """A building must not wall off anything: every marker on the map still
    needs an open neighbour you can walk to from the spawn."""
    trial = [row[:] for row in grid]
    stamp(trial, look, door, marker)
    walkable = reachable(trial, find(trial, "@")[0])
    for y, row in enumerate(trial):
        for x, ch in enumerate(row):
            if ch in OPEN or ch in SOLID or ch in "=@~T":
                continue
            if not any(n in walkable for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))):
                return False
    return True


def place(name):
    grid = load(name)
    keep_away = find(grid, "@") + find(grid, "^") + find(grid, "J") + find(grid, "G")
    for marker, look, preferred in BUILDINGS.get(name, []):
        if find(grid, marker):
            continue
        spot = None
        for radius in range(0, 30):
            for dy in range(-radius, radius + 1):
                for dx in range(-radius, radius + 1):
                    if max(abs(dx), abs(dy)) != radius:
                        continue
                    candidate = (preferred[0] + dx, preferred[1] + dy)
                    if fits(grid, look, candidate, keep_away, CLEARABLE_IN.get(name, CLEARABLE), OPEN_IN.get(name, OPEN)) and keeps_everything_reachable(grid, look, candidate, marker):
                        spot = candidate
                        break
                if spot:
                    break
            if spot:
                break
        if spot is None:
            raise SystemExit(f"{name}: no room for {look}")
        stamp(grid, look, spot, marker)
        print(f"{name}: {look} door at {spot}")
    spawn = find(grid, "@")[0]
    walkable = reachable(grid, spawn)
    for marker, look, _ in BUILDINGS.get(name, []):
        x, y = find(grid, marker)[0]
        if (x, y + 1) not in walkable:
            raise SystemExit(f"{name}: the door of {look} cannot be reached")
    save(name, grid)


def main():
    for name in BUILDINGS:
        place(name)


if __name__ == "__main__":
    main()
