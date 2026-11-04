class_name TouchPad
extends Control
## Draws the on-screen controls that TouchControls lays out: round glassy
## buttons with small pixel icons, and the floating stick. It also swallows
## the mouse clicks that touches are mirrored into, but only over a button, so
## a tap on a button never reaches the panel underneath while a tap anywhere
## else still does.

const RUNE_ICONS := preload("res://assets/sprites/icons/runes.png")
const RUNE_ICON := 12
const INK := Color("#f6ecd6")
const FACE := Color("#16202a")
const RIM := Color("#8fb8c8")
const LIT := Color("#ffd166")

var controls: Node


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP


func _has_point(point: Vector2) -> bool:
	return controls != null and not controls.button_at(point).is_empty()


func _draw() -> void:
	if controls == null:
		return
	var alpha := clampf(float(Settings.value("touch_opacity")), 0.2, 1.0)
	if controls.mode == controls.Mode.PLAY:
		_draw_stick(alpha)
	for button: Dictionary in controls.buttons:
		_draw_button(button, alpha)


func _draw_stick(alpha: float) -> void:
	var radius: float = controls.STICK_RADIUS * controls._scale()
	var origin: Vector2 = controls.stick_origin()
	var knob: Vector2 = origin + controls.stick_vector()
	var held: bool = controls._stick_finger >= 0
	var base_alpha := alpha * (0.75 if held else 0.35)
	draw_circle(origin, radius + 2.0, Color(0, 0, 0, 0.35 * base_alpha))
	draw_circle(origin, radius, Color(FACE, 0.45 * base_alpha))
	draw_arc(origin, radius, 0, TAU, 40, Color(RIM, base_alpha), 1.0, true)
	for i in 4:
		var dir := Vector2.RIGHT.rotated(i * PI / 2.0)
		var tip := origin + dir * (radius - 4.0)
		draw_colored_polygon(PackedVector2Array([tip + dir * 2.0, tip - dir * 1.5 + dir.orthogonal() * 2.5, tip - dir * 1.5 - dir.orthogonal() * 2.5]), Color(RIM, base_alpha * 0.8))
	draw_circle(knob, radius * 0.45, Color(RIM.darkened(0.3), alpha * (0.9 if held else 0.5)))
	draw_arc(knob, radius * 0.45, 0, TAU, 24, Color(INK, alpha * 0.8), 1.0, true)


func _draw_button(button: Dictionary, alpha: float) -> void:
	var center: Vector2 = button["center"]
	var radius: float = button["radius"]
	var held: bool = controls.is_held(button["id"])
	var glowing: bool = button["id"] == "interact" and controls.prompt_ready()
	var rim := LIT if glowing else RIM
	var face_alpha := alpha * (0.9 if held else 0.55)
	if held:
		radius *= 0.92
	draw_circle(center + Vector2(0, 1.5), radius, Color(0, 0, 0, 0.35 * alpha))
	draw_circle(center, radius, Color(FACE.lightened(0.25) if held else FACE, face_alpha))
	draw_arc(center, radius - 0.5, 0, TAU, 36, Color(rim, alpha * (1.0 if held or glowing else 0.8)), 1.0 if radius < 12 else 1.5, true)
	if glowing:
		var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 180.0)
		draw_arc(center, radius + 2.0, 0, TAU, 36, Color(LIT, alpha * 0.5 * pulse), 1.0, true)
	var ink := Color(INK, minf(1.0, alpha + 0.3))
	var icon: String = button["icon"]
	if icon == "rune":
		_draw_rune(button, center, ink)
	elif not icon.is_empty():
		_draw_icon(icon, center, radius, ink)
	var label: String = button["label"]
	if not label.is_empty():
		_draw_label(label, center, radius, ink)


## The word on a button, as large as fits inside it, centred.
func _draw_label(label: String, center: Vector2, radius: float, ink: Color) -> void:
	var size := 8
	var width := UiTheme.FONT_FILE.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	if width > radius * 2.0 - 4.0:
		size = 6
		width = UiTheme.FONT_FILE.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	draw_string(UiTheme.FONT_FILE, Vector2(center.x - width / 2.0, center.y + size * 0.35), label, HORIZONTAL_ALIGNMENT_LEFT, -1, size, ink)


