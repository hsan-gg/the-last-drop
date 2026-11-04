#!/usr/bin/env python3
"""Builds every room you can walk into and every dungeon under the world:
their maps (data/maps/<id>.txt), scenes (world/<id>.tscn), and their entries in
data/areas.json, plus the doors on the region side. Rooms are carved out of
solid rock: any wall directly above a floor becomes a wall face, so rooms read
the way Stardew Valley's do (a tall back wall, thin side walls).

Each map is checked: every door, chest, puzzle, note, vein and enemy can be
reached from the way in, counting locked gates and cracked walls as passable
(you get the key, you break the wall).

Map characters inside (see tools/assets_interiors.py for the art):
  # wall top   B wall face   . floor   , rug   : tiled floor   = runner/rails
  C counter   F shelf   P table   t bed (stalagmite in caves)   S stove/machine
  H crates (boulder in caves)   b clutter   r debris   M doormat   ~ water   T spill
Entity markers (per area, below): ^ way out  c l chests  + workbench
  ! ? puzzle stations   ; n notes   x cracked wall   | locked gate
  o i k q ore veins (copper, iron, crystal, coal)   Y Q R zombies   L lamp

Run from game/:  python3 tools/build_interiors.py
"""
import json
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
MAPS = ROOT / "data" / "maps"
SCENE = """[gd_scene load_steps=2 format=3]

[ext_resource type="PackedScene" path="res://world/game_area.tscn" id="1"]

[node name="{node}" instance=ExtResource("1")]
area_id = "{id}"
"""
SOLID = set("#BCFPtSH~")
WALKABLE = set(".,:=brMDT")
PASSABLE_MARKERS = set("|x^")


class Plan:
    def __init__(self, width, height):
        self.w, self.h = width, height
        self.cells = [["#"] * width for _ in range(height)]

    def room(self, x0, y0, x1, y1, floor="."):
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.cells[y][x] = floor
        return self

    def put(self, x, y, ch):
        self.cells[y][x] = ch
        return self

    def row(self, x, y, text):
        for i, ch in enumerate(text):
            if ch != " ":
                self.cells[y][x + i] = ch
        return self

    def faces(self):
        """A wall directly above open floor is the wall's face."""
        for y in range(self.h - 1):
            for x in range(self.w):
                below = self.cells[y + 1][x]
                # Furniture stands in front of the wall, so its wall shows a face too.
                if self.cells[y][x] == "#" and below not in ("#", "B"):
                    self.cells[y][x] = "B"
        # Faces need a wall top above them; the map's top row stays wall top.
        for x in range(self.w):
            if self.cells[0][x] == "B":
                self.cells[0][x] = "#"
        return self

    def text(self):
        return "\n".join("".join(row) for row in self.cells) + "\n"


def check(area_id, plan):
    grid = plan.cells
    exits = [(x, y) for y, row in enumerate(grid) for x, ch in enumerate(row) if ch == "^"]
    assert exits, f"{area_id}: no way out"
    start = None
    ex, ey = exits[0]
    for nx, ny in ((ex, ey - 1), (ex, ey + 1), (ex - 1, ey), (ex + 1, ey)):
        if 0 <= ny < plan.h and 0 <= nx < plan.w and grid[ny][nx] in WALKABLE:
            start = (nx, ny)
    assert start, f"{area_id}: the way out opens onto nothing"
    seen = {start}
    queue = deque([start])
    while queue:
        x, y = queue.popleft()
        for nx, ny in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
            if (nx, ny) in seen or not (0 <= ny < plan.h and 0 <= nx < plan.w):
                continue
            ch = grid[ny][nx]
            if ch in WALKABLE or ch in PASSABLE_MARKERS:
                seen.add((nx, ny))
                queue.append((nx, ny))
    for y, row in enumerate(grid):
        for x, ch in enumerate(row):
            if ch in SOLID or ch in WALKABLE or ch == "#":
                continue
            near = ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1))
            assert (x, y) in seen or any(n in seen for n in near), f"{area_id}: '{ch}' at {(x, y)} cannot be reached"


