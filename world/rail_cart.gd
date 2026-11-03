class_name RailCart
extends Interactable
## A rail cart on the old maintenance line. With the region's lights on it runs
## to any other lit region (see ui/travel_panel.gd), so errands and old friends
## are never a long walk away.

const SPRITE := preload("res://assets/sprites/rail_cart.png")

@export var region_id: String = ""

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	super()
	_sprite.texture = SPRITE
	interacted.connect(_on_interacted)
	EventBus.flag_changed.connect(_refresh.unbind(2))
	_refresh()


func powered() -> bool:
	return GameState.has_flag(RegionGenerator.lit_flag(region_id))


func _on_interacted(_by: Node) -> void:
	if not powered():
		EventBus.text_requested.emit(["An old rail cart. The line is dead.", "Light this region with its generator and the cart will run."] as Array[String])
		return
	var panel := get_tree().get_first_node_in_group("travel_panel") as TravelPanel
	if panel != null:
		panel.open_from(region_id)


func _refresh() -> void:
	set_prompt("Ride the rail cart" if powered() else "Look at the rail cart")
	_sprite.modulate = Color.WHITE if powered() else Color(0.6, 0.6, 0.65)
