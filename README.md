# The Last Drop

A survival adventure in a world buried by its own waste. You learn environmental
responsibility because you need it to survive: sort waste, recover materials,
repair water treatment, and uncover why the world collapsed.

Godot 4.7 (GL Compatibility renderer), 2D, 480x270 pixel viewport, integer-scaled.
Plays in the browser on desktop and on phones and tablets (touch controls,
installable as an app, plays offline once loaded).

## Play

Open `game/` in Godot and press F5, or run the web build (see Export).

| Key | Action |
|---|---|
| WASD / arrows | Move |
| E / Space | Interact, continue dialogue |
| J / left click | Sword attack |
| K / right click (hold) | Block; raise it just as a strike lands to parry. Block straight out of a swing once the blow lands (pressed earlier, it waits for that moment). A quick guard is ready again at once; one held until the arm tires (about 1.6 s) needs 1.2 s |
| H / G | Use a bandage / drink purified water |
| 1 / 2 / 3 | Use the rune in that slot (Ember: hold to breathe fire; Scatter: the shotgun, two shells then a 1.1 s reload from the shells you carry, which are rare (a few chests and 5-30% drops from the Spoiled once you own it); Tide) |
| T | Show or hide the task tracker |
| Esc | Menu: Items, Quests, Codex, Map, Options, Keys |
| I / Q / M | Open the menu on Inventory / Quests / Map |
| Tab or PgDn (in the menu) | Next page |
| 1 / 2 / 3 / 4 or click (while sorting) | Choose a bin (4 is compost); Esc leaves the pile for later |
| E at a door | Go into a building; walk onto the doormat to go back out |
| J at an ore vein or a cracked wall | Mine it (ore needs the pickaxe) or break through to a hidden room |
| Arrows + E (in a hands-on puzzle) | Move, turn, flip, set a dial; 1-4 on the sorting line; Esc steps away |

Every key except the menu and fixed shortcuts can be rebound in Menu > Controls.

### On a phone or tablet

Hold the phone sideways (the page asks you to turn it in portrait). The first
tap goes fullscreen on Android; on an iPhone use Share > Add to Home Screen,
which opens the game fullscreen like an app.

| Touch | Action |
|---|---|
| Drag on the left half | Walk (a stick appears under your thumb; push further to go faster) |
| Sword (big button, right) | Attack |
| Shield (hold) | Guard and parry; tap the sword while guarding to strike at once |
| USE (glows when there is something to use) | Interact, talk, go through doors |
| Rune buttons (appear when you carry runes) | Runes 1-3 (hold for Ember) |
| Red cross / blue drop | Bandage / water |
| Map and menu (top right), "tasks" | Map, the menu, the task list |
| OK / BACK, arrows, numbers | Over menus, puzzles and conversations; boards also take taps directly |

Several fingers work at once (walk, guard and swing together). Menu > Options >
Touch screen sets the controls to Auto (they appear on the first touch and hide
when a keyboard is used), On or Off, plus button size, opacity, a left-handed
layout and vibration. Display > Battery saver caps the game at 30 fps.

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

## Menus, story and lives

- **Three lives:** collapsing costs one and returns you to the area start; with none left the run restarts after a game over screen.
- **Story cutscenes:** an opening overview of the regions, a short scene at each gate, and a finale. Esc skips.
- **Dialogue does not pause the world.** Zombies still come; being hit or walking away ends a conversation.
- **Esc leaves a scrap pile** part-way; what you recovered is kept and the rest waits on the pile.
- **A wrong Field Check costs 12 health** and draws a zombie, so the quiz matters.
- **Inventory board:** your character, worn weapon, head and body gear, and a backpack grid with consumables and materials.
- **Map with fog of war;** quests as cards sorted by difficulty; options for audio, display, gameplay and accessibility (saved).
- **Objective tracker:** hidden until you press T. It slides in with OBJECTIVE COMPLETE and NEW OBJECTIVE banners. The objective pointer is subtle (Options > Objective hints: Off, Subtle, Strong).

## The world

