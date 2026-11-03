class_name CutsceneScenes
extends RefCounted
## Animated pixel "postcards" for the cutscenes, drawn from shapes so they cost
## no art and always fit the 480x270 stage: ruined skyline, the outpost at dawn,
## the leaking factory, the great dump, the dead river and the spring. Each is a
## few parallax layers that drift, plus small living details (smoke, embers,
## crows, glints) so a still moment never looks still.

const SCENES: Array[String] = ["ruins", "outpost", "factory", "dump", "river", "spring"]
const BAND := 6.0


static func has_scene(kind: String) -> bool:
	return SCENES.has(kind)


## Draws scene `kind` for time `t` seconds into the beat.
static func draw(canvas: CanvasItem, kind: String, size: Vector2, t: float) -> void:
	match kind:
		"ruins":
			_sky(canvas, size, Color("#f08a4a"), Color("#2a1c3a"), 0.78)
			_sun(canvas, Vector2(size.x * 0.7, size.y * 0.5), 26.0, Color("#ffd08a"), t)
			_skyline(canvas, size, t, Color("#5a3a4a"), 0.55, 6.0, 40.0, 0.62)
			_skyline(canvas, size, t, Color("#2e2036"), 1.0, 12.0, 60.0, 0.78)
			_debris(canvas, size, t, Color("#c8a078"))
			_ground(canvas, size, Color("#1a1420"), 0.9)
		"outpost":
			_sky(canvas, size, Color("#7ac0c8"), Color("#f4b48a"), 0.7)
			_skyline(canvas, size, t, Color("#8a7a86"), 0.4, 4.0, 26.0, 0.66)
			_ground(canvas, size, Color("#4a3a34"), 0.72)
			_pipeline(canvas, size, t)
			_hut(canvas, Vector2(size.x * 0.3, size.y * 0.72))
			_campfire(canvas, Vector2(size.x * 0.52, size.y * 0.76), t)
			_sleeper(canvas, Vector2(size.x * 0.62, size.y * 0.78), t)
			_embers(canvas, Vector2(size.x * 0.52, size.y * 0.74), t, Color("#ffb050"))
		"factory":
			_sky(canvas, size, Color("#46503e"), Color("#161c18"), 0.8)
			_skyline(canvas, size, t, Color("#2a3228"), 0.6, 5.0, 30.0, 0.66)
			_ground(canvas, size, Color("#10160f"), 0.78)
			_factory(canvas, size, t)
			_leak(canvas, size, t)
		"dump":
			_sky(canvas, size, Color("#a86a4a"), Color("#2a1c1c"), 0.7)
			_heaps(canvas, size, t)
			_crows(canvas, size, t)
			_eyes(canvas, Vector2(size.x * 0.64, size.y * 0.6), t)
		"river":
			_sky(canvas, size, Color("#8a8a70"), Color("#2c3028"), 0.5)
			_dead_trees(canvas, size, t)
			_river(canvas, size, t)
		"spring":
			_sky(canvas, size, Color("#10243c"), Color("#04101c"), 1.0)
			_stars(canvas, size, t)
			_spring(canvas, size, t)


# ------------------------------------------------------------------ helpers

static func _hash(index: int) -> float:
	return fposmod(sin(float(index) * 12.9898) * 43758.5453, 1.0)


static func _sky(canvas: CanvasItem, size: Vector2, top: Color, bottom: Color, horizon: float) -> void:
	var height := size.y * horizon
	var bands := int(ceil(height / BAND))
	for band in bands:
		var ratio := float(band) / maxf(bands - 1, 1)
		canvas.draw_rect(Rect2(0, band * BAND, size.x, BAND + 1.0), top.lerp(bottom, ratio))
	canvas.draw_rect(Rect2(0, height, size.x, size.y - height), bottom)


static func _ground(canvas: CanvasItem, size: Vector2, color: Color, from_ratio: float) -> void:
	canvas.draw_rect(Rect2(0, size.y * from_ratio, size.x, size.y), color)
	canvas.draw_rect(Rect2(0, size.y * from_ratio, size.x, 2), color.lightened(0.15))


static func _sun(canvas: CanvasItem, at: Vector2, radius: float, color: Color, t: float) -> void:
	canvas.draw_circle(at, radius * 2.2, Color(color.r, color.g, color.b, 0.12 + 0.03 * sin(t * 1.5)))
	canvas.draw_circle(at, radius * 1.5, Color(color.r, color.g, color.b, 0.2))
	canvas.draw_circle(at, radius, color)


