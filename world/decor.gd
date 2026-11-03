class_name Decor
extends StaticBody2D
## Non-interactive set dressing placed from data/areas.json: a sprite sitting on
## its map cell, optionally solid and optionally giving off light.

const SPRITE_PATH_FORMAT := "res://assets/sprites/decor/%s.png"
const FIRE_ENERGY := 0.85

@export var sprite_name: String = ""
## Collision footprint in pixels; zero means the player can walk over it.
@export var blocker_size: Vector2 = Vector2.ZERO
## Hex colour of an attached light; empty means no light.
@export var light_color: String = ""
@export var light_radius: float = 36.0


func _ready() -> void:
	collision_layer = 1
	collision_mask = 0
	var texture := load(SPRITE_PATH_FORMAT % sprite_name) as Texture2D
	if texture == null:
		push_error("Decor: no sprite '%s' in assets/sprites/decor" % sprite_name)
		return
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = texture
	sprite.position = Vector2(0, MapBuilder.TILE_SIZE / 2.0 - texture.get_height() / 2.0)
	add_child(sprite)
	if blocker_size != Vector2.ZERO:
		_add_blocker()
	if not light_color.is_empty():
		add_child(AreaLighting.make_light({"color": light_color, "energy": FIRE_ENERGY, "radius": light_radius}))


func _add_blocker() -> void:
	var shape := RectangleShape2D.new()
	shape.size = blocker_size
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = Vector2(0, MapBuilder.TILE_SIZE / 2.0 - blocker_size.y / 2.0)
	add_child(collider)
