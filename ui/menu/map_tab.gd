class_name MapTab
extends MenuTab
## The map, drawn like a hand-inked parchment chart (after Stardew Valley's).
## Two pages, switched with Left/Right:
## - AREA: the place you are in, inked from its layout, with clouds of hatching
##   where you have not been yet, little icons for gates, chests, the generator,
##   errands and the objective, and your face as the pin.
## - WORLD: the whole journey on one sheet: each region a painted vignette on
##   the road north, lit regions glowing, unknown ones under cloud, a "!" where
##   an errand waits, and your pin on the region you are in.

enum Page { AREA, WORLD }

const AREA_NAMES := {"outpost": "Forgotten Outpost", "factory": "Battery Factory", "dump": "Great Dump", "river": "Dead River"}
## Region spots on the world sheet, as fractions of the sheet, in story order.
const WORLD: Array[Dictionary] = [
	{"id": "outpost", "name": "Outpost", "at": Vector2(0.14, 0.78)},
	{"id": "factory", "name": "Battery Factory", "at": Vector2(0.32, 0.42)},
	{"id": "dump", "name": "Great Dump", "at": Vector2(0.52, 0.72)},
	{"id": "river", "name": "Dead River", "at": Vector2(0.68, 0.34)},
	{"id": "fields", "name": "???", "at": Vector2(0.86, 0.62)},
	{"id": "sanctuary", "name": "???", "at": Vector2(0.9, 0.18)},
]
const MARKERS := [
	{"group": "scene_chest", "icon": "chest"},
	{"group": "scene_repair_station", "icon": "repair"},
	{"group": "scene_archive_terminal", "icon": "terminal"},
	{"group": "scene_region_generator", "icon": "generator"},
]

var page := Page.AREA
var _layout: PackedStringArray = PackedStringArray()
var _area_id := ""
var _time := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func refresh() -> void:
	var scene := get_tree().current_scene
	_area_id = (scene as GameArea).area_id if scene is GameArea else ""
	_layout = MapBuilder.load_layout(Content.area(_area_id).get("layout", "")) if not _area_id.is_empty() else PackedStringArray()
	queue_redraw()


func tab_input(event: InputEvent) -> bool:
	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_right"):
		page = Page.WORLD if page == Page.AREA else Page.AREA
		EventBus.sfx_requested.emit("click")
		queue_redraw()
		return true
	return false


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_time += delta
		queue_redraw()


## Pixels per map cell so the whole area fits the drawing space.
func cell_size(map_size: Vector2i, space: Vector2) -> int:
	if map_size.x <= 0 or map_size.y <= 0:
		return 1
	return maxi(mini(int(space.x) / map_size.x, int(space.y) / map_size.y), 1)


## Regions with an errand still waiting, for the "!" marks on the world page.
static func regions_with_errands() -> Array[String]:
	var waiting: Array[String] = []
	for request_id in ["radio", "garden", "fountain"]:
		var request := Content.request(request_id)
		if not request.is_empty() and not GameState.has_flag(RequestPoint.done_flag(request_id)) and MapMemory.has_visited(request["area"]):
			if not waiting.has(request["area"]):
				waiting.append(request["area"])
	return waiting


func _draw() -> void:
	var sheet := Rect2(Vector2(2, 14), size - Vector2(4, 16))
	MapPaint.parchment(self, sheet)
	var font := UiTheme.FONT_FILE as Font
	var header := "< AREA  |  world >" if page == Page.AREA else "< area  |  WORLD >"
	draw_string(font, Vector2(4, 9), header, HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiTheme.COLOR_YELLOW)
	draw_string(font, Vector2(size.x - 196, 9), "Left / Right: switch page", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiTheme.COLOR_MUTED)
	if page == Page.WORLD:
		_draw_world(sheet.grow(-8))
	else:
		_draw_area(sheet.grow(-8))


# ------------------------------------------------------------------ area page

func _draw_area(space: Rect2) -> void:
	if _layout.is_empty():
		MapPaint.banner(self, space.get_center(), "No map here")
		return
	var map_size := MapBuilder.layout_size(_layout)
	var cell := cell_size(map_size, Vector2(space.size.x - 110.0, space.size.y - 14.0))
	var origin := space.position + Vector2(0, 12)
	for y in map_size.y:
		for x in map_size.x:
			_draw_cell(origin, cell, x, y)
	draw_rect(Rect2(origin, Vector2(map_size) * cell), MapPaint.INK, false, 1.0)
	MapPaint.banner(self, origin + Vector2(map_size.x * cell / 2.0, -5), String(AREA_NAMES.get(_area_id, _area_id.capitalize())))
	_draw_area_markers(origin, cell)
	MapPaint.compass(self, origin + Vector2(map_size.x * cell - 12, 14))
	_draw_legend(Vector2(origin.x + map_size.x * cell + 10, origin.y + 2))


