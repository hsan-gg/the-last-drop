class_name HarvestPlot
extends Interactable
## Lena's garden bed in the Silent Fields. Dead dust until the soil is brought
## back to life; then the first food in the game grows here, and harvesting it
## heals you and fills your pack.

const DEAD := preload("res://assets/sprites/request_garden.png")
const GROWN := preload("res://assets/sprites/request_garden_done.png")

@export var soil_flag: String = "soil_restored"
@export var harvest_flag: String = "harvest_done"

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	super()
	interacted.connect(_on_interacted)
	EventBus.flag_changed.connect(_refresh.unbind(2))
	_refresh()


func _on_interacted(_by: Node) -> void:
	if not GameState.has_flag(soil_flag):
		EventBus.dialogue_requested.emit("harvest_dead")
		return
	if GameState.has_flag(harvest_flag):
		EventBus.dialogue_requested.emit("harvest_again")
		return
	GameState.set_flag(harvest_flag)
	Survival.heal(Survival.max_health())
	for _i in 3:
		Inventory.add("energy_bar")
	EventBus.loot_found.emit("Tomatoes and beans x3")
	EventBus.celebrate.emit(global_position)
	EventBus.sfx_requested.emit("note_quest")
	EventBus.dialogue_requested.emit("harvest_first")


func _refresh() -> void:
	_sprite.texture = GROWN if GameState.has_flag(soil_flag) else DEAD
	set_prompt("Harvest" if GameState.has_flag(soil_flag) and not GameState.has_flag(harvest_flag) else "Look at the garden bed")
