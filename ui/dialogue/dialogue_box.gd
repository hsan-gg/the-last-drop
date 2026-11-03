class_name DialogueBox
extends CanvasLayer
## Typewriter dialogue at the bottom of the screen. Listens to the EventBus,
## pauses the game while open, and reports back with dialogue_finished.

const CHARS_PER_SECOND := 70.0
const BLIP_EVERY_N_CHARS := 3

## Conversations no longer stop the world: zombies still come, and being hit
## cuts the conversation short. Turn this on only for a modal use of the box.
@export var pauses_game: bool = false

var _lines: Array[String] = []
var _index := 0
var _dialogue_id := ""
var _typing: Tween
var _opened_on_frame := -1

var _root: Control
var _text: Label
var _hint: Label


func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false
	EventBus.dialogue_requested.connect(_on_dialogue_requested)
	EventBus.text_requested.connect(show_lines.bind(""))
	EventBus.damage_taken.connect(interrupt.unbind(1))


func is_open() -> bool:
	return visible


func show_lines(lines: Array[String], dialogue_id: String = "") -> void:
	if lines.is_empty():
		EventBus.dialogue_finished.emit(dialogue_id)
		return
	_lines = lines.duplicate()
	_dialogue_id = dialogue_id
	_index = 0
	_opened_on_frame = Engine.get_process_frames()
	visible = true
	if pauses_game:
		get_tree().paused = true
	_show_line()


## Ends the conversation without finishing it, e.g. because the player was hit.
func interrupt() -> void:
	if not visible:
		return
	if _typing != null:
		_typing.kill()
	visible = false
	if pauses_game:
		get_tree().paused = false
	EventBus.dialogue_interrupted.emit()


func advance() -> void:
	if not visible:
		return
	if _is_typing():
		_typing.kill()
		_text.visible_characters = -1
		return
	_index += 1
	if _index >= _lines.size():
		_close()
	else:
		_show_line()


func _on_dialogue_requested(dialogue_id: String) -> void:
	show_lines(Content.dialogue(dialogue_id), dialogue_id)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or Engine.get_process_frames() == _opened_on_frame:
		return
	if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		advance()


func _on_panel_gui_input(event: InputEvent) -> void:
	var click := event as InputEventMouseButton
	if click != null and click.pressed and click.button_index == MOUSE_BUTTON_LEFT:
		advance()


func _show_line() -> void:
	var line := _lines[_index]
	_text.text = line
	_text.visible_characters = 0
	_hint.text = "[E] Continue" if _index < _lines.size() - 1 else "[E] Close"
	if _typing != null:
		_typing.kill()
	_typing = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	_typing.tween_method(_reveal, 0, line.length(), maxf(line.length() / (CHARS_PER_SECOND * Settings.text_speed_multiplier()), 0.05))
	_typing.finished.connect(func() -> void: _text.visible_characters = -1)


func _reveal(count: Variant) -> void:
	var characters := int(count)
	_text.visible_characters = characters
	if characters % BLIP_EVERY_N_CHARS == 0:
		EventBus.sfx_requested.emit("blip")


func _is_typing() -> bool:
	return _typing != null and _typing.is_running()


func _close() -> void:
	visible = false
	if pauses_game:
		get_tree().paused = false
	var finished_id := _dialogue_id
	EventBus.dialogue_finished.emit(finished_id)


func _build() -> void:
	_root = Control.new()
	_root.theme = UiTheme.get_theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	var panel := PanelContainer.new()
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = 16.0
	panel.offset_right = -16.0
	panel.offset_top = -92.0
	panel.offset_bottom = -10.0
	panel.gui_input.connect(_on_panel_gui_input)
	_root.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)
	panel.add_child(box)

	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.custom_minimum_size = Vector2(0, 48)
	box.add_child(_text)

	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_color_override("font_color", UiTheme.COLOR_ORANGE)
	box.add_child(_hint)