func _draw_cell(origin: Vector2, cell: int, x: int, y: int) -> void:
	var rect := Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell))
	if not MapMemory.is_seen(_area_id, Vector2i(x, y)):
		draw_rect(rect, MapPaint.FOG)
		if (x + y) % 3 == 0:  # hatching, like clouds sketched over the unknown
			draw_line(rect.position + Vector2(0, cell), rect.position + Vector2(cell, 0), MapPaint.FOG_LINE, 1.0)
		return
	var ch := _layout[y][x]
	var color := MapPaint.PAPER
	if ch == "~":
		color = MapPaint.WATER
	elif ch == "T":
		color = MapPaint.TOXIC
	elif ch == "=":
		color = MapPaint.ROAD
	elif MapBuilder.is_solid_char(ch):
		color = MapPaint.INK_SOFT
	elif (x * 7 + y * 3) % 11 == 0:
		color = MapPaint.PAPER.darkened(0.04)
	draw_rect(rect, color)
	if MapBuilder.is_solid_char(ch) and y + 1 < _layout.size() and not MapBuilder.is_solid_char(_layout[y + 1][x]):
		draw_rect(Rect2(rect.position + Vector2(0, cell - 1), Vector2(cell, 1)), MapPaint.INK)


func _draw_area_markers(origin: Vector2, cell: int) -> void:
	var lit := GameState.has_flag(RegionGenerator.lit_flag(_area_id))
	for marker in MARKERS:
		for node in get_tree().get_nodes_in_group(marker["group"]):
			if node is Node2D and _node_seen(node as Node2D):
				MapPaint.icon(self, marker["icon"], _to_map(origin, cell, node as Node2D), _time, lit)
	for node in get_tree().get_nodes_in_group("scene_area_exit"):
		if node is AreaExit and _node_seen(node as Node2D):
			var gate := node as AreaExit
			MapPaint.icon(self, "gate" if not gate.required_flag.is_empty() else "back", _to_map(origin, cell, gate), _time, gate.is_open())
	for node in get_tree().get_nodes_in_group("scene_request_point"):
		if node is RequestPoint and not (node as RequestPoint).is_done() and _node_seen(node as Node2D):
			MapPaint.icon(self, "errand", _to_map(origin, cell, node as Node2D), _time)
	var hud := get_tree().current_scene.get_node_or_null("Hud") as Hud
	if hud != null and int(Settings.value("objective_hints")) > 0:
		var objective := ObjectivesTracker.current(hud.area_id)
		var target := ObjectiveBeacon.pick_target(objective.get("target", {}), get_tree().get_nodes_in_group("scene_%s" % objective.get("target", {}).get("scene", "")), Vector2.ZERO)
		if target != null:
			MapPaint.icon(self, "objective", _to_map(origin, cell, target), _time)
	for node in get_tree().get_nodes_in_group("player"):
		MapPaint.player_pin(self, _to_map(origin, cell, node as Node2D), _time)


func _to_map(origin: Vector2, cell: int, node: Node2D) -> Vector2:
	return origin + node.global_position / MapBuilder.TILE_SIZE * cell


func _node_seen(node: Node2D) -> bool:
	return MapMemory.is_seen(_area_id, Vector2i((node.global_position / MapBuilder.TILE_SIZE).floor()))