static func _stars(canvas: CanvasItem, size: Vector2, t: float) -> void:
	for index in 60:
		var blink := 0.5 + 0.5 * sin(t * (1.0 + _hash(index) * 2.0) + index)
		var at := Vector2(floorf(_hash(index + 100) * size.x), floorf(_hash(index + 200) * size.y * 0.8))
		canvas.draw_rect(Rect2(at, Vector2(1, 1)), Color(1, 1, 1, 0.3 + 0.6 * blink))


## A row of tall, broken buildings that drifts sideways (parallax).
static func _skyline(canvas: CanvasItem, size: Vector2, t: float, color: Color, depth: float, speed: float, max_height: float, base_ratio: float) -> void:
	var base := size.y * base_ratio
	var width := 22.0
	var count := int(size.x / width) + 3
	var shift := fposmod(t * speed * depth, width)
	for index in count:
		var seed_index := index + int(depth * 40.0)
		var height := 14.0 + _hash(seed_index) * max_height
		var x := index * width - shift - width
		var top := base - height
		canvas.draw_rect(Rect2(floorf(x), floorf(top), width - 2.0, height + size.y), color)
		if _hash(seed_index + 7) > 0.5:  # a broken, sloped roofline
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(x, top), Vector2(x + width - 2.0, top), Vector2(x + width - 2.0, top - 6.0 - _hash(seed_index + 3) * 6.0)]), color)
		if depth > 0.8:
			for row in int(height / 9.0):
				if _hash(seed_index * 31 + row) > 0.72:
					canvas.draw_rect(Rect2(floorf(x) + 4, floorf(top) + 4 + row * 9, 3, 3), Color("#f0b060", 0.5 + 0.4 * sin(t * 2.0 + index)))


static func _debris(canvas: CanvasItem, size: Vector2, t: float, color: Color) -> void:
	for index in 26:
		var speed := 14.0 + _hash(index) * 30.0
		var y := fposmod(t * speed + _hash(index + 50) * size.y, size.y)
		var x := fposmod(_hash(index + 90) * size.x + sin(t + index) * 8.0, size.x)
		var piece := 1.0 + floorf(_hash(index + 20) * 3.0)
		canvas.draw_rect(Rect2(floorf(x), floorf(y), piece, piece), Color(color.r, color.g, color.b, 0.35 + 0.4 * _hash(index)))


static func _pipeline(canvas: CanvasItem, size: Vector2, t: float) -> void:
	var y := size.y * 0.72
	canvas.draw_rect(Rect2(size.x * 0.66, y - 5, size.x * 0.34, 5), Color("#6a6a78"))
	canvas.draw_rect(Rect2(size.x * 0.66, y - 5, size.x * 0.34, 1), Color("#9a9aa8"))
	for post in 4:
		canvas.draw_rect(Rect2(size.x * 0.7 + post * 38.0, y, 3, 8), Color("#3a3036"))
	var pulse := fposmod(t * 40.0, size.x * 0.34)
	canvas.draw_rect(Rect2(size.x * 0.66 + pulse, y - 4, 6, 3), Color("#7ae0ff", 0.55))


static func _hut(canvas: CanvasItem, at: Vector2) -> void:
	canvas.draw_rect(Rect2(at + Vector2(-26, -26), Vector2(52, 26)), Color("#6a5448"))
	canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(-32, -26), at + Vector2(0, -46), at + Vector2(32, -26)]), Color("#3e2e2c"))
	canvas.draw_rect(Rect2(at + Vector2(-6, -18), Vector2(12, 18)), Color("#241a1a"))
	canvas.draw_rect(Rect2(at + Vector2(-20, -20), Vector2(8, 8)), Color("#f0c070"))


static func _campfire(canvas: CanvasItem, at: Vector2, t: float) -> void:
	canvas.draw_circle(at, 24.0 + 3.0 * sin(t * 9.0), Color("#ff9a40", 0.14))
	canvas.draw_rect(Rect2(at + Vector2(-7, 0), Vector2(14, 3)), Color("#4a2e20"))
	var flick := 6.0 + 2.0 * sin(t * 13.0) + sin(t * 7.0)
	canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(-5, 0), at + Vector2(0, -flick - 6.0), at + Vector2(5, 0)]), Color("#ff7a20"))
	canvas.draw_colored_polygon(PackedVector2Array([at + Vector2(-3, 0), at + Vector2(0, -flick), at + Vector2(3, 0)]), Color("#ffd060"))


