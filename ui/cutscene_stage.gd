class_name CutsceneStage
extends Control
## What a cutscene shows behind its words: the dusk skyline, a hand-drawn map
## of the journey that fills in region by region, or plain darkness.

const PAPER := Color("#14161c")
const GRID := Color("#1e232c")
const ROUTE := Color("#5a4a3a")
const ROUTE_LIT := Color("#f0a050")
const HIDDEN := Color("#2c343e")
const REGION_COLORS := {
	"outpost": Color("#c8a078"), "factory": Color("#8a8aa0"), "dump": Color("#a06a58"), "river": Color("#5a9a8a"),
	"fields": Color("#8a9a48"), "industry": Color("#a07050"), "sanctuary": Color("#6ad0e0"),
}
## Region positions on the 480x270 stage, in journey order.
const REGIONS: Array[Dictionary] = [
	{"id": "outpost", "name": "Outpost", "at": Vector2(52, 206)},
	{"id": "factory", "name": "Factory", "at": Vector2(130, 150)},
	{"id": "dump", "name": "Dump", "at": Vector2(212, 196)},
	{"id": "river", "name": "River", "at": Vector2(286, 128)},
	{"id": "fields", "name": "Fields", "at": Vector2(352, 176)},
	{"id": "industry", "name": "Industry", "at": Vector2(402, 100)},
	{"id": "sanctuary", "name": "Sanctuary", "at": Vector2(436, 44)},
]

## Scenes are composed above the caption box, so the action is never hidden behind it.
const SCENE_HEIGHT := 196.0

var mode := "black"
var focus: Array = []
## 0 to 1: how much of the route has been drawn.
var route_progress := 0.0:
	set(value):
		route_progress = value
		queue_redraw()

## Camera: zoom into the picture about its centre, and slide it sideways.
var zoom := 1.0
var pan := 0.0

var _backdrop: TitleBackdrop
var _time := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_beat(beat: Dictionary) -> void:
	mode = beat.get("visual", "black")
	focus = beat.get("focus", [])
	if _backdrop != null:
		_backdrop.queue_free()
		_backdrop = null
	if mode == "sky":
		_backdrop = TitleBackdrop.new()
		add_child(_backdrop)
	_time = 0.0
	queue_redraw()


## How many of the regions are lit for the current focus, in journey order.
func lit_count() -> int:
	var count := 0
	for region in REGIONS:
		if focus.has(region["id"]):
			count += 1
	return count


func _process(delta: float) -> void:
	_time += delta
	if mode == "map" or CutsceneScenes.has_scene(mode):
		queue_redraw()


func _draw() -> void:
	var stage := get_viewport_rect().size
	if mode == "black":
		draw_rect(Rect2(Vector2.ZERO, stage), Color.BLACK)
		return
	if mode == "sky":
		return
	if CutsceneScenes.has_scene(mode):
		draw_set_transform(Vector2(pan, 0.0) - stage * 0.5 * (zoom - 1.0), 0.0, Vector2(zoom, zoom))
		CutsceneScenes.draw(self, mode, Vector2(stage.x, SCENE_HEIGHT), _time)
		draw_rect(Rect2(0, SCENE_HEIGHT, stage.x, stage.y), Color("#0c0a10"))
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		if not focus.is_empty():
			_draw_inset(stage)
		return
	draw_rect(Rect2(Vector2.ZERO, stage), PAPER)
	for x in range(0, int(stage.x), 20):
		draw_line(Vector2(x, 0), Vector2(x, stage.y), GRID, 1.0)
	for y in range(0, int(stage.y), 20):
		draw_line(Vector2(0, y), Vector2(stage.x, y), GRID, 1.0)
	_draw_route()
	for region in REGIONS:
		_draw_region(region)


