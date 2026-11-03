# The Last Drop: Gameplay Overhaul Brief

A structured prompt for building the game as a **game first, lesson second**.
Learning stays in the game, but it must never be the reason a moment is fun or
the reason a moment is boring. Every system below is judged by one question:
*would a player who ignores the lessons still want to keep playing?*

## 1. Role and objective

You are the lead gameplay engineer and designer for a 2D top-down action
survival game in Godot 4 (GDScript, 480x270 pixel view, plays in the browser).
Deliver a combat-driven progression loop on top of the existing exploration,
sorting, quiz and puzzle layers. Work in small verified phases, test each,
commit each. Do not rush: there are three weeks.

## 2. Pillars (in priority order)

1. **Feel.** Every action has instant, readable feedback: hit-stop, flashes,
   knockback, shake, sound, floating numbers. Controls respond in under 100 ms.
2. **Clarity.** The player always knows what to do next and where it is.
3. **Growth.** Every few minutes the player gets something: XP, a level, a
   weapon, armor, a quest reward. Power is visible (damage numbers, new sprites,
   stats).
4. **Danger.** Fights are about timing and positioning (telegraphed attacks,
   blocking, parrying), not stat checks alone. Losing costs time, not progress.
5. **Mood.** A darker world so that light means safety and attention.
6. **Meaning.** The environmental theme drives enemies, loot and quests, and the
   lessons ride along with the action.

## 3. Requirements

### 3.1 Atmosphere and visibility
- Darker ambient tint per area; light pools (player lantern, fires, machines)
  noticeably brighter by contrast. The player must stay readable everywhere.
- Never make an area unplayable: the lantern always shows at least a 5-tile pool.

### 3.2 Objective visibility
- The current objective has a pulsing glow in the HUD and flashes when it changes.
- A **beacon** marks the objective's target in the world (bobbing marker) and an
  **edge arrow** points to it when off-screen.
- A short **"NEW OBJECTIVE"** banner appears on change.
- Objectives are data (`data/objectives.json`) with a `target` descriptor.

### 3.3 Combat
- **Sword attack:** short windup, active hit frames, recovery; hits an arc in front.
  Damage from level and weapon. Knockback and hit-stop on hit.
- **Block:** hold to raise the guard; incoming hits from the front are cut by 80%
  and the player moves slower. **Parry:** blocking within ~0.15 s of an enemy's
  strike negates the damage, staggers the enemy, and rewards XP.
- **Invulnerability frames** after being hit; no stun-lock.
- Fists are the fallback so combat is never impossible.
- Input: J / left mouse = attack, K / right mouse = block (hold).

### 3.4 Enemies
- Data-driven (`data/enemies.json`): health, speed, damage, reach, windup,
  cooldown, aggro radius, XP, drops, sprite set.
- Variety with distinct behavior: **walker** (slow, steady), **runner** (fast, low
  health, short windup), **brute** (slow, heavy telegraph, high damage and health).
- Every attack is **telegraphed** (visible windup) so it can be blocked or dodged.
- Enemies chase on sight, give up when far, never attack through walls.
- Spawn from map markers; safe zones around the spawn and key objects; defeated
  enemies stay defeated for the run.
- Enemies theme: waste-world scavengers and infected, never gratuitous gore.

### 3.5 Progression
- **XP and levels** (cap 10). XP from kills, quests, objectives, parries.
  Level up: more max health, more damage, full heal, a clear celebration.
- **Gear:** weapon, head and body slots with tiers and rarity (`data/gear.json`).
  Armor reduces damage by a flat amount (diminishing, never immunity).
  Gear comes from chests, enemy drops and quest rewards.
- **Equipment screen** (I): see owned gear, equip, compare stats.

### 3.4b Quests
- Every quest has a **difficulty** (easy, medium, hard), an **XP reward** and a
  category (combat, gather, sort, learn, explore, puzzle).
- Journal sorts by difficulty, shows XP, progress and completion.
- Variety per area: at least one easy, one medium and one hard quest.
- Harder quests pay more XP and better gear.

### 3.6 HUD
- Level and XP bar, health, water, equipped weapon, damage numbers, quest toasts.
- Keep the screen uncluttered: the world is the star.

### 3.7 Learning integration (secondary, never blocking)
- Lessons arrive after piles as Field Checks; puzzles guard terminals; enemies
  and loot reference the waste theme (hazard-coloured brutes drop hazard loot).
- Quizzes can be skipped without penalty; right answers give a small buff.

## 4. Non-functional requirements
- Plays in the browser at a steady frame rate (budget: 60 fps, <= 12 active enemies).
- All content is data; rules are plain classes with unit tests; scenes present.
- No regression: existing tests stay green; the browser playthrough keeps passing.
- Accessibility: Juicee reduced-motion and shake toggles are honoured.

## 5. Phases and acceptance criteria

| Phase | Deliverable | Done when |
|---|---|---|
| A | Darker mood, brighter light, objective glow, beacon, banner | Screenshot shows lit pools against dark; objective is findable without reading |
| B | Player combat: sword, block, parry, i-frames | Unit tests for hit/block/parry math; feels right in browser |
| C | Enemies: three types, telegraphs, drops, spawn markers | Each type is beatable and distinct; no stuck loops |
| D | Progression: XP, levels, stats | Level up changes max health and damage; tested |
| E | Gear and chests: data, equip, drops, equipment screen | Equipping changes damage and armor; tested |
| F | Quests: difficulty, XP, variety, journal sorting | Journal sorted by difficulty; XP paid once |
| G | Polish and balance pass | Browser playthrough with combat passes; fight lengths feel right |

## 6. Working rules
- One logical change per commit; run `bash scripts/test.sh` and the browser
  playthrough before calling a phase done; report failures honestly.
- Tune numbers in data files, not code. Keep a balance table in `docs/`.
- Placeholder art is fine; the pack's zombies, sprites and the dusk palette are
  the visual baseline.