## The player, curled up by the fire; they stir and sit up as the beat goes on.
static func _sleeper(canvas: CanvasItem, at: Vector2, t: float) -> void:
	var rise := clampf((t - 1.2) * 0.6, 0.0, 1.0) * 7.0
	canvas.draw_rect(Rect2(at + Vector2(-9, -4 - rise), Vector2(18, 5 + rise)), Color("#3a5a6a"))
	canvas.draw_rect(Rect2(at + Vector2(-12, -8 - rise), Vector2(7, 7)), Color("#e0b890"))
	if fposmod(t, 3.0) < 2.8:
		canvas.draw_rect(Rect2(at + Vector2(-10, -6 - rise), Vector2(1, 1)), Color("#1a1218"))


static func _embers(canvas: CanvasItem, at: Vector2, t: float, color: Color) -> void:
	for index in 14:
		var age := fposmod(t * (0.5 + _hash(index) * 0.5) + _hash(index + 5), 1.0)
		var p := at + Vector2(sin(age * 6.0 + index) * 8.0, -age * 80.0)
		canvas.draw_rect(Rect2(floorf(p.x), floorf(p.y), 1, 1), Color(color.r, color.g, color.b, 1.0 - age))


static func _factory(canvas: CanvasItem, size: Vector2, t: float) -> void:
	var base := size.y * 0.78
	canvas.draw_rect(Rect2(size.x * 0.2, base - 70, size.x * 0.5, 70), Color("#232a22"))
	for window in 8:
		var lit := _hash(window + 4) > 0.45 and sin(t * 3.0 + window * 2.0) > -0.6
		canvas.draw_rect(Rect2(size.x * 0.23 + window * 28.0, base - 54, 10, 8), Color("#b6e060") if lit else Color("#10140e"))
	for chimney in 3:
		var x := size.x * 0.28 + chimney * 62.0
		canvas.draw_rect(Rect2(x, base - 118 + chimney * 8, 14, 50 - chimney * 8), Color("#2e362c"))
		for puff in 7:
			var age := fposmod(t * 0.35 + puff / 7.0 + chimney * 0.3, 1.0)
			var p := Vector2(x + 7.0 + sin(age * 5.0) * 6.0 + age * 24.0, base - 118 + chimney * 8 - age * 70.0)
			canvas.draw_circle(p, 4.0 + age * 9.0, Color(0.5, 0.56, 0.46, 0.35 * (1.0 - age)))


static func _leak(canvas: CanvasItem, size: Vector2, t: float) -> void:
	var base := size.y * 0.78
	canvas.draw_rect(Rect2(size.x * 0.3, base + 6, size.x * 0.4, 14), Color("#7ae03a", 0.35 + 0.1 * sin(t * 2.0)))
	for drop in 5:
		var age := fposmod(t * 0.8 + drop * 0.2, 1.0)
		canvas.draw_rect(Rect2(size.x * 0.34 + drop * 26.0, base - 6 + age * 14, 2, 3), Color("#9aff50"))
	for barrel in 3:
		canvas.draw_rect(Rect2(size.x * 0.74 + barrel * 14.0, base - 12, 11, 12), Color("#6a3a2a"))
		canvas.draw_rect(Rect2(size.x * 0.74 + barrel * 14.0, base - 8, 11, 2), Color("#9aff50"))


static func _heaps(canvas: CanvasItem, size: Vector2, t: float) -> void:
	var base := size.y * 0.8
	for layer in 2:
		var color := Color("#4a3430") if layer == 0 else Color("#2e201e")
		var shift := t * (3.0 + layer * 5.0)
		for peak in 5:
			var cx := fposmod(peak * 120.0 - shift, size.x + 160.0) - 80.0
			var h := 70.0 + _hash(peak + layer * 9) * 60.0 - layer * 20.0
			canvas.draw_colored_polygon(PackedVector2Array([Vector2(cx - 90, base), Vector2(cx, base - h), Vector2(cx + 90, base)]), color)
			for fleck in 14:
				var fx := cx + (_hash(fleck + peak * 20) - 0.5) * 90.0
				var fy := base - _hash(fleck + 70 + peak) * h * 0.8
				canvas.draw_rect(Rect2(floorf(fx), floorf(fy), 2, 2), [Color("#c8a078"), Color("#7ab0c0"), Color("#d05a4a")][fleck % 3])
	canvas.draw_rect(Rect2(0, base, size.x, size.y), Color("#1c1414"))


static func _crows(canvas: CanvasItem, size: Vector2, t: float) -> void:
	for crow in 4:
		var x := fposmod(t * (22.0 + crow * 6.0) + crow * 130.0, size.x + 40.0) - 20.0
		var y := 34.0 + crow * 18.0 + sin(t * 2.0 + crow) * 5.0
		var flap := sin(t * 9.0 + crow) * 3.0
		canvas.draw_line(Vector2(x - 5, y + flap), Vector2(x, y), Color("#120c10"), 1.0)
		canvas.draw_line(Vector2(x, y), Vector2(x + 5, y + flap), Color("#120c10"), 1.0)


