class_name TitleBackdrop
extends Control
## The title screen's world: a dusk sky with a low sun, two layers of ruined
## skyline, a mound of rubbish in front and embers drifting up.

const SKY_TOP := Color("#1a1230")
const SKY_MID := Color("#5a2a4a")
const SKY_HORIZON := Color("#e8803c")
const SUN := Color("#ffd9a0")
const FAR_BUILDINGS := Color("#4a2a4e")
const NEAR_BUILDINGS := Color("#241830")
const GROUND := Color("#1a1018")
const WINDOW := Color("#f0a050")
const HORIZON_Y := 0.74
const EMBER_COUNT := 28

var _rng := RandomNumberGenerator.new()


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_embers())


func _draw() -> void:
	_rng.seed = 2026
	var size_px := get_viewport_rect().size
	var horizon := size_px.y * HORIZON_Y
	_draw_sky(size_px, horizon)
	_draw_sun(size_px, horizon)
	_draw_skyline(size_px, horizon, FAR_BUILDINGS, 14.0, 52.0, 10.0, 0.0)
	_draw_skyline(size_px, horizon, NEAR_BUILDINGS, 10.0, 36.0, 14.0, 0.5)
	draw_rect(Rect2(0, horizon, size_px.x, size_px.y - horizon), GROUND)
	_draw_rubbish(size_px, horizon)


func _draw_sky(size_px: Vector2, horizon: float) -> void:
	var bands := 36
	for band in bands:
		var t := float(band) / (bands - 1)
		var color := SKY_TOP.lerp(SKY_MID, minf(t * 2.0, 1.0))
		if t > 0.5:
			color = SKY_MID.lerp(SKY_HORIZON, (t - 0.5) * 2.0)
		draw_rect(Rect2(0, horizon * band / bands, size_px.x, horizon / bands + 1.0), color)


func _draw_sun(size_px: Vector2, horizon: float) -> void:
	var center := Vector2(size_px.x * 0.72, horizon - 6.0)
	for ring in 5:
		draw_circle(center, 44.0 - ring * 7.0, Color(SUN.r, SUN.g, SUN.b, 0.07 + ring * 0.05))
	draw_circle(center, 16.0, SUN)


func _draw_skyline(size_px: Vector2, horizon: float, color: Color, min_h: float, max_h: float, width: float, lit: float) -> void:
	var x := -4.0
	while x < size_px.x:
		var w := width + _rng.randf_range(0.0, 14.0)
		var h := _rng.randf_range(min_h, max_h)
		draw_rect(Rect2(x, horizon - h, w, h + 1.0), color)
		if h > 34.0 and _rng.randf() < 0.5:  # a broken top, like a snapped storey
			draw_rect(Rect2(x + w * 0.3, horizon - h - 5.0, w * 0.4, 5.0), color)
		if lit > 0.0:
			for row in int(h / 8.0):
				if _rng.randf() < lit * 0.18:
					draw_rect(Rect2(x + 2.0 + _rng.randi_range(0, int(w) - 5), horizon - h + 4.0 + row * 8.0, 2, 3), WINDOW)
		x += w + _rng.randf_range(1.0, 5.0)


func _draw_rubbish(size_px: Vector2, horizon: float) -> void:
	var x := 0.0
	while x < size_px.x:
		var w := _rng.randf_range(8.0, 20.0)
		var h := _rng.randf_range(2.0, 9.0)
		draw_rect(Rect2(x, horizon - h, w, h + 1.0), GROUND)
		if _rng.randf() < 0.25:
			draw_rect(Rect2(x + 2.0, horizon - h - 1.0, 2, 2), Color("#7a4a3a"))
		x += w - 2.0


func _embers() -> CPUParticles2D:
	var embers := CPUParticles2D.new()
	var size_px := get_viewport_rect().size
	embers.position = Vector2(size_px.x * 0.5, size_px.y * 0.95)
	embers.amount = EMBER_COUNT
	embers.lifetime = 7.0
	embers.preprocess = 7.0
	embers.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	embers.emission_rect_extents = Vector2(size_px.x * 0.55, 6.0)
	embers.direction = Vector2(0.25, -1.0)
	embers.spread = 14.0
	embers.gravity = Vector2.ZERO
	embers.initial_velocity_min = 8.0
	embers.initial_velocity_max = 20.0
	embers.scale_amount_min = 1.0
	embers.scale_amount_max = 2.0
	embers.color = Color(1.0, 0.62, 0.28, 0.85)
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	fade.offsets = PackedFloat32Array([0.0, 0.2, 1.0])
	embers.color_ramp = fade
	embers.name = "Embers"
	return embers
