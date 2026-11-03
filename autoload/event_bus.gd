extends Node
## Global signal hub. Systems talk through these signals instead of holding
## references to each other, so scenes stay decoupled.

## Text to show for the nearest interactable; empty string hides the prompt.
signal prompt_changed(text: String)
signal interacted(interactable: Node)
signal inventory_changed
signal flag_changed(key: String, value: Variant)

signal dialogue_requested(dialogue_id: String)
## Ad-hoc text (e.g. "the unit needs: ..."); reported back with an empty id.
signal text_requested(lines: Array[String])
signal dialogue_finished(dialogue_id: String)
## A conversation opened (it holds notices until it ends).
signal dialogue_opened
signal sorting_requested(pile_id: String, item_ids: Array[String])
signal sorting_finished(pile_id: String)

signal survival_changed(water: float, health: float)
signal damage_taken(amount: float)
signal player_collapsed

## Ask the area to play a sparkle burst at a world position.
signal celebrate(world_position: Vector2)

## Name of a sound in assets/audio/sfx/ (without extension).
signal sfx_requested(sfx_name: String)

signal counter_changed(key: String, value: int)

## Open a Field Check quiz drawn from the lessons just learned.
signal quiz_requested(lesson_ids: Array)
signal quiz_finished(correct: bool)

## Open an ordering puzzle from data/puzzles.json.
signal puzzle_requested(puzzle_id: String)
signal puzzle_finished(puzzle_id: String, solved: bool)

signal quest_completed(quest_id: String)

signal xp_changed(level: int, xp: int, needed: int)
signal level_up(level: int)
signal gear_changed
## A line for the loot toast: "Found: Rusty Sword".
signal loot_found(text: String)
signal enemy_killed(enemy_id: String)
signal player_hit(outcome: String, damage: int)

signal lives_changed(lives: int)
signal life_lost(lives_left: int)
signal game_over
## The player was hit while a conversation was open, so it was cut short.
signal dialogue_interrupted
## A short headline on the screen: (title, text, colour).
signal banner_requested(title: String, text: String, color: Color)
