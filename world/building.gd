class_name Building
extends Node2D
## A building you can walk into, Stardew-style: a solid house on the map with
## its front door at the bottom centre (the map marker's cell). Its look comes
## from assets/sprites/buildings/<look>.png (tools/assets_buildings.py); the
## room inside is another area, reached through the door.

const SPRITE_FORMAT := "res://assets/sprites/buildings/%s.png"
const DOOR_SCENE := preload("res://world/door.tscn")
const WINDOW_LIGHT := {"color": "#ffcf80", "energy": 0.9, "radius": 40.0}

@export var look: String = "outpost_house"
@export_file("*.tscn") var interior: String = ""
## The marker of the way out inside, where you arrive.
@export var inside_marker: String = "^"
@export var prompt: String = "Go inside"
@export var required_flag: String = ""
@export var key_item: String = ""
@export var locked_text: String = "The door is locked."
@export var spawn_key: String = ""

var door: Door


func _ready() -> void:
	var texture := load(SPRITE_FORMAT % look) as Texture2D
	if texture == null:
		push_error("Building: no sprite for look '%s'" % look)
		return
	var size := texture.get_size()
	var bottom := MapBuilder.TILE_SIZE / 2.0
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = texture
	sprite.position = Vector2(0, bottom - size.y / 2.0)
	add_child(sprite)

	var walls := StaticBody2D.new()
	walls.collision_layer = 1
	walls.collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = Vector2(size.x - 4.0, size.y - 6.0)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	collider.position = Vector2(0, bottom - 6.0 - shape.size.y / 2.0)
	walls.add_child(collider)
	add_child(walls)

	door = DOOR_SCENE.instantiate()
	door.position = Vector2(0, bottom - 2.0)
	door.target_scene = interior
	door.arrive_marker = inside_marker
	door.prompt = prompt
	door.required_flag = required_flag
	door.key_item = key_item
	door.locked_text = locked_text
	door.spawn_key = spawn_key
	add_child(door)
	var light := AreaLighting.make_light(WINDOW_LIGHT)
	light.position = Vector2(0, bottom - 16.0)
	add_child(light)


## How many tiles the building covers (for maps and tests).
static func footprint(look_id: String) -> Vector2i:
	var texture := load(SPRITE_FORMAT % look_id) as Texture2D
	return Vector2i(texture.get_size() / MapBuilder.TILE_SIZE) if texture != null else Vector2i.ZERO