# ------------------------------------------------------------------ entities

def way_out(region, marker, prompt="Step outside"):
    return {"scene": "door", "props": {"target_scene": f"res://world/{region}.tscn", "arrive_marker": marker, "prompt": prompt, "walk_through": True}}


def chest(items=None, gear=None):
    return {"scene": "chest", "props": {"items": items or {}, "gear": gear or []}}


def station(puzzle_id, look, prompt, reward, done_lines, required_flag="", locked_lines=None):
    props = {"puzzle_id": puzzle_id, "look": look, "prompt": prompt, "reward": reward, "done_lines": done_lines, "done_prompt": "Look again"}
    if required_flag:
        props["required_flag"] = required_flag
        props["locked_lines"] = locked_lines or ["Nothing happens."]
    return {"scene": "puzzle_station", "props": props}


def note(note_id, title, lines):
    return {"scene": "note", "props": {"note_id": note_id, "title": title, "lines": lines}}


def cracked(tileset, part="top", hides=None, drops=None):
    props = {"sprite_name": f"cracked_{tileset}_{part}", "hits": 3, "secret": True, "persist": True, "drops": drops or {}, "xp": 20}
    if hides:
        props["hides"] = list(hides)
    return {"scene": "breakable", "props": props}


def vein(kind, item, count=2):
    return {"scene": "breakable", "props": {"sprite_name": f"vein_{kind}", "hits": 3, "needs_item": "pickaxe", "persist": False, "drops": {item: count}, "xp": 3}}


def gate(key_item, text):
    return {"scene": "door", "props": {"key_item": key_item, "locked_text": text, "prompt": "Unlock the gate"}}


def enemy(kind):
    return {"scene": "enemy", "props": {"enemy_id": kind}}


WORKBENCH = {"scene": "workbench"}
LAMP = {"scene": "lamp"}


def area(area_id, plan, tileset, title, subtitle, region, entities, *, kind="interior", tint="#e8d8c0", ambience=("dust",), music=None):
    return {
        "id": area_id, "layout": f"res://data/maps/{area_id}.txt", "floor": ".", "tileset": tileset,
        "kind": kind, "region": region, "title": title, "subtitle": subtitle, "tint": tint, "lit_tint": tint,
        "music": music or region, "ambience": list(ambience), "entities": entities,
    }, plan


# ------------------------------------------------------------------ the rooms

def tobi_house():
    p = Plan(19, 10)
    p.room(1, 2, 11, 8).room(13, 2, 17, 6)
    p.row(1, 2, "FF.SC....;.")
    p.row(1, 4, ".P..,,,..t.")
    p.row(1, 5, "....,,,..t.")
    p.row(1, 6, "+...,,,....")
    p.row(1, 7, ".........!.")
    p.put(6, 8, "M").put(6, 9, "^").put(12, 4, "x").put(15, 3, "c").row(13, 6, "b...b")
    p.faces()
    return area("tobi_house", p, "home", "Old Tobi's House", "it smells of solder and soup", "outpost", {
        "^": way_out("outpost", "0"),
        "+": WORKBENCH,
        ";": note("tobi_diary", "Tobi's diary", [
            "Tobi's handwriting, shaky: 'Things I must not forget.'",
            "'1. Water the beans. 2. The radio needs a valve. 3. Her name was Ines.'",
            "'4. The metro under the yard flooded in the second winter. Something still moves down there.'",
            "'5. I walled up the pantry. If I forget why, it is because I wanted to.'",
        ]),
        "!": station("radio_handshake", "radio", "Tune Tobi's old radio", {"items": {"rune_battery": 1}, "xp": 30}, [
            "A voice through the static: '...anyone on this band, the river is still moving...'",
            "Then nothing. But somebody is out there.",
        ]),
        "x": cracked("home", "top", (13, 1, 17, 6)),
        "c": chest({"energy_bar": 2, "purified_water": 1, "textile_scrap": 2}),
    }, tint="#f0dcc0")


