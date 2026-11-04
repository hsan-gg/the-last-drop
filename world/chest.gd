class_name Chest
extends Interactable
## A chest of gear and materials. Opens once per run (the flag keeps it open
## when you come back) and announces what was inside.

const CLOSED := preload("res://assets/sprites/chest_closed.png")
const OPEN := preload("res://assets/sprites/chest_open.png")

## Unique per placed chest.
@export var chest_id: String = ""
## Set by GameArea from the map cell; used when no chest_id is given.
@export var spawn_key: String = ""
@export var gear: Array[String] = []
@export var items: Dictionary = {}

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	super()
	interacted.connect(_on_interacted)
	_refresh()


func is_open() -> bool:
	return GameState.has_flag(_flag())


func _on_interacted(_by: Node) -> void:
	if is_open():
		return
	GameState.set_flag(_flag())
	GameState.add_to_counter("chests_opened")
	EventBus.sfx_requested.emit("chest_open")
	get_tree().create_timer(0.25).timeout.connect(EventBus.sfx_requested.emit.bind("loot"))
	EventBus.celebrate.emit(global_position)
	_pop_lid()
	var found: Array[String] = []
	for gear_id in gear:
		if Gear.grant(gear_id):
			found.append(Gear.definition(gear_id)["name"])
	for item_id: String in items:
		for _count in int(items[item_id]):
			Inventory.add(item_id)
		found.append("%s x%d" % [ItemDB.display_name(item_id), int(items[item_id])])
	_refresh()
	EventBus.loot_found.emit("Chest: %s" % (", ".join(found) if not found.is_empty() else "empty"))


## The lid springs: a quick squash and stretch so opening feels physical.
func _pop_lid() -> void:
	var tween := _sprite.create_tween()
	tween.tween_property(_sprite, "scale", Vector2(1.2, 0.8), 0.06)
	tween.tween_property(_sprite, "scale", Vector2(0.9, 1.15), 0.08)
	tween.tween_property(_sprite, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


func _flag() -> String:
	return "chest_%s" % (chest_id if not chest_id.is_empty() else spawn_key)


func _refresh() -> void:
	_sprite.texture = OPEN if is_open() else CLOSED
	set_prompt("Empty chest" if is_open() else "Open the chest")
