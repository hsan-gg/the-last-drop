class_name Workbench
extends Interactable
## A bench with a vice, a forge and a grinder: where mined ore and salvage
## become gear (see data/recipes.json and ui/craft_panel.gd).

const SPRITE := preload("res://assets/sprites/stations/workbench.png")


func _ready() -> void:
	super()
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = SPRITE
	sprite.position = Vector2(0, MapBuilder.TILE_SIZE / 2.0 - SPRITE.get_height() / 2.0)
	add_child(sprite)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(18, 16)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	blocker_size = Vector2(14, 8)
	blocker_offset = Vector2(0, 4)
	_add_blocker()
	set_prompt("Use the workbench")
	interacted.connect(func(_by: Node) -> void: EventBus.craft_requested.emit())
