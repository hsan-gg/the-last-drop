class_name MapTab
extends MenuTab
## The map: the current area drawn from its layout, revealed as you explore
## (fog of war), with you, exits, chests and the objective marked, plus a strip
## showing how the regions connect.

const TILE_COLORS := {
	"#": Color("#6a3c3c"), "H": Color("#5a4a58"), "~": Color("#4a6a58"), "=": Color("#c8a078"),
	":": Color("#8a8a96"), "M": Color("#5c5870"), "D": Color("#403c52"), "F": Color("#4a4a5c"),
	"P": Color("#6a6a7c"), "S": Color("#5a5a6c"), "C": Color("#8a6a44"), "B": Color("#7a3c3c"),
	"T": Color("#5a8a48"), "t": Color("#5a4838"), "r": Color("#6a5a50"), ",": Color("#5a5040"),
	"b": Color("#463c4a"), ".": Color("#5a4a42"),
}
const UNSEEN := Color("#0a0e12")
const AREA_NAMES := {"outpost": "Forgotten Outpost", "factory": "Battery Factory", "dump": "Great Dump", "river": "Dead River"}
const REGIONS: Array[Dictionary] = [
	{"id": "outpost", "name": "OUTPOST"},
	{"id": "factory", "name": "FACTORY"},
	{"id": "dump", "name": "DUMP"},
	{"id": "river", "name": "RIVER"},
	{"id": "", "name": "???"},
]
const MARKERS := [
	{"group": "scene_area_exit", "color": Color("#7bc043"), "label": "Exit"},
	{"group": "scene_chest", "color": Color("#f2c94c"), "label": "Chest"},
	{"group": "scene_archive_terminal", "color": Color("#5fe0d0"), "label": "Terminal"},
	{"group": "scene_repair_station", "color": Color("#f08a24"), "label": "Repair"},
]

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


func _process(delta: float) -> void:
	if is_visible_in_tree():
		_time += delta
		queue_redraw()


## Pixels per map cell so the whole area fits the drawing space.
func cell_size(map_size: Vector2i, space: Vector2) -> int:
	if map_size.x <= 0 or map_size.y <= 0:
		return 1
	return maxi(mini(int(space.x) / map_size.x, int(space.y) / map_size.y), 1)


func _draw() -> void:
	if _layout.is_empty():
		draw_string(ThemeDB.fallback_font, Vector2(20, 40), "No map here.", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiTheme.COLOR_MUTED)
		return
	var map_size := MapBuilder.layout_size(_layout)
	var space := Vector2(size.x - 130.0, size.y - 28.0)
	var cell := cell_size(map_size, space)
	var origin := Vector2(4, 4)
	for y in map_size.y:
		for x in map_size.x:
			var seen := MapMemory.is_seen(_area_id, Vector2i(x, y))
			var color := UNSEEN
			if seen:
				color = TILE_COLORS.get(_layout[y][x], TILE_COLORS["."])
			draw_rect(Rect2(origin + Vector2(x, y) * cell, Vector2(cell, cell)), color)
	draw_rect(Rect2(origin, Vector2(map_size) * cell), Color("#31505c"), false, 1.0)
	_draw_markers(origin, cell)
	_draw_legend(origin + Vector2(map_size.x * cell + 10, 0))
	_draw_regions(Vector2(4, size.y - 20))


func _draw_markers(origin: Vector2, cell: int) -> void:
	var scene := get_tree().current_scene
	for marker in MARKERS:
		for node in get_tree().get_nodes_in_group(marker["group"]):
			if node is Node2D and _node_seen(node as Node2D):
				var point := origin + (node as Node2D).global_position / MapBuilder.TILE_SIZE * cell
				draw_rect(Rect2(point - Vector2(2, 2), Vector2(4, 4)), marker["color"])
	var hud := scene.get_node_or_null("Hud") as Hud
	if hud != null:
		var objective := ObjectivesTracker.current(hud.area_id)
		var target := ObjectiveBeacon.pick_target(objective.get("target", {}), get_tree().get_nodes_in_group("scene_%s" % objective.get("target", {}).get("scene", "")), Vector2.ZERO)
		if target != null and int(Settings.value("objective_hints")) > 0:
			var point := origin + target.global_position / MapBuilder.TILE_SIZE * cell
			var pulse := 0.5 + 0.5 * sin(_time * 4.0)
			draw_circle(point, 4.0 + 2.0 * pulse, Color(1.0, 0.7, 0.28, 0.5))
			draw_circle(point, 2.0, Color("#ffb347"))
	for node in get_tree().get_nodes_in_group("player"):
		var spot := origin + (node as Node2D).global_position / MapBuilder.TILE_SIZE * cell
		draw_circle(spot, 3.0, Color.WHITE if int(_time * 3.0) % 2 == 0 else Color("#ffd9a0"))


func _node_seen(node: Node2D) -> bool:
	return MapMemory.is_seen(_area_id, Vector2i((node.global_position / MapBuilder.TILE_SIZE).floor()))


func _draw_legend(at: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var y := at.y + 8
	draw_string(font, Vector2(at.x, y), String(AREA_NAMES.get(_area_id, _area_id.capitalize())).to_upper(), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiTheme.COLOR_YELLOW)
	y += 14
	var entries: Array[Dictionary] = [{"color": Color.WHITE, "label": "You"}, {"color": Color("#ffb347"), "label": "Objective"}]
	entries.append_array(MARKERS)
	for entry in entries:
		draw_rect(Rect2(at + Vector2(0, y - 12 - at.y + at.y), Vector2(5, 5)), entry["color"])
		draw_string(font, Vector2(at.x + 9, y - 6), entry["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiTheme.COLOR_TEXT)
		y += 12
	var total := MapBuilder.layout_size(_layout).x * MapBuilder.layout_size(_layout).y
	draw_string(font, Vector2(at.x, y + 6), "Explored %d%%" % int(MapMemory.fraction_seen(_area_id, total) * 100.0), HORIZONTAL_ALIGNMENT_LEFT, -1, 8, UiTheme.COLOR_MUTED)


## A strip of the regions in story order, the one you are in highlighted.
func _draw_regions(at: Vector2) -> void:
	var font := ThemeDB.fallback_font
	var x := at.x
	for region in REGIONS:
		var visited: bool = region["id"] != "" and MapMemory.has_visited(region["id"])
		var current: bool = region["id"] == _area_id
		var color := UiTheme.COLOR_YELLOW if current else (UiTheme.COLOR_TEAL if visited else Color("#3a4a54"))
		draw_rect(Rect2(Vector2(x, at.y), Vector2(58, 12)), color, false, 1.0)
		draw_string(font, Vector2(x + 4, at.y + 9), region["name"], HORIZONTAL_ALIGNMENT_LEFT, 52, 8, color)
		x += 62
		if region != REGIONS[-1]:
			draw_string(font, Vector2(x - 4, at.y + 9), ">", HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color("#3a4a54"))