def tool_shed():
    p = Plan(12, 8)
    p.room(1, 2, 10, 6)
    p.row(1, 2, "HH.F..S.HH").row(1, 3, ".........b").row(1, 4, ".!.....;..").row(1, 5, "b.........").row(1, 6, ".H..M...c.")
    p.put(5, 7, "^")
    p.faces()
    return area("tool_shed", p, "shack", "The Tool Shed", "everything here is broken, or about to be", "outpost", {
        "^": way_out("outpost", "&"),
        "!": station("shed_fusebox", "fusebox", "Fix the fuse box", {"items": {"pickaxe": 1}, "xp": 30, "flag": "shed_power"}, [
            "The bulb buzzes on. Behind the workbench hangs a pickaxe.",
            "You take it. Swing it (J) at ore veins to break them.",
        ]),
        ";": note("metro_notice", "a torn notice", [
            "A notice, half torn: 'METRO SERVICE STAFF: the maintenance key is kept in the ticket office safe drawer.'",
            "Someone has scrawled under it: 'not any more. it's in the office desk down there. good luck.'",
        ]),
        "c": chest({"bandage": 2, "copper_wire": 2}),
    }, tint="#e0d0b8")


def metro():
    p = Plan(40, 24)
    p.room(2, 2, 13, 9)                 # ticket hall
    p.room(14, 5, 23, 6)                # corridor east
    p.room(24, 2, 37, 9)                # concourse
    p.room(6, 10, 7, 13)                # stairs down to the platform
    p.room(2, 14, 27, 19)               # west platform and track
    p.room(29, 14, 37, 19)              # east platform, past the collapse
    p.row(2, 17, "=" * 26).row(2, 18, "=" * 26).row(29, 17, "=" * 9).row(29, 18, "=" * 9)
    p.room(30, 10, 30, 13)              # service stairs, behind a gate
    p.row(2, 2, "F.;F.M....F.").row(3, 4, "P.c")
    p.put(7, 1, "^")
    p.put(30, 11, "|")
    p.row(24, 2, "C....!......;.").row(26, 5, "Y......Y").put(35, 8, "L")
    p.row(3, 15, "Y.........Q...........R").put(31, 15, "Y").put(36, 15, "l")
    # The tunnel wall south of the track hides a sealed room.
    p.put(12, 20, "x").room(9, 21, 15, 22)
    p.put(10, 21, "c").put(14, 22, "k")
    # Veins in the tunnel walls.
    p.put(2, 16, "q").put(37, 16, "o").put(20, 14, "o").put(13, 14, "q")
    p.faces()
    return area("metro", p, "metro", "The Old Metro", "the last trains left from here", "outpost", {
        "^": way_out("outpost", "*", "Climb the stairs"),
        ";": note("last_train", "a timetable", [
            "A timetable. Every train after the 14th is crossed out by hand.",
            "Under the last one, in pencil: 'They said the water would be fine by spring.'",
        ]),
        "!": station("metro_lights", "radio", "Wake the signal box", {"items": {"metro_key": 1}, "xp": 40, "flag": "metro_lights_on"}, [
            "Green lamps flicker along the tunnel. A drawer in the signal box springs open:",
            "a blue-tagged key. 'MAINTENANCE ONLY'.",
        ]),
        "|": gate("metro_key", "A service gate. A blue tag on the lock reads: MAINTENANCE KEY."),
        "c": chest({"rune_battery": 2, "coal": 2}, ["tire_vest"]),
        "l": chest({"bandage": 2, "energy_bar": 1}, ["scrap_blade"]),
        "x": cracked("metro", "face", (9, 21, 15, 22)),
        "k": vein("crystal", "crystal_shard", 2),
        "o": vein("copper", "copper_ore", 2),
        "q": vein("coal", "coal", 2),
        "Y": enemy("walker"), "Q": enemy("runner"), "R": enemy("brute"),
        "L": LAMP,
    }, kind="dungeon", tint="#5a6070", ambience=("dust", "mist"))


