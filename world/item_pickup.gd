class_name ItemPickup
extends Interactable
## A world object that moves one item into the inventory and removes itself.

@export var item_id: String = ""

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	super()
	_sprite.texture = ItemDB.icon(item_id)
	set_prompt("Pick up %s" % ItemDB.display_name(item_id))
	interacted.connect(_on_interacted)


func _on_interacted(_by: Node) -> void:
	if Inventory.add(item_id):
		EventBus.sfx_requested.emit("pickup")
		EventBus.celebrate.emit(global_position)
		queue_free()