## The journey so far, as a small framed map in the corner of a scene.
func _draw_inset(stage: Vector2) -> void:
	const SCALE := 0.3
	var origin := Vector2(stage.x - 480.0 * SCALE - 10.0, 28.0)
	draw_rect(Rect2(origin - Vector2(3, 3), Vector2(480.0 * SCALE + 6.0, 270.0 * SCALE + 6.0)), Color(0.05, 0.07, 0.09, 0.95))
	draw_rect(Rect2(origin - Vector2(3, 3), Vector2(480.0 * SCALE + 6.0, 270.0 * SCALE + 6.0)), ROUTE_LIT, false, 1.0)
	draw_set_transform(origin, 0.0, Vector2(SCALE, SCALE))
	_draw_route()
	for region in REGIONS:
		_draw_region(region)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_route() -> void:
	var lit := lit_count()
	for index in REGIONS.size() - 1:
		var from: Vector2 = REGIONS[index]["at"]
		var to: Vector2 = REGIONS[index + 1]["at"]
		var reached := index + 1 < lit
		var color := ROUTE_LIT if reached else ROUTE
		var steps := 14
		for step in steps:
			if step % 2 == 0:
				var a := from.lerp(to, float(step) / steps)
				var b := from.lerp(to, float(step + 1) / steps)
				draw_line(a, b, color if reached else Color(color.r, color.g, color.b, 0.45), 2.0 if reached else 1.0)


func _draw_region(region: Dictionary) -> void:
	var id: String = region["id"]
	var at: Vector2 = region["at"]
	var lit := focus.has(id)
	var known := lit or focus.is_empty() and mode == "map" and false
	var color: Color = REGION_COLORS[id] if lit else HIDDEN
	var pulse := 0.5 + 0.5 * sin(_time * 3.0)
	if lit and id == focus[focus.size() - 1]:
		draw_circle(at, 14.0 + 3.0 * pulse, Color(color.r, color.g, color.b, 0.18))
		draw_arc(at, 16.0 + 3.0 * pulse, 0.0, TAU, 24, Color(color.r, color.g, color.b, 0.7), 1.0)
	_draw_icon(id, at, color)
	var label: String = region["name"] if lit else "???"
	draw_string(ThemeDB.fallback_font, at + Vector2(-26, 22), label, HORIZONTAL_ALIGNMENT_CENTER, 52, 8, color if lit else Color(color.r, color.g, color.b, 0.7))
	if known:
		pass


func _draw_icon(id: String, at: Vector2, color: Color) -> void:
	match id:
		"outpost":  # a small house
			draw_rect(Rect2(at + Vector2(-8, -3), Vector2(16, 10)), color)
			draw_colored_polygon(PackedVector2Array([at + Vector2(-10, -3), at + Vector2(0, -12), at + Vector2(10, -3)]), color.darkened(0.25))
		"factory":  # a block with chimneys
			draw_rect(Rect2(at + Vector2(-10, -4), Vector2(20, 12)), color)
			draw_rect(Rect2(at + Vector2(-8, -12), Vector2(4, 9)), color.darkened(0.25))
			draw_rect(Rect2(at + Vector2(2, -9), Vector2(4, 6)), color.darkened(0.25))
		"dump":  # a heap of rubbish
			draw_colored_polygon(PackedVector2Array([at + Vector2(-13, 8), at + Vector2(-4, -8), at + Vector2(3, -2), at + Vector2(8, -10), at + Vector2(14, 8)]), color)
		"river":  # waves
			for row in 3:
				draw_arc(at + Vector2(-6, -6 + row * 6), 4.0, PI, TAU, 8, color, 2.0)
				draw_arc(at + Vector2(2, -6 + row * 6), 4.0, 0.0, PI, 8, color, 2.0)
		"fields":  # crop rows
			for row in 4:
				draw_line(at + Vector2(-10, -7 + row * 5), at + Vector2(10, -7 + row * 5), color, 2.0)
		"industry":  # gear and stack
			draw_circle(at, 7.0, color)
			draw_circle(at, 3.0, PAPER)
			draw_rect(Rect2(at + Vector2(6, -12), Vector2(4, 12)), color.darkened(0.25))
		"sanctuary":  # a dome with a drop
			draw_circle(at + Vector2(0, 4), 11.0, color.darkened(0.3))
			draw_rect(Rect2(at + Vector2(-12, 4), Vector2(24, 7)), PAPER)
			draw_colored_polygon(PackedVector2Array([at + Vector2(0, -6), at + Vector2(-4, 2), at + Vector2(4, 2)]), color)