func _draw_legend(at: Vector2) -> void:
	var font := UiTheme.FONT_FILE as Font
	var y := at.y + 6
	var lit := GameState.has_flag(RegionGenerator.lit_flag(_area_id))
	for entry in [["objective", "Objective"], ["gate", "Gate on"], ["back", "Gate back"], ["generator", "Generator"], ["errand", "Errand"], ["chest", "Chest"], ["repair", "Repair"]]:
		MapPaint.icon(self, entry[0], Vector2(at.x + 5, y), _time, entry[0] == "generator" and lit)
		draw_string(font, Vector2(at.x + 14, y + 4), entry[1], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, MapPaint.INK)
		y += 14
	var total := MapBuilder.layout_size(_layout).x * MapBuilder.layout_size(_layout).y
	draw_string(font, Vector2(at.x, y + 6), "Explored %d%%" % int(MapMemory.fraction_seen(_area_id, total) * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, MapPaint.INK_SOFT)
	draw_string(font, Vector2(at.x, y + 20), "Lights: %s" % ("ON" if lit else "off"), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, MapPaint.GOLD if lit else MapPaint.INK_SOFT)


# ------------------------------------------------------------------ world page

func _draw_world(space: Rect2) -> void:
	var points: Array[Vector2] = []
	for region in WORLD:
		points.append(space.position + region["at"] * space.size)
	# the dead river winds across the sheet
	var river := PackedVector2Array()
	for step in 24:
		var t := float(step) / 23.0
		river.append(space.position + Vector2(t * space.size.x, space.size.y * (0.12 + 0.14 * sin(t * 5.0 + 0.6)) + t * space.size.y * 0.35))
	draw_polyline(river, MapPaint.WATER, 3.0)
	# the road north, dotted where you have not walked it yet
	for index in points.size() - 1:
		var walked := MapMemory.has_visited(WORLD[index + 1]["id"])
		_dotted(points[index], points[index + 1], MapPaint.INK if walked else MapPaint.INK_SOFT, walked)
	var errands := regions_with_errands()
	for index in WORLD.size():
		_draw_region(WORLD[index], points[index], errands.has(WORLD[index]["id"]))
	MapPaint.banner(self, space.position + Vector2(space.size.x * 0.5, 6), "The Way to the Last Drop")
	MapPaint.compass(self, space.end - Vector2(14, 14))


func _dotted(from: Vector2, to: Vector2, color: Color, solid: bool) -> void:
	var steps := int(from.distance_to(to) / 4.0)
	for step in steps:
		if solid or step % 2 == 0:
			draw_line(from.lerp(to, float(step) / steps), from.lerp(to, float(step + 1) / steps), color, 2.0 if solid else 1.0)


func _draw_region(region: Dictionary, at: Vector2, has_errand: bool) -> void:
	var id: String = region["id"]
	var known := MapMemory.has_visited(id)
	var lit := GameState.has_flag(RegionGenerator.lit_flag(id))
	if not known:
		for puff in 5:  # a cloud over the unknown
			draw_circle(at + Vector2(-12 + puff * 6, sin(puff * 1.7) * 3.0), 7.0, MapPaint.FOG)
		MapPaint.banner(self, at + Vector2(0, 16), "???", MapPaint.INK_SOFT)
		return
	if lit:
		var glow := 0.5 + 0.5 * sin(_time * 2.0)
		draw_circle(at, 18.0, Color(1.0, 0.85, 0.35, 0.18 + 0.1 * glow))
	_vignette(id, at)
	MapPaint.banner(self, at + Vector2(0, 17), region["name"], MapPaint.INK)
	if has_errand:
		MapPaint.icon(self, "errand", at + Vector2(14, -14), _time)
	if lit:
		MapPaint.icon(self, "generator", at + Vector2(-15, -12), _time, true)
	if id == _area_id:
		MapPaint.player_pin(self, at + Vector2(0, -6), _time)


## A small painted picture of each region.
func _vignette(id: String, at: Vector2) -> void:
	match id:
		"outpost":
			draw_rect(Rect2(at + Vector2(-9, -3), Vector2(18, 10)), Color("#a87a58"))
			draw_colored_polygon(PackedVector2Array([at + Vector2(-11, -3), at + Vector2(0, -12), at + Vector2(11, -3)]), Color("#6a4434"))
			draw_rect(Rect2(at + Vector2(-2, 1), Vector2(4, 6)), MapPaint.INK)
		"factory":
			draw_rect(Rect2(at + Vector2(-12, -4), Vector2(24, 12)), Color("#7a7a8c"))
			draw_rect(Rect2(at + Vector2(-9, -14), Vector2(4, 10)), Color("#5a5a6c"))
			draw_rect(Rect2(at + Vector2(2, -11), Vector2(4, 7)), Color("#5a5a6c"))
			for window in 4:
				draw_rect(Rect2(at + Vector2(-9 + window * 5, 0), Vector2(3, 3)), Color("#c8e060"))
		"dump":
			draw_colored_polygon(PackedVector2Array([at + Vector2(-15, 8), at + Vector2(-5, -9), at + Vector2(2, -2), at + Vector2(8, -11), at + Vector2(15, 8)]), Color("#8a6a58"))
			for fleck in 6:
				draw_rect(Rect2(at + Vector2(-8 + fleck * 3, 2 - (fleck % 3) * 3), Vector2(2, 2)), [Color("#c84a3a"), Color("#5a8ac0"), Color("#e0c060")][fleck % 3])
		"river":
			for row in 3:
				draw_arc(at + Vector2(-6, -5 + row * 5), 4.0, PI, TAU, 8, MapPaint.WATER.darkened(0.2), 2.0)
				draw_arc(at + Vector2(2, -5 + row * 5), 4.0, 0.0, PI, 8, MapPaint.WATER.darkened(0.2), 2.0)
