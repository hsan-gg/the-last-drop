class_name Ambience
extends Node2D
## Makes a region feel alive. Drawn over the ground in world space: ripples
## that drift across water, blades of grass that sway in the wind, bubbles and
## vapour over toxic puddles. Over the screen: whatever hangs in the air there
## (dust, ash, spores, smog, fireflies, rain, embers, seeds) and a slow,
## drifting haze of pollution. Each region picks its mix in data/areas.json
## ("ambience"). Only cells near the camera are drawn, so big maps stay cheap.

const WATER := "~"
const TOXIC := "T"
const GRASS := ","
const VIEW_MARGIN := 2
## name -> particle settings for the air layer.
const AIRS := {
	"dust": {"amount": 40, "color": Color(0.9, 0.8, 0.6, 0.35), "velocity": Vector2(26, 4), "size": [1.0, 2.0], "life": 6.0},
	"ash": {"amount": 36, "color": Color(0.85, 0.85, 0.85, 0.35), "velocity": Vector2(8, 14), "size": [1.0, 2.0], "life": 7.0},
	"spores": {"amount": 34, "color": Color(0.8, 0.6, 0.95, 0.45), "velocity": Vector2(6, -8), "size": [1.0, 2.5], "life": 8.0},
	"smog": {"amount": 22, "color": Color(0.55, 0.5, 0.4, 0.18), "velocity": Vector2(12, 0), "size": [8.0, 16.0], "life": 9.0},
	"fireflies": {"amount": 26, "color": Color(0.85, 1.0, 0.6, 0.9), "velocity": Vector2(0, -3), "size": [1.0, 1.5], "life": 6.0},
	"rain": {"amount": 90, "color": Color(0.6, 0.9, 0.7, 0.35), "velocity": Vector2(-30, 220), "size": [1.0, 1.0], "life": 1.6},
	"embers": {"amount": 30, "color": Color(1.0, 0.6, 0.25, 0.7), "velocity": Vector2(10, -20), "size": [1.0, 1.5], "life": 4.0},
	"seeds": {"amount": 18, "color": Color(1.0, 0.95, 0.8, 0.7), "velocity": Vector2(22, -4), "size": [1.0, 2.0], "life": 8.0},
	"flies": {"amount": 20, "color": Color(0.1, 0.1, 0.1, 0.8), "velocity": Vector2(0, 0), "size": [1.0, 1.0], "life": 3.0},
	"mist": {"amount": 16, "color": Color(0.8, 0.9, 0.95, 0.12), "velocity": Vector2(6, 0), "size": [10.0, 18.0], "life": 10.0},
}

var water_color := Color(0.8, 0.9, 0.85, 0.5)
var grass_color := Color(0.55, 0.6, 0.35)
var toxic_color := Color(0.6, 1.0, 0.4)
var _layout: PackedStringArray = PackedStringArray()
var _water: Array[Vector2i] = []
var _toxic: Array[Vector2i] = []
var _grass: Array[Vector2i] = []
var _time := 0.0
var _haze: TextureRect
var _air: CanvasLayer
var _has_fireflies := false


## Sets up the ambience for a layout from the area's config.
func setup(layout: PackedStringArray, config: Dictionary) -> void:
	_layout = layout
	for y in layout.size():
		for x in layout[y].length():
			match layout[y][x]:
				WATER:
					_water.append(Vector2i(x, y))
				TOXIC:
					_toxic.append(Vector2i(x, y))
				GRASS:
					_grass.append(Vector2i(x, y))
	var palette: Dictionary = config.get("ambience_colors", {})
	water_color = Color(palette.get("water", water_color.to_html()))
	grass_color = Color(palette.get("grass", grass_color.to_html()))
	toxic_color = Color(palette.get("toxic", toxic_color.to_html()))
	_air = CanvasLayer.new()
	_air.layer = 2
	add_child(_air)
	for air: String in config.get("ambience", ["ash"]):
		if AIRS.has(air):
			_air.add_child(_make_air(AIRS[air]))
	_has_fireflies = config.get("ambience", []).has("fireflies")
	var haze: Dictionary = config.get("haze", {})
	if not haze.is_empty():
		_air.add_child(_make_haze(Color(haze.get("color", "#6a6040")), float(haze.get("alpha", 0.12))))


## The region's lights are back on: the pollution haze thins away and, if the
## region has them, fireflies come out.
func clear_air() -> void:
	if _haze != null:
		var tween := create_tween()
		tween.tween_property(_haze, "modulate:a", 0.015, 6.0).set_trans(Tween.TRANS_SINE)
	if _air != null and not _has_fireflies:
		_has_fireflies = true
		var fireflies := _make_air(AIRS["fireflies"])
		fireflies.amount = 14
		_air.add_child(fireflies)


func counts() -> Dictionary:
	return {"water": _water.size(), "toxic": _toxic.size(), "grass": _grass.size(), "airs": _air.get_child_count() if _air != null else 0}


func _process(delta: float) -> void:
	_time += delta
	if _haze != null:
		_haze.position = Vector2(fposmod(-_time * 6.0, 256.0) - 256.0, fposmod(-_time * 2.0, 256.0) - 256.0)
	queue_redraw()


func _view_cells() -> Rect2i:
	var camera := get_viewport().get_camera_2d()
	var size := get_viewport_rect().size
	var centre := camera.get_screen_center_position() if camera != null else size / 2.0
	var top_left := Vector2i(((centre - size / 2.0) / MapBuilder.TILE_SIZE).floor()) - Vector2i(VIEW_MARGIN, VIEW_MARGIN)
	var cells := Vector2i((size / MapBuilder.TILE_SIZE).ceil()) + Vector2i(VIEW_MARGIN, VIEW_MARGIN) * 2
	return Rect2i(top_left, cells)