def halden_office():
    p = Plan(16, 10)
    p.room(1, 2, 14, 8)
    p.row(1, 2, "FF.SS.C..F.FF!").row(1, 4, ".P..:::...P...").row(1, 5, "....:::.......").row(1, 6, "?...:::.....;.")
    p.put(7, 8, "M").put(7, 9, "^").put(13, 7, "c")
    p.faces()
    return area("halden_office", p, "office", "Halden's Office", "within limits", "factory", {
        "^": way_out("factory", "0"),
        "!": station("halden_safe", "safe", "Try the wall safe", {"gear": ["welding_mask"], "items": {"rune_battery": 2}, "xp": 50}, [
            "The safe swings open: a welding mask, two crystal cells,",
            "and a photo of a girl with Halden's eyes. On the back: 'for Asha, 14 July'.",
        ]),
        "?": station("hazmat_pairs", "board", "Study the hazard board", {"items": {"bandage": 2}, "xp": 30}, [
            "You know every symbol on the board now. So would anyone who read it.",
        ]),
        ";": note("halden_memo", "a memo", [
            "MEMO: 'Discharge within limits. Limits revised upward, effective immediately.'",
            "Signed by Halden. Underneath, in his hand: 'I should not have signed this.'",
        ]),
        "c": chest({"chemical_can": 1, "copper_wire": 2}),
    }, tint="#d0d8e0")


def recycling_hall():
    p = Plan(18, 10)
    p.room(1, 2, 16, 8)
    p.row(1, 2, "HH..SSSSSS.....H").row(1, 3, "........!.......").row(1, 5, "b..:::::::::...b").row(1, 6, "?.............;.")
    p.put(8, 8, "M").put(8, 9, "^").put(15, 7, "c")
    p.faces()
    return area("recycling_hall", p, "shack", "The Recycling Hall", "the line still runs, if someone runs it", "dump", {
        "^": way_out("dump", "0"),
        "!": station("dump_line", "conveyor", "Run the sorting line", {"items": {"scrap_metal": 2, "glass_jar": 1}, "xp": 50}, [
            "The line rattles to a stop. Neat piles, each in its bin. Nana Ru would approve.",
        ]),
        "?": station("dump_pairs", "board", "Read the pickers' board", {"items": {"energy_bar": 1}, "xp": 25}, [
            "The pickers' board: what goes where. You could teach it now.",
        ]),
        ";": note("kip_drawing", "a child's drawing", [
            "A crayon drawing: a tall woman with white hair, a boy running, and a big sun.",
            "'NANA RU AND ME AND THE SUN COMING BACK' it says, in letters of every size.",
        ]),
        "c": chest({"tin_can": 2, "plastic_bottle": 2}),
    }, tint="#e0d4c0")


def nana_shack():
    p = Plan(14, 9)
    p.room(1, 2, 8, 7).room(10, 2, 12, 5)
    p.row(1, 2, "F..t...F").row(1, 4, ".P..,,.;").row(1, 5, "....,,..")
    p.put(9, 3, "x").put(11, 3, "c")
    p.put(4, 7, "M").put(4, 8, "^")
    p.faces()
    return area("nana_shack", p, "shack", "Nana Ru's Shack", "everything has a price, and a use", "dump", {
        "^": way_out("dump", "&"),
        ";": note("nana_ledger", "Nana Ru's ledger", [
            "Columns of trades in tiny writing: 'Six bottles: one tin of beans. One battery, sealed: two days of water.'",
            "On the last page: 'Kip's birthday. Find him something that is not rubbish.'",
        ]),
        "x": cracked("shack", "face", (10, 1, 12, 5)),
        "c": chest({"rune_battery": 1, "crystal_shard": 1}, ["hard_hat"]),
    }, tint="#e0c8a8")


