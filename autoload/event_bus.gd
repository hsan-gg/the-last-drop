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
signal sorting_requested(pile_id: String, item_ids: Array[String])
signal sorting_finished(pile_id: String)

signal survival_changed(water: float, health: float)
signal damage_taken(amount: float)
signal player_collapsed

## Ask the area to play a sparkle burst at a world position.
signal celebrate(world_position: Vector2)

## Name of a sound in assets/audio/sfx/ (without extension).
signal sfx_requested(sfx_name: String)
