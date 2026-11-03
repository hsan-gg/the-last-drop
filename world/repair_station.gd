class_name RepairStation
extends Interactable
## A broken machine. Bring the recovered materials it needs and it is fixed.

const SPRITES := {
	"treatment_unit": {
		"broken": preload("res://assets/sprites/treatment_unit_broken.png"),
		"fixed": preload("res://assets/sprites/treatment_unit_fixed.png"),
	},
	"shelter_roof": {
		"broken": preload("res://assets/sprites/shelter_broken.png"),
		"fixed": preload("res://assets/sprites/shelter_fixed.png"),
	},
	"filter_plant": {
		"broken": preload("res://assets/sprites/treatment_unit_broken.png"),
		"fixed": preload("res://assets/sprites/treatment_unit_fixed.png"),
	},
	"generator": {
		"broken": preload("res://assets/sprites/generator_broken.png"),
		"fixed": preload("res://assets/sprites/generator_fixed.png"),
	},
}

@export var repair_id: String = ""

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	super()
	interacted.connect(_on_interacted)
	EventBus.flag_changed.connect(_refresh.unbind(2))
	_refresh()


func _on_interacted(_by: Node) -> void:
	if RepairRules.is_done(repair_id):
		return
	if RepairRules.perform(repair_id):
		EventBus.sfx_requested.emit("repair")
		EventBus.celebrate.emit(global_position)
		EventBus.dialogue_requested.emit(Content.repair(repair_id).get("dialogue", ""))
		return
	EventBus.text_requested.emit(_missing_text())


func _missing_text() -> Array[String]:
	var repair := Content.repair(repair_id)
	var needs: Array[String] = []
	var shortfall := RepairRules.missing(repair_id)
	for item_id: String in shortfall:
		needs.append("%dx %s" % [shortfall[item_id], ItemDB.display_name(item_id)])
	var lines: Array[String] = [
		"The %s is broken. It still needs: %s." % [repair.get("name", "machine"), ", ".join(needs)],
		"Sort scrap to recover usable materials. Hazardous items can never be used.",
	]
	return lines


func _refresh() -> void:
	var done := RepairRules.is_done(repair_id)
	var textures: Dictionary = SPRITES.get(repair_id, {})
	if not textures.is_empty():
		_sprite.texture = textures["fixed" if done else "broken"]
	var machine_name: String = Content.repair(repair_id).get("name", "machine")
	set_prompt("%s: working" % machine_name if done else "Repair the %s" % machine_name)
