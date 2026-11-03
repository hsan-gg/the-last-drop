# Balance table

Generated from `data/enemies.json` and `data/gear.json`. A swing takes 0.39s
(windup 0.07, active 0.12, recovery 0.20). Level gives +1 damage per level above 1
and +8 max health per level.

## Hits to defeat an enemy

| Weapon | Damage | Runner (16 hp) | Walker (30 hp) | Brute (80 hp) |
|---|---|---|---|---|
| Bare Fists (lv 1) | 3 | 6 hits (2.3s) | 10 hits (3.9s) | 27 hits (10.5s) |
| Rusty Sword (lv 1) | 8 | 2 hits (0.8s) | 4 hits (1.6s) | 10 hits (3.9s) |
| Scrap Blade (lv 3) | 14 | 2 hits (0.8s) | 3 hits (1.2s) | 6 hits (2.3s) |
| Recycled Edge (lv 6) | 22 | 1 hits (0.4s) | 2 hits (0.8s) | 4 hits (1.6s) |
| Solar Saber (lv 10) | 33 | 1 hits (0.4s) | 1 hits (0.4s) | 3 hits (1.2s) |

## Damage taken per strike (unblocked / blocked)

Armor lets `40/(40+DEF)` of the damage through; a block cuts that by 80%; a
parry takes none and stuns the enemy for 1.3s.

| Armor | Through | Runner (6) | Walker (10) | Brute (22) |
|---|---|---|---|---|
| none (DEF 0) | 100% | 6 / 1 | 10 / 2 | 22 / 4 |
| Hard Hat + Cloth Wrap (DEF 4) | 91% | 5 / 1 | 9 / 2 | 20 / 4 |
| Welding Mask + Tire Vest (DEF 10) | 80% | 5 / 1 | 8 / 2 | 18 / 4 |
| Crash Helmet + Riot Jacket (DEF 19) | 68% | 4 / 1 | 7 / 1 | 15 / 3 |

## Enemy tempo

| Enemy | Speed | Windup (warning) | Cooldown | Aggro | XP |
|---|---|---|---|---|---|
| Scavenger Zombie | 30 | 0.55s | 1.1s | 96px | 12 |
| Starved Runner | 56 | 0.3s | 0.8s | 120px | 8 |
| Toxic Brute | 22 | 0.95s | 1.7s | 88px | 40 |

## Design intent

- A level-1 player with a Rusty Sword beats a walker in 4 hits (about 1.6 s) and
  takes at most one hit if they back off during its 0.55 s windup.
- A brute (windup 0.95 s, 22 damage) is a pattern fight: wait for the windup,
  block or parry, then punish. Unblocked it takes a quarter of a 100 health bar.
- Armor is steady, not decisive: even the best set still lets 68% of damage
  through, so blocking and timing always matter more than gear.
- Levels 1 to 10 are reached with roughly 1,600 XP from kills, objectives and
  quests (see `ProgressionRules`).
