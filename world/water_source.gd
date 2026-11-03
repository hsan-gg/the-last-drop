class_name WaterSource
extends Interactable
## Contaminated water that only becomes drinkable once its treatment is done,
## so fixing one system unlocks another. The flags and dialogue come from
## data/areas.json, so each area can have its own water.

const DIRTY := preload("res://assets/sprites/water_dirty.png")
const CLEAN := preload("res://assets/sprites/water_clean.png")
const DRINK_AMOUNT := 100.0

## Set once the treatment that makes this water safe is done.
@export var clean_flag: String = "treatment_repaired"
@export var tested_flag: String = "water_tested"
@export var secure_flag: String = "water_secure"
@export var contaminated_dialogue: String = "water_contaminated"
@export var needs_treatment_dialogue: String = "water_needs_treatment"
@export var clean_dialogue: String = "water_clean"

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	super()
	interacted.connect(_on_interacted)
	EventBus.flag_changed.connect(_refresh.unbind(2))
	_refresh()


func _on_interacted(_by: Node) -> void:
	if GameState.has_flag(clean_flag):
		_drink()
	elif GameState.has_flag(tested_flag):
		EventBus.dialogue_requested.emit(needs_treatment_dialogue)
	else:
		GameState.set_flag(tested_flag)
		EventBus.dialogue_requested.emit(contaminated_dialogue)


func _drink() -> void:
	Survival.drink(DRINK_AMOUNT)
	EventBus.sfx_requested.emit("drink")
	if not GameState.has_flag(secure_flag):
		GameState.set_flag(secure_flag)
		EventBus.celebrate.emit(global_position)
		EventBus.dialogue_requested.emit(clean_dialogue)


func _refresh() -> void:
	var clean := GameState.has_flag(clean_flag)
	_sprite.texture = CLEAN if clean else DIRTY
	if clean:
		set_prompt("Drink clean water")
	elif GameState.has_flag(tested_flag):
		set_prompt("Check the water again")
	else:
		set_prompt("Inspect the water")
