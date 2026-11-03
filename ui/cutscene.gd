class_name CutscenePlayer
extends Control
## Plays the cutscene named by Cutscenes.pending_id: a stage behind a caption
## box. E, Space or a click goes to the next beat; Esc skips the whole thing.

signal finished

const CHARS_PER_SECOND := 90.0
const FADE_SECONDS := 0.3
## After the words finish, the next beat comes by itself (E or a click is faster).
const MIN_HOLD_SECONDS := 1.6
const HOLD_PER_CHARACTER := 0.022
const DRIFT_ZOOM := 0.07
const BAR_HEIGHT := 20.0

var _beats: Array = []
var _index := 0
var _stage: CutsceneStage
var _title: Label
var _text: Label
var _hint: Label
var _typing: Tween
var _veil: ColorRect
var _bar: ColorRect
var _pips: Label
var _auto: Tween
var _drift: Tween
var _done := false


func _ready() -> void:
	Music.stop_area()
	Music.play("finale" if Cutscenes.pending_id == "finale" else "story")
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
	if _auto != null:
		_auto.kill()
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
	var last := _index >= _beats.size() - 1
	_hint.text = "[E] begin   [Esc] skip" if last else "[E] next   [Esc] skip"
	_pips.text = "".join(PackedStringArray(range(_beats.size()).map(func(i: int) -> String: return "o" if i == _index else ".")))
	var fade := create_tween()
	_veil.modulate.a = 1.0
	fade.tween_property(_veil, "modulate:a", 0.0, FADE_SECONDS)
	if _typing != null:
		_typing.kill()
	_typing = create_tween()
	_typing.tween_interval(FADE_SECONDS * 0.6)
	_typing.tween_method(func(count: Variant) -> void: _text.visible_characters = int(count), 0, _text.text.length(), maxf(_text.text.length() / CHARS_PER_SECOND, 0.1))
	_start_camera_drift()
	_slam_title()
	_schedule_auto_advance(last)
	if beat.get("visual", "") == "map":
		var route := create_tween()
		route.tween_property(_stage, "route_progress", 1.0, 1.2)


## Seconds a beat stays after its words are out, before it moves on by itself.
static func hold_seconds(text: String) -> float:
	return MIN_HOLD_SECONDS + text.length() * HOLD_PER_CHARACTER


func _schedule_auto_advance(is_last: bool) -> void:
	if _auto != null:
		_auto.kill()
	if is_last:
		return  # the last beat waits: the player decides when to begin
	var words: String = _text.text
	_auto = create_tween()
	_auto.tween_interval(FADE_SECONDS + words.length() / CHARS_PER_SECOND + hold_seconds(words))
	_auto.tween_callback(advance)


## A slow push-in with a sideways drift, like a camera moving over a painting.
func _start_camera_drift() -> void:
	if _drift != null:
		_drift.kill()
	var seconds := FADE_SECONDS + _text.text.length() / CHARS_PER_SECOND + hold_seconds(_text.text)
	var direction := 1.0 if _index % 2 == 0 else -1.0
	_stage.zoom = 1.0
	_stage.pan = 6.0 * direction
	_drift = create_tween().set_parallel()
	_drift.tween_property(_stage, "zoom", 1.0 + DRIFT_ZOOM, seconds).set_trans(Tween.TRANS_SINE)
	_drift.tween_property(_stage, "pan", -6.0 * direction, seconds)


## The title card lands with a punch: big, then snapped into place with a shake.
func _slam_title() -> void:
	if not _title.visible:
		return
	_title.pivot_offset = Vector2(0, 8)
	_title.scale = Vector2(1.7, 1.7)
	var slam := create_tween()
	slam.tween_property(_title, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	slam.tween_callback(func() -> void: EventBus.sfx_requested.emit("blip"))
	for shake in 3:
		slam.tween_property(self, "position:y", 2.0 if shake % 2 == 0 else -2.0, 0.03)
	slam.tween_property(self, "position:y", 0.0, 0.03)


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
	var footer := HBoxContainer.new()
	box.add_child(footer)
	_pips = Label.new()
	_pips.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_pips.autowrap_mode = TextServer.AUTOWRAP_OFF
	_pips.add_theme_color_override("font_color", UiTheme.COLOR_ORANGE)
	footer.add_child(_pips)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.autowrap_mode = TextServer.AUTOWRAP_OFF
	_hint.add_theme_color_override("font_color", UiTheme.COLOR_MUTED)
	footer.add_child(_hint)
	_bar = ColorRect.new()
	_bar.color = Color.BLACK
	_bar.anchor_right = 1.0
	_bar.offset_bottom = BAR_HEIGHT
	_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_bar)
	_veil = ColorRect.new()
	_veil.color = Color.BLACK
	_veil.set_anchors_preset(Control.PRESET_FULL_RECT)
	_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_veil)
