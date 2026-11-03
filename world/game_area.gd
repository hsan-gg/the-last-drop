class_name GameArea
extends Node2D
## One explorable area, built entirely from data/areas.json and its ASCII map.
## Add an area by writing a layout and a config entry; no new code needed.

const ENTITY_SCENES := {
	"scrap_pile": preload("res://world/scrap_pile.tscn"),
	"water_source": preload("res://world/water_source.tscn"),
	"repair_station": preload("res://world/repair_station.tscn"),
	"recording": preload("res://world/recording.tscn"),
	"area_exit": preload("res://world/area_exit.tscn"),
	"archive_terminal": preload("res://world/archive_terminal.tscn"),
	"item_pickup": preload("res://world/item_pickup.tscn"),
	"decor": preload("res://world/decor.tscn"),
	"sample_point": preload("res://world/sample_point.tscn"),
}
const COLLAPSE_LINES: Array[String] = [
	"You collapse from the strain, and come to at the edge of camp.",
	"Mistakes with hazardous waste cost health. Take more care.",
]

const BURST_PARTICLES := 14
const BURST_SECONDS := 0.6
const BURST_COLOR := Color("#f2c94c")

@export var area_id: String = "outpost"

var _camera: Camera2D

@onready var _entities: Node2D = $Entities
@onready var _player: Player = $Entities/Player
@onready var _hud: Hud = $Hud
@onready var _tint: CanvasModulate = $Tint


func _ready() -> void:
	var config := Content.area(area_id)
	if config.is_empty():
		push_error("GameArea: no config for area '%s' in data/areas.json" % area_id)
		return

	var layout := MapBuilder.load_layout(config["layout"])
	var definitions: Dictionary = config.get("entities", {})
	var marker_chars := MapBuilder.SPAWN_MARKER + "".join(PackedStringArray(definitions.keys()))

	var ground := MapBuilder.build_layer(layout, marker_chars, config.get("floor", MapBuilder.GROUND_CHAR))
	add_child(ground)
	move_child(ground, 0)
	_place_entities(layout, definitions, marker_chars)
	AreaLighting.add_player_lantern(_player)
	_limit_camera(layout)

	_tint.color = Color(config.get("tint", "#ffffff"))
	_hud.set_area(area_id)
	GameState.set_flag("area_%s_reached" % area_id)
	EventBus.player_collapsed.connect(_on_player_collapsed)
	EventBus.celebrate.connect(_spawn_burst)
	_play_arrival_dialogue(config.get("arrival_dialogue", ""))


func _place_entities(layout: PackedStringArray, definitions: Dictionary, marker_chars: String) -> void:
	for marker in MapBuilder.markers(layout, marker_chars):
		var position := MapBuilder.cell_center(marker["cell"])
		if marker["char"] == MapBuilder.SPAWN_MARKER:
			_player.place_at(position)
			continue

		var definition: Dictionary = definitions[marker["char"]]
		var scene: PackedScene = ENTITY_SCENES.get(definition.get("scene", ""))
		if scene == null:
			push_error("GameArea: unknown entity scene '%s'" % definition.get("scene", ""))
			continue
		var entity: Node2D = scene.instantiate()
		entity.position = position
		var properties: Dictionary = definition.get("props", {})
		for key: String in properties:
			entity.set(key, _typed(properties[key], entity.get(key)))
		_entities.add_child(entity)
		AreaLighting.decorate(entity, definition.get("scene", ""))


func _limit_camera(layout: PackedStringArray) -> void:
	var size := MapBuilder.layout_size(layout) * MapBuilder.TILE_SIZE
	_camera = _player.get_node("Camera2D")
	_camera.limit_left = 0
	_camera.limit_top = 0
	_camera.limit_right = size.x
	_camera.limit_bottom = size.y


func _play_arrival_dialogue(dialogue_id: String) -> void:
	var seen_flag := "arrival_%s_seen" % area_id
	if dialogue_id.is_empty() or GameState.has_flag(seen_flag):
		return
	GameState.set_flag(seen_flag)
	EventBus.dialogue_requested.emit(dialogue_id)


func _spawn_burst(world_position: Vector2) -> void:
	var burst := CPUParticles2D.new()
	burst.position = world_position
	burst.one_shot = true
	burst.explosiveness = 1.0
	burst.amount = BURST_PARTICLES
	burst.lifetime = BURST_SECONDS
	burst.direction = Vector2.UP
	burst.spread = 180.0
	burst.gravity = Vector2.ZERO
	burst.initial_velocity_min = 25.0
	burst.initial_velocity_max = 55.0
	burst.scale_amount_min = 2.0
	burst.scale_amount_max = 2.0
	burst.color = BURST_COLOR
	burst.z_index = 50
	burst.finished.connect(burst.queue_free)
	_entities.add_child(burst)
	burst.emitting = true


func _on_player_collapsed() -> void:
	EventBus.sfx_requested.emit("collapse")
	EventBus.text_requested.emit(COLLAPSE_LINES)


## JSON has no Vector2 and its arrays are untyped, so convert to whatever type
## the exported property already holds.
func _typed(value: Variant, current: Variant) -> Variant:
	if value is Array and current is Vector2:
		return Vector2(value[0], value[1])
	if value is Array:
		var strings: Array[String] = []
		strings.assign(value)
		return strings
	return value
