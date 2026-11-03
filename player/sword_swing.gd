class_name SwordSwing
extends Node2D
## What the player's sword and guard look like: the blade sweeping through its
## arc with a fading trail, a cyan arc while blocking, and a white flash on a parry.

const SWORD_TEXTURE := preload("res://assets/sprites/sword.png")
const SWEEP_RADIANS := 1.25
const TRAIL_RADIUS := 17.0
const GUARD_RADIUS := 14.0
const GUARD_COLOR := Color(0.5, 0.9, 1.0, 0.75)

var _blade: Sprite2D
var _guarding := false
var _guard_angle := 0.0
var _trail_angle := 0.0
var _trail_from := 0.0
var _trail_alpha := 0.0
var _flash := 0.0
var _tint := Color.WHITE


func _ready() -> void:
	position = Vector2(0, -8)
	z_index = 5
	_blade = Sprite2D.new()
	_blade.texture = SWORD_TEXTURE
	_blade.centered = false
	_blade.offset = Vector2(0, -2.5)
	_blade.visible = false
	add_child(_blade)


func swing(facing: Vector2, seconds: float, tint: Color) -> void:
	var base := facing.angle()
	_tint = tint
	_trail_from = base - SWEEP_RADIANS
	_trail_alpha = 0.9
	_blade.visible = true
	_blade.modulate = tint
	_blade.position = facing * 3.0
	_blade.rotation = base - SWEEP_RADIANS
	var tween := create_tween().set_parallel()
	tween.tween_property(_blade, "rotation", base + SWEEP_RADIANS, seconds).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_trail_alpha", 0.0, seconds * 1.6)
	tween.chain().tween_callback(func() -> void: _blade.visible = false)
	var angle_tween := create_tween()
	angle_tween.tween_method(func(value: float) -> void: _trail_angle = value, base - SWEEP_RADIANS, base + SWEEP_RADIANS, seconds).set_ease(Tween.EASE_OUT)


func guard(active: bool, facing: Vector2) -> void:
	_guarding = active
	_guard_angle = facing.angle()


func parry_flash() -> void:
	_flash = 0.25


func _process(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	if _trail_alpha > 0.01:
		var color := Color(_tint.r, _tint.g, _tint.b, _trail_alpha * 0.6)
		draw_arc(Vector2.ZERO, TRAIL_RADIUS, _trail_from, _trail_angle, 14, color, 3.0)
	if _guarding:
		draw_arc(Vector2.ZERO, GUARD_RADIUS, _guard_angle - 0.95, _guard_angle + 0.95, 12, GUARD_COLOR, 2.0)
	if _flash > 0.0:
		draw_circle(Vector2.ZERO, 12.0 + (0.25 - _flash) * 40.0, Color(1, 1, 1, _flash * 2.0))