def boathouse():
    p = Plan(16, 10)
    p.room(1, 2, 14, 8)
    p.row(1, 2, "FF....~~~~..S.").row(1, 3, "......~~~~....").row(1, 5, ".P..,,,....!..").row(1, 6, "....,,,.....?.").row(1, 7, ";...........c.")
    p.put(7, 8, "M").put(7, 9, "^")
    p.faces()
    return area("boathouse", p, "home", "Osei's Boathouse", "the river remembers everything", "river", {
        "^": way_out("river", "0"),
        ";": note("osei_ledger", "Osei's ledger", [
            "A ferryman's ledger. Fares, weather, who crossed and when.",
            "A note in the margin: 'Halden came by again. Asked me to keep his safe code, in case he forgets:",
            "his girl's birthday, the 14th of July. 1-4-7. Poor man.'",
        ]),
        "!": station("river_pumps", "valves", "Open the pump valves", {"items": {"purified_water": 3}, "xp": 40}, [
            "Water rushes through the filters and out of the tap, clear and cold.",
        ]),
        "?": station("filter_bed", "mixer", "Pack the filter barrel", {"items": {"charcoal": 2, "sand_sack": 1}, "xp": 35}, [
            "Gravel, sand, charcoal, sand. The water that drips out the bottom is clear.",
        ]),
        "c": chest({"glass_jar": 2, "charcoal": 1}),
    }, tint="#c8d8d0")


def farmhouse():
    p = Plan(16, 10)
    p.room(1, 2, 14, 8)
    p.row(1, 2, "FF.SC.....t.F.").row(1, 3, "..........t...").row(1, 4, ".PP..,,,......").row(1, 5, "....,,,...!...").row(1, 6, "?...,,,......;")
    p.put(7, 8, "M").put(7, 9, "^").put(1, 7, "c")
    p.faces()
    return area("farmhouse", p, "home", "Lena's Farmhouse", "the seeds are still in the drawer", "fields", {
        "^": way_out("fields", "0"),
        "!": station("compost_mix", "mixer", "Mix the compost", {"items": {"food_scraps": 2}, "xp": 40, "flag": "compost_mixed"}, [
            "The heap warms in your hands. In a week it will be soil. Jory claps, silently, delighted.",
        ]),
        "?": station("seed_pairs", "board", "Jory's seed chart", {"items": {"energy_bar": 2}, "xp": 30}, [
            "Jory's chart, drawn in pictures because he does not speak:",
            "beans feed the soil, corn climbs the beans, squash shades the weeds.",
        ]),
        ";": note("jory_drawing", "Jory's drawing", [
            "Jory cannot speak, so he draws. This one: the field green, Lena smiling, and you, holding a spade.",
            "It is dated tomorrow.",
        ]),
        "c": chest({"textile_scrap": 2, "food_scraps": 2}),
    }, tint="#f0e0c0")


def barn():
    p = Plan(18, 10)
    p.room(1, 2, 12, 8).room(14, 2, 16, 8)
    p.row(1, 2, "HHH..HH..HHH").row(1, 4, "..b....b....").row(1, 6, "H..!....;..H")
    p.put(13, 5, "|").put(15, 3, "c").put(15, 7, "l")
    p.put(6, 8, "M").put(6, 9, "^")
    p.faces()
    return area("barn", p, "shack", "The Old Barn", "hay, rust and a locked stall", "fields", {
        "^": way_out("fields", "&"),
        "!": station("barn_lock", "safe", "Try the stall padlock", {"items": {"rusty_key": 1}, "xp": 40}, [
            "The padlock clicks. Hanging inside the box: a rusty key on a nail.",
        ]),
        ";": note("barn_sign", "a sign on the stall", [
            "'TOOLS. LOCKED. Code from the plant, ask the robot.' Someone had a sense of humour.",
        ]),
        "|": gate("rusty_key", "The back stall is shut with a heavy lock. It takes an old key."),
        "c": chest({"crystal_shard": 1, "iron_ore": 2}, ["crash_helmet"]),
        "l": chest({"energy_bar": 2, "rune_battery": 1}),
    }, tint="#e8d0a8")


