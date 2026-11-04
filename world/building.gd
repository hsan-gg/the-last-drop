class_name Building
extends Node2D
## A building you can walk into, Stardew-style: a solid house on the map with
## its front door at the bottom centre (the map marker's cell). Its look comes
## from assets/sprites/buildings/<look>.png (tools/assets_buildings.py); the
## room inside is another area, reached through the door.

const SPRITE_FORMAT := "res://assets/sprites/buildings/%s.png"
## Each look's size and how many tiles up from the ground it is solid
## (tools/assets_buildings.py). Above that the roof overhangs open ground: you
## can walk behind the house, and the roof turns see-through while you do.
const SHAPES_PATH := "res://data/building_looks.json"
const BEHIND_ALPHA := 0.45
const SHADOW := Color(0, 0, 0, 0.28)
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
var _sprite: Sprite2D
var _solid_height := 0.0
var _size := Vector2.ZERO


func _ready() -> void:
	var texture := load(SPRITE_FORMAT % look) as Texture2D
	if texture == null:
		push_error("Building: no sprite for look '%s'" % look)
		return
	var size := texture.get_size()
	_size = size
	var bottom := MapBuilder.TILE_SIZE / 2.0
	_solid_height = solid_rows(look) * MapBuilder.TILE_SIZE
	add_child(_ground_shadow(size, bottom))
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	_sprite.texture = texture
	_sprite.position = Vector2(0, bottom - size.y / 2.0)
	add_child(_sprite)

	# Only the house's base is solid; the roof above it overhangs open ground.
	var walls := StaticBody2D.new()
	walls.collision_layer = 1
	walls.collision_mask = 0
	var shape := RectangleShape2D.new()
	shape.size = Vector2(size.x - 4.0, _solid_height - 6.0)
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


## The roof turns see-through while the player is behind the house.
func _process(delta: float) -> void:
	if _sprite == null:
		return
	var target := BEHIND_ALPHA if player_is_behind() else 1.0
	_sprite.modulate.a = move_toward(_sprite.modulate.a, target, delta * 4.0)


func player_is_behind() -> bool:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player == null:
		return false
	var local := player.global_position - global_position
	var bottom := MapBuilder.TILE_SIZE / 2.0
	return absf(local.x) < _size.x / 2.0 + 2.0 and local.y < bottom - _solid_height + 8.0 and local.y > bottom - _size.y - 4.0


## A soft shadow cast down and to the right (the light comes from the upper left).
func _ground_shadow(size: Vector2, bottom: float) -> Polygon2D:
	var shadow := Polygon2D.new()
	var left := -size.x / 2.0 + 4.0
	var right := size.x / 2.0
	var top := bottom - _solid_height + 4.0
	shadow.polygon = PackedVector2Array([
		Vector2(left, bottom - 1.0), Vector2(right, bottom - 1.0), Vector2(right, top),
		Vector2(right + 7.0, top + 5.0), Vector2(right + 7.0, bottom + 4.0), Vector2(left + 6.0, bottom + 4.0),
	])
	shadow.color = SHADOW
	return shadow


## How many tiles up from its door row a look is solid.
static func solid_rows(look_id: String) -> int:
	var shapes: Variant = DataLoader.load_json(SHAPES_PATH)
	var shape: Dictionary = shapes.get(look_id, {}) if shapes is Dictionary else {}
	return int(shape.get("solid_rows", footprint(look_id).y))


## How many tiles the building covers (for maps and tests).
static func footprint(look_id: String) -> Vector2i:
	var texture := load(SPRITE_FORMAT % look_id) as Texture2D
	return Vector2i(texture.get_size() / MapBuilder.TILE_SIZE) if texture != null else Vector2i.ZERO
