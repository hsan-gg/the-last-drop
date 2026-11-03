class_name Lamp
extends Node2D
## A street lamp that stays dark until its region's generator is started, then
## flickers on a moment after the rest, so the place lights up in a wave.

const TEXTURE := preload("res://assets/sprites/decor/lamp.png")
const ON_ENERGY := 1.5
const LIGHT_RADIUS := 62.0
const MAX_DELAY := 1.4

var _sprite: Sprite2D
var _light: PointLight2D
var _area_id := ""


func _ready() -> void:
	_sprite = Sprite2D.new()
	_sprite.texture = TEXTURE
	_sprite.position = Vector2(0, MapBuilder.TILE_SIZE / 2.0 - TEXTURE.get_height() / 2.0)
	add_child(_sprite)
	_light = AreaLighting.make_light({"color": "#ffd9a0", "energy": ON_ENERGY, "radius": LIGHT_RADIUS})
	_light.position = Vector2(0, -TEXTURE.get_height() + 10.0)
	_light.energy = 0.0
	_light.visible = false
	add_child(_light)
	add_to_group("lamps")
	EventBus.region_lit.connect(_on_region_lit)
	if not _area_id.is_empty() and GameState.has_flag(RegionGenerator.lit_flag(_area_id)):
		_turn_on(0.0)


## The area this lamp belongs to; GameArea sets it before the lamp enters the tree.
func set_region(area: String) -> void:
	_area_id = area


func is_on() -> bool:
	return _light.visible and _light.energy > 0.0


func _on_region_lit(area: String) -> void:
	if area == _area_id:
		_turn_on(randf() * MAX_DELAY)


func _turn_on(delay: float) -> void:
	_light.visible = true
	if delay <= 0.0:  # a region that was already lit when the area loaded: no show, just on
		_light.energy = ON_ENERGY
		return
	var tween := create_tween()
	tween.tween_interval(delay)
	for step in [0.0, 0.6, 0.15, 1.0]:  # a stuttering flicker before it holds
		tween.tween_property(_light, "energy", ON_ENERGY * step, 0.06)
	tween.tween_property(_light, "energy", ON_ENERGY, 0.2)