def bunker():
    p = Plan(16, 10)
    p.room(1, 2, 14, 8)
    p.row(1, 2, "SSS..F..F...SS").row(1, 4, ".P.....::.....").row(1, 5, "+......::...!.").row(1, 6, "....;..::.....")
    p.put(7, 8, "M").put(7, 9, "^").put(13, 7, "c")
    p.faces()
    return area("bunker", p, "office", "Vex's Bunker", "the last working lights in the plant", "industry", {
        "^": way_out("industry", "0"),
        "+": WORKBENCH,
        "!": station("unit7_diagnostic", "radio", "Run Unit-7's diagnostic", {"items": {"rune_battery": 1, "coal": 3}, "xp": 45}, [
            "UNIT-7 SELF-TEST: PASSED. 'Thank you. My left wheel has felt wrong for 2,191 days.'",
        ]),
        ";": note("unit7_log", "Unit-7's maintenance log", [
            "UNIT-7 LOG, entry 4,410: Swept floor. Floor clean. Floor will be dirty again tomorrow.",
            "Entry 4,411: Farmer requested barn padlock reset. New code: 2-2-0-8. (Shift change, 22:08.)",
            "Entry 4,412: No one has come. Swept floor.",
        ]),
        "c": chest({"iron_ore": 2, "coal": 2}),
    }, tint="#c8ccd8")


def slag_mine():
    p = Plan(44, 26)
    p.room(18, 18, 25, 23)              # entry gallery
    p.put(21, 23, "M").put(21, 24, "^").put(22, 24, "#")
    p.room(20, 12, 23, 17)              # shaft up
    p.room(4, 4, 39, 11, ".")           # the long gallery
    p.row(4, 8, "=" * 36)
    p.room(4, 12, 9, 22)                # west cut
    p.room(34, 12, 40, 22)              # east cut
    p.room(10, 20, 17, 21).room(26, 20, 33, 21)
    p.room(2, 14, 3, 16)                # niche
    p.row(5, 4, "t....q...i....H...k.....t....o.....")
    p.row(6, 10, "Y....R.......!........Y...R")
    p.put(5, 13, "i").put(8, 15, "o").put(5, 18, "q").put(8, 21, "k").put(5, 21, "c")
    p.put(35, 13, "i").put(39, 15, "k").put(36, 19, "o").put(39, 21, "q").put(38, 12, "Y")
    p.put(10, 20, "Q").put(30, 20, "Q")
    # A seam of crystal behind a cracked wall: the grotto.
    p.put(41, 17, "x").room(42, 15, 42, 19)
    p.put(42, 15, "k").put(42, 19, "l")
    p.put(24, 21, ";").put(19, 19, "L").put(23, 13, "L")
    p.faces()
    return area("slag_mine", p, "cave", "The Slag Mine", "dig, and mind the dark", "industry", {
        "^": way_out("industry", "&", "Climb out"),
        ";": note("miners_rules", "miners' rules", [
            "RULE 1: Mind the dark. RULE 2: Never mine alone. RULE 3: What you dig up, you put to use.",
            "Scratched underneath: 'rule 4: the wall at the far end of the east cut is hollow. don't tell Vex.'",
        ]),
        "!": station("mine_lift", "fusebox", "Restore the lift power", {"items": {"crystal_shard": 2, "iron_ore": 2}, "xp": 60, "flag": "mine_lift_on"}, [
            "The old lift groans and the gallery lamps come up. Ore glints in every wall.",
        ]),
        "c": chest({"coal": 3, "copper_ore": 2}, ["scrap_plate"]),
        "l": chest({"crystal_shard": 3, "rune_battery": 2}, ["recycled_edge"]),
        "x": cracked("cave", "face", (42, 14, 42, 19)),
        "o": vein("copper", "copper_ore", 2), "i": vein("iron", "iron_ore", 2),
        "k": vein("crystal", "crystal_shard", 1), "q": vein("coal", "coal", 2),
        "Y": enemy("walker"), "Q": enemy("runner"), "R": enemy("rust_brute"),
        "L": LAMP,
    }, kind="dungeon", tint="#5a4e48", ambience=("dust", "embers"))


