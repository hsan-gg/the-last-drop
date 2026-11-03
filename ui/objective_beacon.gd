class_name ObjectiveBeacon
extends CanvasLayer
## Makes the current objective impossible to miss: a pulsing marker over its
## target in the world, and an arrow on the screen edge when it is off-screen.

const COLOR := Color("#ffb347")
const EDGE_MARGIN := 16.0
const BOB_PIXELS := 3.0
const MARKER_LIFT := 26.0

var _canvas: Control
var _target: Node2D
var _time := 0.0


func _ready() -> void:
	layer = 8
	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_beacon)
	add_child(_canvas)


func _process(delta: float) -> void:
	_time += delta
	var hud := get_parent() as Hud
	var objective := ObjectivesTracker.current(hud.area_id) if hud != null else {}
	_target = pick_target(objective.get("target", {}), get_tree().get_nodes_in_group("scene_%s" % objective.get("target", {}).get("scene", "")), _view_center())
	_canvas.queue_redraw()


## Does this node satisfy the target description from data/objectives.json?
static func matches(spec: Dictionary, node: Node) -> bool:
	var props: Dictionary = node.get_meta("props", {})
	for key: String in spec.get("props", {}):
		if props.get(key) != spec["props"][key]:
			return false
	var flag_format: String = spec.get("untested_flag", "")
	if not flag_format.is_empty():
		var value: String = str(props.get(spec.get("flag_prop", ""), ""))
		if GameState.has_flag(flag_format % value):
			return false
	return true


## The nearest matching node to `from`, or null.
static func pick_target(spec: Dictionary, candidates: Array, from: Vector2) -> Node2D:
	var best: Node2D = null
	var best_distance := INF
	for node: Node in candidates:
		if not node is Node2D or not is_instance_valid(node) or not matches(spec, node):
			continue
		var distance := (node as Node2D).global_position.distance_squared_to(from)
		if distance < best_distance:
			best_distance = distance
			best = node as Node2D
	return best


func _view_center() -> Vector2:
	var camera := get_viewport().get_camera_2d()
	return camera.get_screen_center_position() if camera != null else Vector2.ZERO


func _draw_beacon() -> void:
	if _target == null or not is_instance_valid(_target):
		return
	var screen_size := get_viewport().get_visible_rect().size
	var point := get_viewport().get_canvas_transform() * _target.global_position
	var pulse := 0.5 + 0.5 * sin(_time * 4.0)
	var inside := Rect2(Vector2.ZERO, screen_size).grow(-EDGE_MARGIN).has_point(point)
	if inside:
		_draw_marker(point + Vector2(0, -MARKER_LIFT + sin(_time * 5.0) * BOB_PIXELS), pulse)
	else:
		_draw_edge_arrow(point, screen_size, pulse)


func _draw_marker(tip: Vector2, pulse: float) -> void:
	var glow := Color(COLOR.r, COLOR.g, COLOR.b, 0.18 + 0.2 * pulse)
	_canvas.draw_circle(tip + Vector2(0, -6), 9.0 + 2.0 * pulse, glow)
	var chevron := PackedVector2Array([tip, tip + Vector2(-6, -8), tip + Vector2(0, -5), tip + Vector2(6, -8)])
	_canvas.draw_colored_polygon(chevron, COLOR)
	_canvas.draw_polyline(PackedVector2Array([chevron[0], chevron[1], chevron[2], chevron[3], chevron[0]]), Color("#2a1a10"), 1.0)


func _draw_edge_arrow(point: Vector2, screen_size: Vector2, pulse: float) -> void:
	var center := screen_size / 2.0
	var direction := (point - center).normalized()
	var limit := screen_size / 2.0 - Vector2(EDGE_MARGIN, EDGE_MARGIN)
	var scale := minf(limit.x / maxf(absf(direction.x), 0.001), limit.y / maxf(absf(direction.y), 0.001))
	var anchor := center + direction * scale
	var side := direction.orthogonal()
	var arrow := PackedVector2Array([anchor + direction * 7.0, anchor - direction * 5.0 + side * 6.0, anchor - direction * 2.0, anchor - direction * 5.0 - side * 6.0])
	_canvas.draw_circle(anchor, 10.0 + 2.0 * pulse, Color(COLOR.r, COLOR.g, COLOR.b, 0.2 + 0.15 * pulse))
	_canvas.draw_colored_polygon(arrow, COLOR)
