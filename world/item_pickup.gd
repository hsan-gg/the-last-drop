class_name ItemPickup
extends Interactable
## A world object that moves one item into the inventory and removes itself.

@export var item_id: String = ""
## Unique per placed pickup, so a find stays found when the area is rebuilt.
@export var pickup_id: String = ""

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	super()
	if not pickup_id.is_empty() and GameState.has_flag(_flag()):
		queue_free()
		return
	_sprite.texture = ItemDB.icon(item_id)
	set_prompt("Pick up %s" % ItemDB.display_name(item_id))
	interacted.connect(_on_interacted)


func _on_interacted(_by: Node) -> void:
	if Inventory.add(item_id):
		if not pickup_id.is_empty():
			GameState.set_flag(_flag())
		GameState.add_to_counter("pickups")
		EventBus.sfx_requested.emit("pickup")
		EventBus.celebrate.emit(global_position)
		queue_free()


func _flag() -> String:
	return "picked_%s" % pickup_id
