# The Last Drop

A survival adventure in a world buried by its own waste. You learn environmental
responsibility because you need it to survive: sort waste, recover materials,
repair water treatment, and uncover why the world collapsed.

Godot 4.7 (GL Compatibility renderer), 2D, 480x270 pixel viewport, integer-scaled.
Plays in the browser.

## Play

Open `game/` in Godot and press F5, or run the web build (see Export).

| Key | Action |
|---|---|
| WASD / arrows | Move |
| E / Space | Interact, continue dialogue |
| 1 / 2 / 3 / 4 or click | Choose a bin while sorting (4 is compost, shown only when a pile has organic waste) |
| Q | Journal: main goal and side quests |
| Esc | Leave a puzzle |
| M | Mute |

## The loop

1. **Outpost:** inspect the contaminated water, sort the scrap pile (wrong bins
   teach a lesson and cost health), repair the water treatment unit with what
   you recovered, drink clean water, find the recording, open the north gate.
2. **Battery factory:** sort hazardous waste safely, restore the generator,
   read the archive. It reveals the truth about the collapse.
3. **The Great Dump:** sort three heaps (with a compost bin), rebuild the shelter roof from
   recovered cardboard, cloth and metal, find recording 2 and read the municipal records.
4. **The Dead River:** test the water at three points, sort two heaps, install a filter from cloth, charcoal, sand and pipe, and set the treatment chain at the console. Then drink clean water and find the recording.
5. **Ending:** preserve the knowledge or share it. The epilogue reflects how
   carefully you sorted. The ending triggers at the last chapter marked `built` in
   `data/chapters.json`, so it moves on as chapters are added.

## Fun layer

- **Field Check quizzes:** after each sorted pile, one multiple-choice question about what you just handled (`data/quizzes.json`). A right answer restores water; a wrong one only teaches.
- **Side quests:** `data/quests.json`, shown in the journal (Q). Progress comes from counters and flags, so a quest is data; finishing one pays out water or health.
- **Terminal puzzles:** ordering puzzles (`data/puzzles.json`) guard the archive terminals: the safe route for hazardous waste, and the waste hierarchy.
- **Hidden finds:** pickups lying around the dump, tracked by the Scavenger quest.

## Project layout

| Folder | Contents |
|---|---|
| `autoload/` | `EventBus` (signals), `ItemDB`, `Content` (lessons, dialogue, repairs, objectives, areas), `Chapters` (campaign order, ending trigger), `GameState` (flags, counters), `Inventory`, `Survival`, `SceneManager`, `AudioManager`, `Polish` (vignette, hurt feedback), `Juicee` (game-feel addon) |
| `systems/` | Pure logic, no scene dependencies: `SortingRules`, `SortingSession`, `RepairRules`, `ObjectivesTracker`, `EndingRules`, `QuizRules`, `OrderPuzzle`, `QuestRules`, `DataLoader` |
| `world/` | `GameArea` (builds a level from data), `MapBuilder`, and the interactable objects |
| `interaction/` | `Interactable` and `Interactor` |
| `player/` | Player, sprite animation |
| `ui/` | HUD, dialogue box, sorting minigame, title, ending, theme |
| `data/` | All content as JSON, plus ASCII maps in `data/maps/` |
| `assets/` | Generated placeholder art and audio (see below) |
| `test/` | `unit/`, `integration/` (GUT) and `e2e/` (browser) |
| `tools/` | Generators for art, audio and maps |

## Conventions

- Systems talk through `EventBus` signals, not node references.
- Shared state is replaced, never mutated in place (`GameState`, `Inventory`).
- Content lives in `data/`, not in scripts. Tests check that every reference resolves.
- Rules that decide outcomes live in `systems/` as plain classes so they are unit-testable; scenes only present them.
- Interactables use physics layer 2. World collision uses layer 1.

## Adding content

- **A new item:** add it to `data/items.json` (category: `hazardous`, `recyclable`, `reusable` or `general`) and a lesson to `data/lessons.json`. Drop an icon at `assets/sprites/items/<id>.png`.
- **A new repair:** add it to `data/repairs.json`; place its marker in a map and config entry. Never require hazardous items (a test enforces this).
- **A new area:** write `data/maps/<name>.txt`, add an entry to `data/areas.json`, and add a scene that inherits `world/game_area.tscn` with `area_id` set. Map legend is in `tools/generate_maps.py`.
- **Dialogue:** `data/dialogue.json`; show it with `EventBus.dialogue_requested.emit("<id>")`.

## Tests

```bash
bash scripts/test.sh     # GUT unit + integration, headless
bash scripts/e2e.sh      # exports the web build and smoke-tests it in Chromium
bash scripts/playthrough.sh   # plays all four areas to the ending in a real browser
```

`bash scripts/test.sh` also fails if any script fails to compile, which GUT alone only warns about.
The unit and integration suites cover the rules, the data, the maps (including a reachability check from spawn to every interactable), collision, and a full scripted playthrough of both areas.

The e2e script needs `npm install` once in `test/e2e`, a Chromium (set `CHROMIUM_PATH` if not at `/usr/bin/chromium`), and the Godot web export templates.

## Export (web)

Install export templates (Editor > Manage Export Templates), then:

```bash
godot --headless --export-release "Web" export/web/index.html
python3 -m http.server --directory export/web 8000
```

The preset uses the single-threaded web build, so any static host works without
special headers (itch.io, GitHub Pages, Vercel, Cloudflare Pages). The engine is
about 40 MB raw and about 10 MB compressed, so enable compression on the host.
The first load takes a few seconds.

`.txt` map files are listed in the preset's include filter. If you add another
non-resource file type that the game loads at runtime, add it there too, or it
will work in the editor and be missing in the exported build.

## Art and audio

World art (tileset, player, scrap pile) comes from a third-party pack in `art_src/`, which is
not in git (see `CREDITS.md` for the licence). `python3 tools/generate_assets.py` builds the
generated placeholders and then applies the pack art on top when `art_src/` exists.
Items, bins, machines and UI are still generated placeholders.


Everything in `assets/` is generated by `tools/generate_assets.py` and
`tools/generate_audio.sh` so the game is complete without external files.
Replace any file with real art or audio of the same size and name and the game
uses it unchanged. See `CREDITS.md` for the font licence.

## Known limits

- There is no save/load; a run is a single sitting of about 10 to 15 minutes.
- Four areas are playable (outpost, battery factory, Great Dump, Dead River). The fields, industry and sanctuary chapters have script data in `data/` but no maps or mechanics yet (see `docs/GAME_SCRIPT.md`).
- Keyboard-first. Mouse works in menus and the sorting minigame; there is no touch layout.
