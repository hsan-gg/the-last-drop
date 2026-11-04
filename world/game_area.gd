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
	"enemy": preload("res://world/enemy.tscn"),
	"chest": preload("res://world/chest.tscn"),
	"region_generator": preload("res://world/region_generator.tscn"),
	"lamp": preload("res://world/lamp.tscn"),
	"request_point": preload("res://world/request_point.tscn"),
	"npc": preload("res://world/npc.tscn"),
	"harvest_plot": preload("res://world/harvest_plot.tscn"),
	"rail_cart": preload("res://world/rail_cart.tscn"),
}
const PENALTY_ZOMBIE := "runner"
const PENALTY_DISTANCE := 90.0
const TOXIC_DAMAGE := 3.0

const BURST_PARTICLES := 14
const BURST_SECONDS := 0.6
const BURST_COLOR := Color("#f2c94c")

@export var area_id: String = "outpost"

var _camera: Camera2D
var _layout: PackedStringArray = PackedStringArray()
var _lit_tint := Color.WHITE
var _hazard_timer := 0.0
var _spawned := 0
var ambience: Ambience
## The way to the player round walls and water, shared by every zombie here.
var nav: NavField
var _reveal_timer := 0.0

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
	_layout = layout
	nav = NavField.new(layout)
	_lit_tint = Color(config.get("lit_tint", "#f0e0c8"))
	var definitions: Dictionary = config.get("entities", {})
	var marker_chars := MapBuilder.SPAWN_MARKER + "".join(PackedStringArray(definitions.keys()))

	var ground := MapBuilder.build_layer(layout, marker_chars, config.get("floor", MapBuilder.GROUND_CHAR), config.get("tileset", ""))
	add_child(ground)
	move_child(ground, 0)
	ambience = Ambience.new()
	ambience.name = "Ambience"
	add_child(ambience)
	move_child(ambience, 1)
	ambience.setup(layout, config)
	_place_entities(layout, definitions, marker_chars)
	AreaLighting.add_player_lantern(_player)
	_arrive(layout)
	_limit_camera(layout)
	if not Content.area(area_id).get("entities", {}).is_empty():
		GameState.set_counter("spawned_%s" % area_id, _spawned)

	_tint.color = Color(config.get("tint", "#ffffff"))
	if GameState.has_flag(RegionGenerator.lit_flag(area_id)):
		_tint.color = _lit_tint
		var lantern := _player.get_node_or_null("Lantern") as PointLight2D
		if lantern != null:
			lantern.visible = false
		ambience.call_deferred("clear_air")
	EventBus.region_lit.connect(_on_region_lit)
	_hud.set_area(area_id)
	GameState.set_flag("area_%s_reached" % area_id)
	Music.play_area(area_id)
	EventBus.player_collapsed.connect(_on_player_collapsed)
	EventBus.penalty_spawn.connect(_on_penalty_spawn)
	EventBus.celebrate.connect(_spawn_burst)
	_play_arrival_dialogue(config.get("arrival_dialogue", ""))
	SaveGame.call_deferred("save_now")


## The whole place brightens when its generator starts.
func _on_region_lit(lit_area: String) -> void:
	if lit_area != area_id:
		return
	ambience.clear_air()
	_night_wave()
	var tween := create_tween().set_parallel()
	tween.tween_property(_tint, "color", _lit_tint, 2.5).set_trans(Tween.TRANS_SINE)
	var lantern := _player.get_node_or_null("Lantern") as PointLight2D
	if lantern != null:  # the region is lit: the lantern is put away
		tween.tween_property(lantern, "energy", 0.0, 2.5)
		tween.chain().tween_callback(func() -> void: lantern.visible = false)


## Green puddles are toxic: standing in one hurts, a lesson in what not to touch.
func _check_hazards(delta: float) -> void:
	_hazard_timer -= delta
	if _hazard_timer > 0.0 or _player == null or _layout.is_empty() or not Combat.enemies_enabled:
		return
	_hazard_timer = 0.6
	var cell := Vector2i((_player.global_position / MapBuilder.TILE_SIZE).floor())
	if cell.y >= 0 and cell.y < _layout.size() and cell.x >= 0 and cell.x < _layout[cell.y].length() and _layout[cell.y][cell.x] == "T":
		Survival.damage(TOXIC_DAMAGE * Difficulty.value("penalty"))
		EventBus.sfx_requested.emit("hurt")
		FloatingText.spawn(_entities, "TOXIC!", _player.global_position, Color("#9be04a"))


func _physics_process(_delta: float) -> void:
	if nav != null and _player != null:
		nav.set_target(_player.global_position)


func _process(delta: float) -> void:
	_check_hazards(delta)
	_reveal_timer -= delta
	if _reveal_timer <= 0.0 and _player != null:
		_reveal_timer = 0.25
		MapMemory.reveal(area_id, Vector2i((_player.global_position / MapBuilder.TILE_SIZE).floor()))


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
		if definition.get("scene", "") == "enemy":
			_place_enemy(scene, definition, position, marker["cell"])
			continue
		var entity: Node2D = scene.instantiate()
		entity.position = position
		var properties: Dictionary = definition.get("props", {})
		for key: String in properties:
			entity.set(key, _typed(properties[key], entity.get(key)))
		if "spawn_key" in entity:
			entity.spawn_key = "%s_%d_%d" % [area_id, marker["cell"].x, marker["cell"].y]
		if entity.has_method("set_region"):
			entity.set_region(area_id)
		entity.add_to_group("scene_%s" % definition.get("scene", ""))
		entity.set_meta("props", properties)
		_entities.add_child(entity)
		AreaLighting.decorate(entity, definition.get("scene", ""))