func _draw() -> void:
	var view := _view_cells()
	var tile := float(MapBuilder.TILE_SIZE)
	for cell in _water:
		if view.has_point(cell):
			_draw_water(Vector2(cell) * tile, cell)
	for cell in _toxic:
		if view.has_point(cell):
			_draw_toxic(Vector2(cell) * tile, cell)
	for cell in _grass:
		if view.has_point(cell):
			_draw_grass(Vector2(cell) * tile, cell)


## Ripples drifting along with the current, and a glint now and then.
func _draw_water(at: Vector2, cell: Vector2i) -> void:
	var phase := float(cell.x * 7 + cell.y * 13)
	for row in 3:
		var y := 3.0 + row * 5.0 + sin(_time * 1.5 + phase + row) * 0.6
		var x := fposmod(_time * (10.0 + row * 4.0) + phase * 3.0, 20.0) - 4.0
		draw_line(at + Vector2(x, y), at + Vector2(minf(x + 5.0, 16.0), y), water_color, 1.0)
	if fposmod(_time * 0.7 + phase * 0.13, 4.0) < 0.15:
		draw_rect(Rect2(at + Vector2(6 + int(phase) % 5, 7), Vector2(2, 1)), Color(1, 1, 1, 0.7))


## Bubbles that rise and pop, and a breath of vapour.
func _draw_toxic(at: Vector2, cell: Vector2i) -> void:
	var phase := float(cell.x * 5 + cell.y * 11)
	for bubble in 2:
		var cycle := fposmod(_time * 0.9 + phase * 0.31 + bubble * 0.5, 1.0)
		var spot := at + Vector2(4.0 + bubble * 7.0 + sin(phase) * 2.0, 12.0 - cycle * 6.0)
		draw_circle(spot, 0.8 + cycle * 1.2, Color(toxic_color.r, toxic_color.g, toxic_color.b, 0.8 * (1.0 - cycle)))
	var rise := fposmod(_time * 0.5 + phase * 0.17, 1.0)
	draw_circle(at + Vector2(8.0 + sin(_time + phase) * 3.0, 6.0 - rise * 12.0), 2.0 + rise * 3.0, Color(toxic_color.r, toxic_color.g, toxic_color.b, 0.15 * (1.0 - rise)))


## A few blades that lean with the wind, each a little out of step.
func _draw_grass(at: Vector2, cell: Vector2i) -> void:
	var phase := float(cell.x * 3 + cell.y * 7)
	var wind := sin(_time * 1.8 + cell.x * 0.35) * 1.6 + sin(_time * 0.7) * 0.8
	for blade in 3:
		var root := at + Vector2(3.0 + blade * 5.0 + fmod(phase, 2.0), 15.0)
		var height := 5.0 + fmod(phase + blade * 3.0, 4.0)
		draw_line(root, root + Vector2(wind * (0.6 + blade * 0.2), -height), grass_color if blade != 1 else grass_color.lightened(0.15), 1.0)


func _make_air(spec: Dictionary) -> CPUParticles2D:
	var size := get_viewport_rect().size
	var air := CPUParticles2D.new()
	air.amount = int(spec["amount"])
	air.lifetime = float(spec["life"])
	air.preprocess = float(spec["life"])
	air.position = size / 2.0
	air.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	air.emission_rect_extents = size * 0.65
	var velocity: Vector2 = spec["velocity"]
	air.direction = velocity.normalized() if velocity != Vector2.ZERO else Vector2.RIGHT
	air.spread = 25.0 if velocity != Vector2.ZERO else 180.0
	air.initial_velocity_min = velocity.length() * 0.6 if velocity != Vector2.ZERO else 4.0
	air.initial_velocity_max = velocity.length() * 1.2 if velocity != Vector2.ZERO else 12.0
	air.gravity = Vector2.ZERO
	var big := float(spec["size"][1]) > 4.0
	if big:  # clouds of mist and smog are soft puffs, not squares
		air.texture = _puff_texture()
		air.scale_amount_min = float(spec["size"][0]) / 8.0
		air.scale_amount_max = float(spec["size"][1]) / 8.0
	else:
		air.scale_amount_min = float(spec["size"][0])
		air.scale_amount_max = float(spec["size"][1])
	air.color = spec["color"]
	var fade := Gradient.new()
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 1), Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
	fade.offsets = PackedFloat32Array([0.0, 0.15, 0.8, 1.0])
	air.color_ramp = fade
	return air


static var _puff: GradientTexture2D


static func _puff_texture() -> GradientTexture2D:
	if _puff == null:
		var gradient := Gradient.new()
		gradient.colors = PackedColorArray([Color.WHITE, Color(1, 1, 1, 0)])
		_puff = GradientTexture2D.new()
		_puff.gradient = gradient
		_puff.width = 16
		_puff.height = 16
		_puff.fill = GradientTexture2D.FILL_RADIAL
		_puff.fill_from = Vector2(0.5, 0.5)
		_puff.fill_to = Vector2(1.0, 0.5)
	return _puff


## A soft, slowly drifting cloud of colour over everything: the pollution you breathe.
func _make_haze(color: Color, alpha: float) -> TextureRect:
	var noise := FastNoiseLite.new()
	noise.frequency = 0.012
	noise.fractal_octaves = 3
	var texture := NoiseTexture2D.new()
	texture.width = 256
	texture.height = 256
	texture.seamless = true
	texture.noise = noise
	_haze = TextureRect.new()
	_haze.texture = texture
	_haze.stretch_mode = TextureRect.STRETCH_TILE
	_haze.size = get_viewport_rect().size + Vector2(512, 512)
	_haze.modulate = Color(color.r, color.g, color.b, alpha)
	_haze.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return _haze
