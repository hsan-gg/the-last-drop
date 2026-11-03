class_name SwordSwing
extends Node2D
## What the player's sword and guard look like: the blade sweeping through its
## arc with a fading trail; while blocking, the blade is raised across the body
## with a glowing arc; sparks fly when a blow is blocked, and a bright ring on a
## parry. A broken guard knocks the blade away.

const SWORD_TEXTURE := preload("res://assets/sprites/sword.png")
const SWEEP_RADIANS := 1.25
const TRAIL_RADIUS := 17.0
const GUARD_RADIUS := 14.0
const GUARD_COLOR := Color(0.5, 0.9, 1.0, 0.75)
const RAISE_SECONDS := 0.09
const SPARK_COUNT := 9

var _blade: Sprite2D
var _guarding := false
var _guard_angle := 0.0
var _guard_strength := 0.0
var _trail_angle := 0.0
var _trail_from := 0.0
var _trail_alpha := 0.0
var _flash := 0.0
var _tint := Color.WHITE
var _raise_tween: Tween


func _ready() -> void:
	position = Vector2(0, -8)
	z_index = 5
	_blade = Sprite2D.new()
	_blade.texture = SWORD_TEXTURE
	_blade.centered = false
	_blade.offset = Vector2(-8, -2.5)
	_blade.visible = false
	add_child(_blade)


func swing(facing: Vector2, seconds: float, tint: Color) -> void:
	var base := facing.angle()
	_tint = tint
	_trail_from = base - SWEEP_RADIANS
	_trail_alpha = 0.9
	_blade.visible = true
	_blade.scale = Vector2.ONE
	_blade.modulate = tint
	_blade.position = facing * 3.0 + Vector2(8, 0).rotated(base)
	_blade.rotation = base - SWEEP_RADIANS
	var tween := create_tween().set_parallel()
	tween.tween_property(_blade, "rotation", base + SWEEP_RADIANS, seconds).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "_trail_alpha", 0.0, seconds * 1.6)
	tween.chain().tween_callback(func() -> void: _blade.visible = false)
	var angle_tween := create_tween()
	angle_tween.tween_method(func(value: float) -> void: _trail_angle = value, base - SWEEP_RADIANS, base + SWEEP_RADIANS, seconds).set_ease(Tween.EASE_OUT)


## Raises or lowers the guard. Raising snaps the blade up across the body.
func guard(active: bool, facing: Vector2) -> void:
	_guard_angle = facing.angle()
	if active == _guarding:
		_blade.rotation = _guard_angle + PI / 2.0
		_blade.position = facing * 8.0
		return
	_guarding = active
	if _raise_tween != null:
		_raise_tween.kill()
	if active:
		_blade.visible = true
		_blade.modulate = Gear.weapon_color()
		_blade.scale = Vector2.ONE
		_blade.rotation = _guard_angle
		_blade.position = facing * 3.0
		_guard_strength = 0.0
		_raise_tween = create_tween().set_parallel()
		_raise_tween.tween_property(_blade, "rotation", _guard_angle + PI / 2.0, RAISE_SECONDS).set_ease(Tween.EASE_OUT)
		_raise_tween.tween_property(_blade, "position", facing * 8.0, RAISE_SECONDS).set_ease(Tween.EASE_OUT)
		_raise_tween.tween_property(self, "_guard_strength", 1.0, RAISE_SECONDS)
	else:
		_guard_strength = 0.0
		_blade.visible = false


func parry_flash(facing: Vector2 = Vector2.DOWN) -> void:
	_flash = 0.25
	_spark_burst(facing * 8.0, Color("#bfefff"), SPARK_COUNT + 5)


## A blow was blocked: sparks off the blade and a small kick back.
func clash(facing: Vector2) -> void:
	_spark_burst(facing * 9.0, Color("#ffe27a"), SPARK_COUNT)
	if _blade.visible:
		var kick := create_tween()
		var rest := facing * 8.0
		kick.tween_property(_blade, "position", rest - facing * 3.0, 0.04)
		kick.tween_property(_blade, "position", rest, 0.08)


## The guard gave way: the blade is knocked off to the side.
func break_guard() -> void:
	_blade.visible = true
	_blade.modulate = Color("#ff9a5a")
	var tween := create_tween().set_parallel()
	tween.tween_property(_blade, "rotation", _blade.rotation + 1.2, 0.18)
	tween.tween_property(_blade, "modulate:a", 0.0, 0.25)
	tween.chain().tween_callback(func() -> void:
		_blade.visible = false
		_blade.modulate.a = 1.0)


func _spark_burst(at: Vector2, color: Color, count: int) -> void:
	var sparks := CPUParticles2D.new()
	sparks.position = at
	sparks.one_shot = true
	sparks.emitting = true
	sparks.amount = count
	sparks.lifetime = 0.3
	sparks.explosiveness = 1.0
	sparks.spread = 180.0
	sparks.gravity = Vector2.ZERO
	sparks.initial_velocity_min = 40.0
	sparks.initial_velocity_max = 90.0
	sparks.scale_amount_min = 1.0
	sparks.scale_amount_max = 2.0
	sparks.color = color
	sparks.finished.connect(sparks.queue_free)
	add_child(sparks)


func _process(delta: float) -> void:
	_flash = maxf(_flash - delta, 0.0)
	queue_redraw()


func _draw() -> void:
	if _trail_alpha > 0.01:
		var color := Color(_tint.r, _tint.g, _tint.b, _trail_alpha * 0.6)
		draw_arc(Vector2.ZERO, TRAIL_RADIUS, _trail_from, _trail_angle, 14, color, 3.0)
	if _guarding:
		var glow := Color(GUARD_COLOR.r, GUARD_COLOR.g, GUARD_COLOR.b, GUARD_COLOR.a * _guard_strength)
		draw_arc(Vector2.ZERO, GUARD_RADIUS, _guard_angle - 0.95, _guard_angle + 0.95, 12, glow, 2.0)
	if _flash > 0.0:
		draw_circle(Vector2.ZERO, 12.0 + (0.25 - _flash) * 40.0, Color(1, 1, 1, _flash * 2.0))