def ines_lab():
    p = Plan(18, 10)
    p.room(1, 2, 16, 8)
    p.row(1, 2, "FF.SS..~~~..SS.F").row(1, 4, "..P........P....").row(1, 5, "....:::::::.....").row(1, 6, "!...:::::::...?.")
    p.put(8, 8, "M").put(8, 9, "^").put(15, 7, ";").put(1, 7, "c")
    p.faces()
    return area("ines_lab", p, "lab", "Ines's Lab", "she left the lights on for you", "sanctuary", {
        "^": way_out("sanctuary", "0"),
        "!": station("ines_vault", "safe", "Open Ines's vault", {"gear": ["solar_saber"], "items": {"crystal_shard": 2}, "xp": 80}, [
            "Inside the vault: a blade that hums with stored sunlight, and a card in Ines's hand:",
            "'For whoever closes the loops. Cut only what needs cutting.'",
        ], "tobi_remembered", ["A vault with a four-digit dial. Ines would have told only one person the code."]),
        "?": station("water_cycle_pairs", "board", "Ines's teaching board", {"items": {"purified_water": 2}, "xp": 35}, [
            "Evaporation, condensation, rain, runoff, the river, the sea. Round and round.",
        ]),
        ";": note("ines_letter", "a letter", [
            "'Tobi. If you are reading this, you came back. I am not angry. I was never angry.'",
            "'The vault code is the day we met. You will remember. You always remembered the important things.'",
        ]),
        "c": chest({"rune_battery": 2, "bandage": 2}),
    }, tint="#e8f0ec")


ROOMS = [tobi_house, tool_shed, metro, halden_office, recycling_hall, nana_shack, boathouse, farmhouse, barn, bunker, slag_mine, ines_lab]

# Region side: marker -> (look, interior, prompt, extra props)
DOORS = {
    "outpost": {"0": ("outpost_house", "tobi_house", "Visit Tobi's house"), "&": ("outpost_shed", "tool_shed", "Open the tool shed"),
                "*": ("metro_stairs", "metro", "Go down to the metro")},
    "factory": {"0": ("factory_office", "halden_office", "Enter Halden's office")},
    "dump": {"0": ("dump_hall", "recycling_hall", "Enter the recycling hall"), "&": ("dump_shack", "nana_shack", "Knock on Nana Ru's shack")},
    "river": {"0": ("river_boathouse", "boathouse", "Enter the boathouse")},
    "fields": {"0": ("fields_farmhouse", "farmhouse", "Enter the farmhouse"), "&": ("fields_barn", "barn", "Open the barn")},
    "industry": {"0": ("industry_bunker", "bunker", "Enter Vex's bunker"), "&": ("mine_mouth", "slag_mine", "Go down the mine")},
    "sanctuary": {"0": ("sanctuary_lab", "ines_lab", "Enter Ines's lab")},
}


def main():
    areas_path = ROOT / "data" / "areas.json"
    areas = json.loads(areas_path.read_text())
    by_id = {entry["id"]: entry for entry in areas}
    for build in ROOMS:
        config, plan = build()
        check(config["id"], plan)
        (MAPS / f"{config['id']}.txt").write_text(plan.text())
        node = "".join(part.capitalize() for part in config["id"].split("_"))
        (ROOT / "world" / f"{config['id']}.tscn").write_text(SCENE.format(node=node, id=config["id"]))
        if config["id"] in by_id:
            areas[areas.index(by_id[config["id"]])] = config
        else:
            areas.append(config)
        by_id[config["id"]] = config
        print(f"{config['id']}: {plan.w}x{plan.h} ok")
    for region, doors in DOORS.items():
        entities = by_id[region]["entities"]
        for marker, (look, interior, prompt) in doors.items():
            entities[marker] = {"scene": "building", "props": {"look": look, "interior": f"res://world/{interior}.tscn", "prompt": prompt}}
    areas_path.write_text(json.dumps(areas, indent="\t", ensure_ascii=False) + "\n")


if __name__ == "__main__":
    main()