Seven regions, each its own world with its own tileset, light, weather, music,
monsters and people: the Forgotten Outpost, the Battery Factory, the Great Dump,
the Dead River, the Silent Fields, the Forgotten Industry and the Last Sanctuary.
The story is written up in `docs/STORY.md` (kept up to date with every change).

Houses are shaded to look three-dimensional (light from the upper left, a hipped roof, a ground shadow) and only their wall is solid: walk round behind one and its roof fades. A banner at the top warns when you are thirsty (only once your water is gone and you are slowed) or out of breath (no stamina).

- **People:** eleven characters (`data/npcs.json`) with conversations that follow
  the story; a gold "!" means they have something new to say.
- **Runes (keys 1, 2, 3):** Ember (flamethrower; the Spoiled catch fire and it
  spreads), Scatter (shotgun with knockback) and Tide (heals and pushes back),
  powered by energy that refills over time and with kills.
- **Monsters:** walkers, runners and brutes, then Blight Husks (spore clouds),
  Smog Wraiths (fade in the smog), Rust Brutes (fire melts their armour), the
  Slag Golem boss, and Moss Sentinels.
- **A living world:** flowing water, swaying grass, bubbling toxins, drifting
  ash, spores, smog, fireflies and a haze of pollution, different in each region.
- **Rail carts:** once a region's lights are on, its cart runs to any other lit region.

## Difficulty

Chosen on the title screen (Easy, **Medium** default, Hard, Hardcore) and fixed for the run
(`data/difficulties.json`). Each level scales zombie health, damage, speed and pack size, the
penalty for mistakes, lives, XP and thirst. Hardcore is built to be close to unwinnable:
one life, packs of fast zombies that hit very hard, a tiny parry window and fierce thirst.

## Combat and progression

- **Stamina:** swings and the guard spend it (yellow bar); a parry refunds some. Hold the guard too long, or take a blow too heavy for it, and it breaks: no guard for a couple of seconds.
- **Gear is visible:** helmet, armour and sword show on the character as you equip them.
- **Gates and errands:** an onward gate opens only once its story step is done and the region's generator is lit. Later areas have a gate back, which drops you at the onward gate of the old area. Three errands need a part from one area delivered to another (a radio valve, a seed tin, a filter cartridge).
- **Map:** a parchment chart in two pages: the area (inked, with fog of war and icons) and the world (the road north, lit regions, errands). Left/Right switches.
- **One bad moment costs one life:** after a collapse there is a 2 s grace, and any open sorting, quiz or puzzle closes.
- **Generators and lamps:** each region ends with a generator. Defeat every zombie, start it, and the whole region lights up, with an XP reward and a full heal.
- **Toxic puddles** hurt when you stand in them.

- **Zombies** (walker, runner, brute) chase on sight and telegraph every strike with a visible windup. Block it, parry it for a stun, or dodge it.
- **XP and levels (1 to 10):** from kills, objectives, quests and parries. A level raises max health and damage and heals you.
- **Gear:** weapon, head and body pieces from chests, drops and hard quests (`data/gear.json`); armor trims damage but never makes you immune.
- **Quests** are tiered easy, medium and hard with XP (and gear for the hard ones). Numbers are in `docs/BALANCE.md`.
- **Darker world:** light pools mean safety and attention. A pulsing objective, a beacon over its target and an edge arrow keep the next step obvious.

## Fun layer

