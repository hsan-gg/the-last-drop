class_name CutscenePlayer
extends Control
## Plays the cutscene named by Cutscenes.pending_id: a stage behind a caption
## box. E, Space or a click goes to the next beat; Esc skips the whole thing.

signal finished

const CHARS_PER_SECOND := 55.0
const FADE_SECONDS := 0.4

var _beats: Array = []
var _index := 0
var _stage: CutsceneStage
var _title: Label
var _text: Label
var _hint: Label
var _typing: Tween
var _veil: ColorRect
var _done := false


func _ready() -> void:
	theme = UiTheme.get_theme()
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_build()
	if _beats.is_empty():
		_beats = Cutscenes.beats(Cutscenes.pending_id)
	_show_beat()


## For tests and tools: play these beats instead of reading the pending cutscene.
func play_beats(beats: Array) -> void:
	_beats = beats
	_index = 0
	_done = false
	if _stage != null:
		_show_beat()


func index() -> int:
	return _index


func is_done() -> bool:
	return _done


func advance() -> void:
	if _done:
		return
	if _typing != null and _typing.is_running():
		_typing.kill()
		_text.visible_characters = -1
		return
	_index += 1
	if _index >= _beats.size():
		finish()
	else:
		_show_beat()


func finish() -> void:
	if _done:
		return
	_done = true
	finished.emit()
	Cutscenes.finish()


func _show_beat() -> void:
	if _beats.is_empty():
		finish()
		return
	var beat: Dictionary = _beats[_index]
	_stage.show_beat(beat)
	_title.text = beat.get("title", "")
	_title.visible = not _title.text.is_empty()
	_text.text = beat.get("text", "")
	_text.visible_characters = 0
	_hint.text = "[E] continue   [Esc] skip" if _index < _beats.size() - 1 else "[E] begin   [Esc] skip"
	var fade := create_tween()
	_veil.modulate.a = 1.0
	fade.tween_property(_veil, "modulate:a", 0.0, FADE_SECONDS)
	if _typing != null:
		_typing.kill()
	_typing = create_tween()
	_typing.tween_interval(FADE_SECONDS * 0.6)
	_typing.tween_method(func(count: Variant) -> void: _text.visible_characters = int(count), 0, _text.text.length(), maxf(_text.text.length() / CHARS_PER_SECOND, 0.1))
	if beat.get("visual", "") == "map":
		var route := create_tween()
		route.tween_property(_stage, "route_progress", 1.0, 1.2)


func _unhandled_input(event: InputEvent) -> void:
	if _done:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		advance()
	elif event.is_action_pressed("menu"):
		get_viewport().set_input_as_handled()
		finish()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		advance()


func _build() -> void:
	var background := ColorRect.new()
	background.color = Color.BLACK
	background.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(background)
	_stage = CutsceneStage.new()
	add_child(_stage)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiTheme.banner_style())
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = 20.0
	panel.offset_right = -20.0
	panel.offset_top = -78.0
	panel.offset_bottom = -12.0
	add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	_title = Label.new()
	_title.add_theme_color_override("font_color", UiTheme.COLOR_ORANGE)
	box.add_child(_title)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_text)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_color_override("font_color", UiTheme.COLOR_MUTED)
	box.add_child(_hint)
	_veil = ColorRect.new()
	_veil.color = Color.BLACK
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)
