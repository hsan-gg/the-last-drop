class_name SwordSwing
extends Node2D
## What the player's sword and guard look like: the blade sweeping through its
## arc with a fading trail; while blocking, the blade is raised across the body
## with a glowing arc; sparks fly when a blow is blocked, and a bright ring on a
## parry. A broken guard knocks the blade away.

const SWORD_TEXTURE := preload("res://assets/sprites/sword.png")
const SWEEP_RADIANS := 1.25
const GUARD_RADIUS := 14.0
const GUARD_COLOR := Color(0.5, 0.9, 1.0, 0.75)
const RAISE_SECONDS := 0.09
const SPARK_COUNT := 9
## How far the blade pulls back before the sweep.
const WINDUP_EXTRA := 0.45
const BLADE_LENGTH := 15.0
const HAND_DISTANCE := 4.0
const FOLLOW_THROUGH_SECONDS := 0.16
const SMEAR_INNER := 6.0
const SMEAR_OUTER := 19.0
const STEEL := Color("#dfe8f0")
const STEEL_EDGE := Color("#ffffff")
const STEEL_SHADE := Color("#7f8ea0")
const HILT := Color("#8a5a2c")
const GUARD_METAL := Color("#e0b040")

var _blade: Sprite2D
var _guarding := false
var _guard_angle := 0.0
var _guard_strength := 0.0
var _flash := 0.0
var _tint := Color.WHITE
var _raise_tween: Tween
var _swinging := false
var _swing_time := 0.0
var _swing_windup := 0.07
var _swing_sweep := 0.12
var _swing_base := 0.0
var _swing_facing := Vector2.DOWN


func _ready() -> void:
	position = Vector2(0, -8)
	z_index = 5
	_blade = Sprite2D.new()
	_blade.texture = SWORD_TEXTURE
	_blade.centered = false
	_blade.offset = Vector2(-8, -2.5)
	_blade.visible = false
	add_child(_blade)


## A full swing over `seconds`: a short pull back (anticipation), a fast
## sweep with a crescent smear behind the blade, then a follow-through where
## the blade lingers and fades. Drawn in _draw so it stays crisp at any angle.
func swing(facing: Vector2, seconds: float, tint: Color) -> void:
	_tint = tint
	_swing_base = facing.angle()
	_swing_facing = facing
	_swing_time = 0.0
	_swing_windup = seconds * 0.35
	_swing_sweep = seconds * 0.65
	_swinging = true
	_blade.visible = false
	_put_behind_body(facing.y < -0.5)  # facing away: the blade is behind the body


## Behind the body means drawn before the player's sprite at the same depth
## (a negative z_index would sink it under the ground as well).
func _put_behind_body(behind: bool) -> void:
	z_index = 0 if behind else 5
	if behind and get_parent() != null:
		get_parent().move_child(self, 0)


## Blade angle (radians) at swing time `t`, and how much of the sweep is done.
func swing_pose(t: float) -> Dictionary:
	var back := _swing_base - SWEEP_RADIANS
	var wind := back - WINDUP_EXTRA
	var finish := _swing_base + SWEEP_RADIANS
	if t < _swing_windup:
		var k := t / maxf(_swing_windup, 0.001)
		return {"angle": lerpf(back, wind, ease(k, 0.5)), "sweep": 0.0}
	var k2 := clampf((t - _swing_windup) / maxf(_swing_sweep, 0.001), 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - k2, 3.0)
	return {"angle": lerpf(wind, finish, eased), "sweep": eased}


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
		_blade.modulate = Color.WHITE.lerp(Gear.weapon_color(), 0.3)
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
	if _swinging:
		_swing_time += delta
		if _swing_time > _swing_windup + _swing_sweep + FOLLOW_THROUGH_SECONDS:
			_swinging = false
			_put_behind_body(false)
	queue_redraw()


func _draw() -> void:
	if _swinging:
		_draw_swing()
	if _guarding:
		var glow := Color(GUARD_COLOR.r, GUARD_COLOR.g, GUARD_COLOR.b, GUARD_COLOR.a * _guard_strength)
		draw_arc(Vector2.ZERO, GUARD_RADIUS, _guard_angle - 0.95, _guard_angle + 0.95, 12, glow, 2.0)
	if _flash > 0.0:
		draw_circle(Vector2.ZERO, 12.0 + (0.25 - _flash) * 40.0, Color(1, 1, 1, _flash * 2.0))


func _draw_swing() -> void:
	var pose := swing_pose(_swing_time)
	var angle: float = pose["angle"]
	var after := maxf(_swing_time - _swing_windup - _swing_sweep, 0.0)
	var fade := 1.0 - clampf(after / FOLLOW_THROUGH_SECONDS, 0.0, 1.0)
	var hand := _swing_facing * HAND_DISTANCE
	if float(pose["sweep"]) > 0.0:
		_draw_smear(_swing_base - SWEEP_RADIANS - WINDUP_EXTRA, angle, fade)
	_draw_blade(hand, angle, fade)


## The crescent of motion behind the blade: brightest at the edge, thinning
## towards its tail, like the smear frames hand-drawn games use.
func _draw_smear(from_angle: float, to_angle: float, fade: float) -> void:
	var slices := 10
	var span := to_angle - from_angle
	for index in slices:
		var a0 := from_angle + span * float(index) / slices
		var a1 := from_angle + span * float(index + 1) / slices
		var strength := float(index + 1) / slices  # newest slice is strongest
		var inner := SMEAR_INNER + (1.0 - strength) * 6.0
		var points := PackedVector2Array([
			Vector2.from_angle(a0) * inner, Vector2.from_angle(a0) * SMEAR_OUTER,
			Vector2.from_angle(a1) * SMEAR_OUTER, Vector2.from_angle(a1) * inner,
		])
		var color := _tint.lerp(STEEL_EDGE, 0.75)
		color.a = 0.7 * strength * strength * fade
		draw_colored_polygon(points, color)
	var rim := STEEL_EDGE
	rim.a = 0.8 * fade
	draw_arc(Vector2.ZERO, SMEAR_OUTER, to_angle - span * 0.35, to_angle, 6, rim, 1.0)


func _draw_blade(hand: Vector2, angle: float, fade: float) -> void:
	var along := Vector2.from_angle(angle)
	var side := along.orthogonal()
	var tip := hand + along * BLADE_LENGTH
	var steel := STEEL.lerp(_tint, 0.25)
	steel.a = fade
	var shade := STEEL_SHADE
	shade.a = fade
	var edge := STEEL_EDGE
	edge.a = fade
	draw_line(hand + along * 3.0, tip, shade, 2.0)
	draw_line(hand + along * 3.0, tip - along, steel, 1.0)
	draw_line(hand + along * 6.0, tip - along * 3.0, edge, 1.0)
	var guard_color := GUARD_METAL
	guard_color.a = fade
	draw_line(hand + along * 2.5 - side * 3.0, hand + along * 2.5 + side * 3.0, guard_color, 1.5)
	var hilt := HILT
	hilt.a = fade
	draw_line(hand - along * 1.0, hand + along * 2.0, hilt, 2.0)