func _draw_rune(button: Dictionary, center: Vector2, ink: Color) -> void:
	var slot := int(String(button["id"]).trim_prefix("rune_"))
	var rune: String = Runes.in_slot(slot)
	if rune.is_empty():
		return
	var index: int = Runes.ORDER.find(rune)
	var color := Color(Runes.DEFINITIONS[rune]["color"])
	var radius: float = button["radius"]
	var fill := clampf(Runes.energy / Runes.MAX_ENERGY, 0.0, 1.0)
	if rune == Runes.SCATTER:
		fill = Runes.reload_progress() if Runes.is_reloading() else float(Runes.loaded_shells) / Runes.MAGAZINE
		var count := "%d+%d" % [Runes.loaded_shells, Runes.spare_shells()]
		var width := UiTheme.FONT_FILE.get_string_size(count, HORIZONTAL_ALIGNMENT_LEFT, -1, 6).x
		draw_string(UiTheme.FONT_FILE, center + Vector2(-width / 2.0, radius + 7.0), count, HORIZONTAL_ALIGNMENT_LEFT, -1, 6, ink)
	draw_arc(center, radius - 2.0, -PI / 2.0, -PI / 2.0 + TAU * fill, 24, Color(color, ink.a), 2.0, true)
	var at := (center - Vector2(RUNE_ICON, RUNE_ICON) / 2.0).round()
	draw_texture_rect_region(RUNE_ICONS, Rect2(at, Vector2(RUNE_ICON, RUNE_ICON)), Rect2(index * RUNE_ICON, 0, RUNE_ICON, RUNE_ICON), Color(1, 1, 1, ink.a))


## Small line icons, drawn so they stay crisp at any button size.
func _draw_icon(icon: String, c: Vector2, r: float, ink: Color) -> void:
	var u := r / 10.0
	match icon:
		"sword":
			var tip := c + Vector2(6, -6) * u
			var hilt := c + Vector2(-4, 4) * u
			draw_line(hilt, tip, ink, 2.0 * u, true)
			draw_line(c + Vector2(-6, 2) * u, c + Vector2(-2, 6) * u, LIT, 1.6 * u, true)
			draw_line(hilt, c + Vector2(-7, 7) * u, ink.darkened(0.3), 1.6 * u, true)
		"shield":
			var points := PackedVector2Array([c + Vector2(-5, -5) * u, c + Vector2(5, -5) * u, c + Vector2(5, 0) * u, c + Vector2(0, 6) * u, c + Vector2(-5, 0) * u])
			draw_colored_polygon(points, Color(RIM, ink.a * 0.5))
			points.append(points[0])
			draw_polyline(points, ink, 1.2, true)
		"bandage":
			draw_rect(Rect2(c - Vector2(1.5, 5) * u, Vector2(3, 10) * u), Color("#e0584a", ink.a))
			draw_rect(Rect2(c - Vector2(5, 1.5) * u, Vector2(10, 3) * u), Color("#e0584a", ink.a))
		"drop":
			var drop := PackedVector2Array([c + Vector2(0, -6) * u, c + Vector2(4, 1) * u, c + Vector2(2.5, 4.5) * u, c + Vector2(-2.5, 4.5) * u, c + Vector2(-4, 1) * u])
			draw_colored_polygon(drop, Color("#4aa3df", ink.a))
		"bars":
			for i in 3:
				draw_line(c + Vector2(-4, -3 + 3 * i) * u, c + Vector2(4, -3 + 3 * i) * u, ink, 1.2, true)
		"map":
			var fold := PackedVector2Array([c + Vector2(-5, -4) * u, c + Vector2(-1.5, -5) * u, c + Vector2(1.5, -4) * u, c + Vector2(5, -5) * u, c + Vector2(5, 4) * u, c + Vector2(1.5, 5) * u, c + Vector2(-1.5, 4) * u, c + Vector2(-5, 5) * u, c + Vector2(-5, -4) * u])
			draw_polyline(fold, ink, 1.0, true)
			draw_line(c + Vector2(-1.5, -5) * u, c + Vector2(-1.5, 4) * u, ink, 1.0)
			draw_line(c + Vector2(1.5, -4) * u, c + Vector2(1.5, 5) * u, ink, 1.0)