## Zombies at a marker: one on Medium, fewer on Easy, packs on Hard and Hardcore.
## The draw is seeded, so a run always meets the same zombies in the same places.
func _copies_at(cell: Vector2i) -> int:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s_%d_%d" % [area_id, cell.x, cell.y]) ^ GameState.run_seed
	var multiplier := Difficulty.value("spawn")
	var whole := int(floor(multiplier))
	return whole + (1 if rng.randf() < multiplier - whole else 0)


func _place_enemy(scene: PackedScene, definition: Dictionary, position: Vector2, cell: Vector2i) -> void:
	var copies := _copies_at(cell)
	for copy in copies:
		var enemy: Node2D = scene.instantiate()
		var properties: Dictionary = definition.get("props", {})
		for key: String in properties:
			enemy.set(key, _typed(properties[key], enemy.get(key)))
		enemy.position = position + _free_offset(position, copy)
		enemy.spawn_key = "%s_%d_%d" % [area_id, cell.x, cell.y] + ("" if copy == 0 else "_%d" % copy)
		enemy.add_to_group("scene_enemy")
		_entities.add_child(enemy)
	_spawned += copies


## An offset for the n-th zombie at a marker that lands on open ground, so a
## pack never spawns inside a wall where it could not be reached.
func _free_offset(position: Vector2, copy: int) -> Vector2:
	if copy == 0:
		return Vector2.ZERO
	for attempt in 8:
		var offset := Vector2.from_angle(copy * 2.4 + attempt * TAU / 8.0) * 22.0
		var cell := Vector2i(((position + offset) / MapBuilder.TILE_SIZE).floor())
		if cell.y >= 0 and cell.y < _layout.size() and cell.x >= 0 and cell.x < _layout[cell.y].length() and not MapBuilder.is_solid_char(_layout[cell.y][cell.x]):
			return offset
	return Vector2.ZERO


## Coming back through a gate: stand next to the gate you came through.
func _arrive(layout: PackedStringArray) -> void:
	var marker := SceneManager.arrival_marker
	SceneManager.arrival_marker = ""
	if marker.is_empty():
		return
	var found := MapBuilder.markers(layout, marker)
	if found.is_empty():
		return
	var gate := MapBuilder.cell_center(found[0]["cell"])
	for step: Vector2 in [Vector2(0, 1), Vector2(0, -1), Vector2(1, 0), Vector2(-1, 0), Vector2(0, 2), Vector2(1, 1), Vector2(-1, 1)]:
		var spot := gate + step * MapBuilder.TILE_SIZE
		if is_open_ground(spot):
			_player.place_at(spot)
			return


## Night of the Spoiled: the new light draws the last of them in, one final
## wave (from "night_wave" in the area's config) to hold the light against.
func _night_wave() -> void:
	var wave: Array = Content.area(area_id).get("night_wave", [])
	if wave.is_empty() or not Combat.enemies_enabled:
		return
	EventBus.banner_requested.emit("NIGHT OF THE SPOILED", "The light draws them in. Hold it!", Color("#ff6a5a"))
	for index in wave.size():
		var enemy: Enemy = ENTITY_SCENES["enemy"].instantiate()
		enemy.enemy_id = wave[index]
		enemy.position = open_spot_near(_player.position, PENALTY_DISTANCE + index * 10.0)
		_entities.add_child(enemy)
		enemy.hunt()
	GameState.add_to_counter("night_waves")


## True if `point` is inside the map on a tile you can walk on.
func is_open_ground(point: Vector2) -> bool:
	var cell := Vector2i((point / MapBuilder.TILE_SIZE).floor())
	return cell.y >= 0 and cell.y < _layout.size() and cell.x >= 0 and cell.x < _layout[cell.y].length() \
		and not MapBuilder.is_solid_char(_layout[cell.y][cell.x])


## A walkable spot about `distance` from `around`, trying many directions and
## nearer rings; falls back to `around` itself so nothing lands in a wall.
func open_spot_near(around: Vector2, distance: float) -> Vector2:
	var start := randf() * TAU
	for ring in [1.0, 0.7, 0.45]:
		for attempt in 12:
			var spot: Vector2 = around + Vector2.from_angle(start + attempt * TAU / 12.0) * distance * float(ring)
			if is_open_ground(spot) and is_open_ground(spot + Vector2(6, 0)) and is_open_ground(spot - Vector2(6, 0)):
				return spot
	return around


## The generator's racket calls every zombie still around to the player, so a
## region can always be cleared even if one wandered somewhere awkward.
func summon_remaining() -> int:
	var called := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead():
			continue
		if enemy.global_position.distance_to(_player.global_position) > PENALTY_DISTANCE * 1.5 or not is_open_ground(enemy.global_position):
			enemy.global_position = open_spot_near(_player.global_position, PENALTY_DISTANCE)
		enemy.hunt()
		called += 1
	return called


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
	get_tree().call_group("enemies", "reset_aggro")


## A mistake has consequences: the noise draws a zombie.
func _on_penalty_spawn(reason: String) -> void:
	if not Combat.enemies_enabled:
		return
	var enemy: Node2D = ENTITY_SCENES["enemy"].instantiate()
	enemy.set("enemy_id", PENALTY_ZOMBIE)
	enemy.position = open_spot_near(_player.position, PENALTY_DISTANCE)
	_entities.add_child(enemy)
	(enemy as Enemy).hunt()
	var title := "CONTAMINATION ALERT" if reason == "sorting" else "THE NOISE DRAWS SOMETHING"
	EventBus.banner_requested.emit(title, "A zombie is coming.", Color("#ff6a5a"))


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