- **Randomised piles:** what a scrap pile holds changes every run (the materials a repair needs are always in it, plus at least one hazard). Wrong bins hurt, and two in a row draw a zombie; a streak of right ones pays bonus XP.
- **Codex:** a field guide that fills in as you meet each lesson, with quests for discovering them.
- **Tips:** short, rebinding-aware hints teach moving, interacting, the inventory, attacking, blocking and stamina the first time they matter (Options > Show tips).
- **Cutscenes:** animated pixel postcards acted by the game's own sprites, with a drifting camera, page-wipe transitions and a title slam. Each beat waits for E; Esc skips.
- **Notifications:** one at a time and in order (what you finished, the XP, a level up on its own calm card, then what is next). Stardew-style messages slide in at the bottom-left with an icon and a soft chime (objectives, quests, loot, a running XP total). Level ups and restored regions get a calm card. Nothing appears while you talk; the task list never pops open, the T chip shows a quiet "!" instead.
- **Music:** composed by `tools/generate_music.py`: modelled harp, guitar, piano, e-piano, flute, strings, accordion and percussion, real chord progressions, motif-based melodies and a convolution reverb. One track per area, plus title, story, finale, combat and game over.
- **Field Check quizzes:** after each sorted pile, one multiple-choice question about what you just handled (`data/quizzes.json`). A right answer restores water; a wrong one only teaches.
- **Side quests:** `data/quests.json`, shown in the journal (Q). Progress comes from counters and flags, so a quest is data; finishing one pays out water or health.
- **Terminal puzzles:** ordering puzzles (`data/puzzles.json`) guard the archive terminals: the safe route for hazardous waste, and the waste hierarchy.
- **Hands-on puzzles (seven kinds):** wire and pipe circuits to reconnect, combination locks whose codes are written down in other regions, memory boards, balance mixes (a compost heap, a water filter), a sorting conveyor racing the shredder, and signal patterns to repeat. They run in the world: time keeps going, your health is on the panel, and a zombie's blow knocks you away.
- **Buildings, rooms and dungeons:** every region has buildings in its own style (brick cottages, scrap shacks, a stilt boathouse, a farmhouse and barn, a concrete bunker, a white stone lab) that you walk into, Stardew-style. Two dungeons, the old metro under the Outpost and the Slag Mine, have locked gates, keys and hidden rooms behind cracked walls.
- **Mining and the workbench:** the pickaxe (from the tool shed's fuse box) breaks copper, iron, crystal and coal veins, which grow back each visit. Workbenches in Tobi's house and Vex's bunker turn ore and salvage into water filters, bandages, rune batteries and gear up to the Solar Saber (`data/recipes.json`).
- **Requests across regions:** Halden wants copper, Nana Ru crystal for Kip, Lena clean water, Vex coal; codes for Halden's safe, the barn and Ines's vault are found in other regions.
- **Hidden finds:** pickups lying around the dump, tracked by the Scavenger quest.

## Project layout

| Folder | Contents |
|---|---|
| `autoload/` | `EventBus` (signals), `ItemDB`, `Content` (lessons, dialogue, repairs, objectives, areas), `Chapters` (campaign order, ending trigger), `GameState` (flags, counters), `Inventory`, `Survival`, `SceneManager`, `AudioManager`, `Polish` (vignette, hurt feedback), `TouchControls` (on-screen stick and buttons), `WebPlatform` (save and pause when the tab or app is put away, PWA updates), `Juicee` (game-feel addon) |
| `systems/` | Pure logic, no scene dependencies: `SortingRules`, `SortingSession`, `RepairRules`, `ObjectivesTracker`, `EndingRules`, `QuizRules`, `OrderPuzzle`, `QuestRules`, `DataLoader`, `CircuitBoard`, `MemoryBoard`, `SignalSequence`, `MixRules`, `RecipeBook`, `TouchStick` |
| `world/` | `GameArea` (builds a level from data), `MapBuilder`, and the interactable objects |
| `interaction/` | `Interactable` and `Interactor` |
| `player/` | Player, sprite animation |
| `ui/` | HUD, dialogue box, sorting minigame, title, ending, theme, `touch/` (the drawn touch pad) |
| `data/` | All content as JSON, plus ASCII maps in `data/maps/` |
| `assets/` | Generated placeholder art and audio (see below) |
| `test/` | `unit/`, `integration/` (GUT) and `e2e/` (browser) |
| `tools/` | Generators for art, audio, maps and app icons |
| `web/` | The page around the web build (`shell.html`) |
| `deploy/` | Host settings copied into the build (`_headers`, `vercel.json`); see `docs/DEPLOY.md` |
| `scripts/` | Tests, `build_web.sh`, `build_android.sh` |

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
- **A building and its room:** add a look to `LOOKS` in `tools/assets_buildings.py`, its marker to `BUILDINGS` in `tools/place_buildings.py`, and the room to `tools/build_interiors.py` (its map, notes, puzzles and the door back). Then run, from `game/`: `python3 tools/assets_buildings.py && python3 tools/place_buildings.py && python3 tools/build_interiors.py`. The builders check that every door, chest and puzzle can be reached.
- **A hands-on puzzle:** add it to `data/puzzles.json` with a `type` (`circuit`, `lock`, `memory`, `mix`, `conveyor`, `signal`) and put a `puzzle_station` on a map.

## Tests

```bash
bash scripts/test.sh     # GUT unit + integration, headless
bash scripts/e2e.sh      # exports the web build and smoke-tests it in Chromium
bash scripts/playthrough.sh   # plays all four areas to the ending in a real browser
bash scripts/playthrough.sh combat.mjs   # fights with real key presses
bash scripts/playthrough.sh rooms.mjs    # walks into buildings and down into the metro
bash scripts/playthrough.sh mobile.mjs   # an emulated phone, touch only: stick, buttons, menus, portrait
```

`bash scripts/test.sh` also fails if any script fails to compile, which GUT alone only warns about.
The unit and integration suites cover the rules, the data, the maps (including a reachability check from spawn to every interactable), collision, and a full scripted playthrough of both areas.

The e2e script needs `npm install` once in `test/e2e`, a Chromium (set `CHROMIUM_PATH` if not at `/usr/bin/chromium`), and the Godot web export templates.

## Export and deploy (web)

Install export templates (Editor > Manage Export Templates), then:

```bash
bash scripts/build_web.sh                      # -> build/web/ and build/the-last-drop-web.zip
python3 -m http.server --directory build/web 8000
```

The preset uses the single-threaded web build, so any static host works without
special headers (itch.io, GitHub Pages, Vercel, Netlify, Cloudflare Pages). It
uses a custom page (`web/shell.html`: loader, rotate screen, fullscreen, wake
lock) and is a PWA (home-screen icons from `tools/assets_app_icons.py`, offline
play). The engine is about 40 MB raw and about 10 MB compressed, so enable
compression on the host. `docs/DEPLOY.md` has step-by-step instructions for
each host, and `.github/workflows/web.yml` tests, builds and publishes to
GitHub Pages on every push to main.

`.txt` map files are listed in the preset's include filter. If you add another
non-resource file type that the game loads at runtime, add it there too, or it
will work in the editor and be missing in the exported build.

## Art and audio

World art (tileset, player, scrap pile) comes from a third-party pack in `art_src/`, which is
not in git (see `CREDITS.md` for the licence). `python3 tools/generate_assets.py` builds the
generated placeholders and then applies the pack art on top when `art_src/` exists.
Items, bins, machines and UI are still generated placeholders.


Sound effects come from CC0 packs (see `CREDITS.md`) through `tools/import_sfx.sh`,
which trims them, takes one channel (some packs' stereo cancels out in mono) and
levels each to a loudness target for its role: buttons and actions clear,
feedback present, footsteps underneath. Sounds heard often (swings, zombie
voices, hurt cries) come in several takes with a little pitch wobble, and zombie
sounds fade with distance (`AudioManager.play_at`). Zombies groan as they roam,
snarl when they spot you and rasp as they wind up a swing: the cue to guard.

Everything else in `assets/` is generated by `tools/generate_assets.py` and
`tools/generate_audio.sh` so the game is complete without external files.
Replace any file with real art or audio of the same size and name and the game
uses it unchanged. See `CREDITS.md` for the font licence.

## Known limits

- One save slot (the game saves on entering an area, when a region is lit, and every minute).
- Sound effects come from CC0 packs (see `CREDITS.md`); the music is generated.
- Touch was tested in an emulated phone (Chromium with touch input), not on real devices; check the button sizes on your own phone.
- iPhones cannot go fullscreen from a web page or lock the orientation; Add to Home Screen gives the fullscreen app.
