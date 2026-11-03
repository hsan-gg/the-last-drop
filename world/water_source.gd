class_name WaterSource
extends Interactable
## Contaminated water that only becomes drinkable once the treatment unit is
## repaired, so fixing one system unlocks another.

const DIRTY := preload("res://assets/sprites/water_dirty.png")
const CLEAN := preload("res://assets/sprites/water_clean.png")
const DRINK_AMOUNT := 100.0

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	super()
	interacted.connect(_on_interacted)
	EventBus.flag_changed.connect(_refresh.unbind(2))
	_refresh()


func _on_interacted(_by: Node) -> void:
	if GameState.has_flag("treatment_repaired"):
		_drink()
	elif GameState.has_flag("water_tested"):
		EventBus.dialogue_requested.emit("water_needs_treatment")
	else:
		GameState.set_flag("water_tested")
		EventBus.dialogue_requested.emit("water_contaminated")


func _drink() -> void:
	Survival.drink(DRINK_AMOUNT)
	EventBus.sfx_requested.emit("drink")
	if not GameState.has_flag("water_secure"):
		GameState.set_flag("water_secure")
		EventBus.celebrate.emit(global_position)
		EventBus.dialogue_requested.emit("water_clean")


func _refresh() -> void:
	var clean := GameState.has_flag("treatment_repaired")
	_sprite.texture = CLEAN if clean else DIRTY
	if clean:
		set_prompt("Drink clean water")
	elif GameState.has_flag("water_tested"):
		set_prompt("Check the water again")
	else:
		set_prompt("Inspect the water")