## Something hungry watches from the dark: eyes that blink.
static func _eyes(canvas: CanvasItem, at: Vector2, t: float) -> void:
	if fposmod(t, 3.4) > 3.1:
		return
	var glow := 0.6 + 0.4 * sin(t * 4.0)
	canvas.draw_rect(Rect2(at + Vector2(-5, 0), Vector2(3, 2)), Color(1.0, 0.2, 0.15, glow))
	canvas.draw_rect(Rect2(at + Vector2(3, 0), Vector2(3, 2)), Color(1.0, 0.2, 0.15, glow))


static func _dead_trees(canvas: CanvasItem, size: Vector2, t: float) -> void:
	for tree in 6:
		var x := fposmod(tree * 90.0 - t * 4.0, size.x + 80.0) - 40.0
		var base := size.y * 0.55
		var h := 40.0 + _hash(tree) * 30.0
		canvas.draw_rect(Rect2(floorf(x), base - h, 3, h), Color("#2a2620"))
		canvas.draw_line(Vector2(x + 1, base - h * 0.6), Vector2(x - 10, base - h * 0.85), Color("#2a2620"), 2.0)
		canvas.draw_line(Vector2(x + 1, base - h * 0.4), Vector2(x + 11, base - h * 0.7), Color("#2a2620"), 2.0)


static func _river(canvas: CanvasItem, size: Vector2, t: float) -> void:
	var top := size.y * 0.55
	var bands := int((size.y - top) / 5.0)
	for band in bands:
		var ratio := float(band) / bands
		var color := Color("#5a4a30").lerp(Color("#2a2418"), ratio)
		canvas.draw_rect(Rect2(0, top + band * 5.0, size.x, 6), color)
		var offset := fposmod(t * (14.0 + ratio * 40.0) + band * 17.0, 60.0)
		for streak in 9:
			canvas.draw_rect(Rect2(streak * 60.0 - offset, top + band * 5.0 + 2, 18, 1), color.lightened(0.18))
	var glint := clampf((t - 2.0) * 0.5, 0.0, 1.0)  # a patch of clean water spreads in
	if glint > 0.0:
		canvas.draw_circle(Vector2(size.x * 0.5, size.y * 0.78), 6.0 + glint * 46.0, Color("#6ad0e8", 0.28 * glint))
		canvas.draw_arc(Vector2(size.x * 0.5, size.y * 0.78), 8.0 + glint * 46.0, 0.0, TAU, 28, Color("#bff4ff", 0.6 * glint), 1.0)


static func _spring(canvas: CanvasItem, size: Vector2, t: float) -> void:
	var centre := Vector2(size.x * 0.5, size.y * 0.42)
	var pulse := 1.0 + 0.08 * sin(t * 2.5)
	for ray in 14:
		var angle := ray * TAU / 14.0 + t * 0.2
		canvas.draw_line(centre + Vector2.from_angle(angle) * 26.0, centre + Vector2.from_angle(angle) * (60.0 + 10.0 * sin(t * 2.0 + ray)), Color("#8aeaff", 0.18), 2.0)
	canvas.draw_circle(centre, 40.0 * pulse, Color("#6ad0e8", 0.14))
	canvas.draw_circle(centre, 26.0 * pulse, Color("#6ad0e8", 0.28))
	var drop := PackedVector2Array([centre + Vector2(0, -22 * pulse), centre + Vector2(-13 * pulse, 6), centre + Vector2(-8 * pulse, 16 * pulse), centre + Vector2(8 * pulse, 16 * pulse), centre + Vector2(13 * pulse, 6)])
	canvas.draw_colored_polygon(drop, Color("#c8f6ff"))
	canvas.draw_rect(Rect2(centre + Vector2(-6, -2), Vector2(3, 8)), Color.WHITE)
	for bubble in 16:
		var age := fposmod(t * 0.3 + _hash(bubble), 1.0)
		var p := Vector2(size.x * (0.2 + 0.6 * _hash(bubble + 30)) + sin(age * 7.0 + bubble) * 6.0, size.y - age * size.y)
		canvas.draw_rect(Rect2(floorf(p.x), floorf(p.y), 2, 2), Color("#bff4ff", 0.6 * (1.0 - age)))
	canvas.draw_rect(Rect2(0, size.y * 0.86, size.x, size.y), Color("#0a2438"))
	for wave in 8:
		canvas.draw_rect(Rect2(fposmod(wave * 70.0 + t * 12.0, size.x + 40.0) - 20.0, size.y * 0.88 + (wave % 3) * 6.0, 26, 1), Color("#5ac0e0", 0.6))
