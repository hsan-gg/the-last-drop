class_name BannerQueue
extends Control
## Headlines at the top of the screen: "OBJECTIVE COMPLETE", "NEW OBJECTIVE",
## "LIFE LOST". They queue up, show one at a time, and keep running during
## conversations because nothing here depends on the game being paused.

const SHOW_SECONDS := 2.6
const FADE_SECONDS := 0.35
const TOP := 22.0
const WIDTH := 260.0

var _queue: Array[Dictionary] = []
var _active := false
var _panel: PanelContainer
var _stripe: ColorRect
var _title: Label
var _text: Label


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build()
	EventBus.banner_requested.connect(push)


func pending() -> int:
	return _queue.size() + (1 if _active else 0)


func push(title: String, text: String, color: Color = UiTheme.COLOR_ORANGE, seconds: float = SHOW_SECONDS) -> void:
	_queue.append({"title": title, "text": text, "color": color, "seconds": seconds})
	if not _active:
		_show_next()


func _show_next() -> void:
	if _queue.is_empty():
		_active = false
		_panel.visible = false
		return
	_active = true
	var banner: Dictionary = _queue.pop_front()
	_title.text = banner["title"]
	_title.add_theme_color_override("font_color", banner["color"])
	_text.text = banner["text"]
	_text.visible = not String(banner["text"]).is_empty()
	_stripe.color = banner["color"]
	_panel.visible = true
	_panel.modulate.a = 0.0
	var tween := create_tween()
	tween.tween_property(_panel, "modulate:a", 1.0, FADE_SECONDS)
	tween.tween_interval(banner["seconds"])
	tween.tween_property(_panel, "modulate:a", 0.0, FADE_SECONDS)
	tween.tween_callback(_show_next)


func _build() -> void:
	_panel = PanelContainer.new()
	_panel.theme = UiTheme.get_theme()
	_panel.add_theme_stylebox_override("panel", UiTheme.banner_style())
	_panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_panel.offset_left = -WIDTH / 2.0
	_panel.offset_right = WIDTH / 2.0
	_panel.offset_top = TOP
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.visible = false
	add_child(_panel)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	_panel.add_child(row)
	_stripe = ColorRect.new()
	_stripe.custom_minimum_size = Vector2(3, 0)
	row.add_child(_stripe)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 3)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(column)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 8)
	column.add_child(_title)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.add_theme_font_size_override("font_size", 8)
	_text.custom_minimum_size = Vector2(WIDTH - 24.0, 0)
	column.add_child(_text)
