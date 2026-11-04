extends CanvasLayer
## The game's own volume bar for the Android app. The app's activity takes the
## phone's volume buttons itself (android/overlay/.../GodotApp.java), so
## Android's volume panel never slides over the game: the media volume changes
## silently and this small bar shows the new level for a moment instead.

const POLL_SECONDS := 0.1
const SHOW_SECONDS := 1.3
const FADE_SECONDS := 0.3
const BAR_SIZE := Vector2(70, 5)

var _app: JavaClass
var _last_state := -1
var _poll := 0.0
var _shown_for := 0.0
var _percent := 0
var _view: Control


func _ready() -> void:
	layer = 95
	process_mode = Node.PROCESS_MODE_ALWAYS
	_view = Control.new()
	_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_view.draw.connect(_draw_bar)
	_view.modulate.a = 0.0
	add_child(_view)
	if OS.get_name() == "Android":
		_app = JavaClassWrapper.wrap("com.godot.game.GodotApp")


## Shows the bar at a volume level (0-100); also used by tests.
func show_level(percent: int) -> void:
	_percent = clampi(percent, 0, 100)
	_shown_for = SHOW_SECONDS
	_view.modulate.a = 1.0
	_view.queue_redraw()


func is_showing() -> bool:
	return _view.modulate.a > 0.0


func _process(delta: float) -> void:
	_poll -= delta
	if _poll <= 0.0 and _app != null:
		_poll = POLL_SECONDS
		var state := int(_app.volumeState())
		if state >= 0 and state != _last_state:
			if _last_state != -1 or state >= 1000:
				show_level(state % 1000)
			_last_state = state
	if _shown_for > 0.0:
		_shown_for -= delta
		if _shown_for <= 0.0:
			create_tween().tween_property(_view, "modulate:a", 0.0, FADE_SECONDS)


func _draw_bar() -> void:
	var view := _view.size
	var box := Rect2(Vector2((view.x - BAR_SIZE.x - 30.0) / 2.0, 10.0), Vector2(BAR_SIZE.x + 30.0, 15.0))
	_view.draw_rect(box, Color(0.05, 0.08, 0.11, 0.85))
	_view.draw_rect(box, UiTheme.COLOR_TEAL, false, 1.0)
	var speaker := box.position + Vector2(6, 4)
	_view.draw_rect(Rect2(speaker + Vector2(0, 2), Vector2(3, 3)), UiTheme.COLOR_TEXT)
	_view.draw_colored_polygon(PackedVector2Array([speaker + Vector2(3, 2), speaker + Vector2(6, 0), speaker + Vector2(6, 7), speaker + Vector2(3, 5)]), UiTheme.COLOR_TEXT)
	var track := Rect2(box.position + Vector2(16, 5), BAR_SIZE)
	_view.draw_rect(track, Color("#1d2a30"))
	_view.draw_rect(Rect2(track.position, Vector2(BAR_SIZE.x * _percent / 100.0, BAR_SIZE.y)), Color("#4aa3df"))
	_view.draw_string(UiTheme.FONT_FILE, Vector2(track.end.x + 3, box.position.y + 11), str(_percent), HORIZONTAL_ALIGNMENT_LEFT, -1, 6, UiTheme.COLOR_TEXT)
