class_name DialogueBox
extends CanvasLayer
## Typewriter dialogue along the bottom of the screen, with a speaker name and
## portrait. It does not pause the world; being hit cuts it short. Reports back
## with dialogue_finished (or dialogue_interrupted).

const CHARS_PER_SECOND := 70.0
const BLIP_EVERY_N_CHARS := 3
const ICON_PATH_FORMAT := "res://assets/sprites/%s.png"
## Who is speaking, by dialogue id prefix. Anything else is narration.
const SPEAKERS: Array[Dictionary] = [
	{"prefix": "recording_", "name": "INES", "tag": "recording", "color": "#f08a24", "icon": "recorder"},
	{"prefix": "archive_", "name": "ARCHIVE", "tag": "terminal", "color": "#5fe0d0", "icon": "terminal_on"},
	{"prefix": "dump_records", "name": "MUNICIPAL RECORDS", "tag": "terminal", "color": "#5fe0d0", "icon": "terminal_on"},
	{"prefix": "terminal_", "name": "TERMINAL", "tag": "", "color": "#5fe0d0", "icon": "terminal_off"},
	{"prefix": "river_cleaned", "name": "TREATMENT PLANT", "tag": "", "color": "#5fe0d0", "icon": "terminal_on"},
	{"prefix": "sample_", "name": "TEST STRIP", "tag": "", "color": "#9be04a", "icon": "sample_kit"},
]
## Walk this far from where the conversation started and it closes.
const WALK_AWAY_DISTANCE := 64.0
const NARRATION := {"name": "", "tag": "", "color": "#5fd0c4", "icon": ""}

## Conversations no longer stop the world: zombies still come, and being hit
## cuts the conversation short. Turn this on only for a modal use of the box.
@export var pauses_game: bool = false

var _lines: Array[String] = []
var _index := 0
var _dialogue_id := ""
var _typing: Tween
var _opened_on_frame := -1
var _anchor := Vector2.INF
var _last_source: Node2D
var _last_source_frame := -1

var _root: Control
var _stripe: ColorRect
var _portrait: TextureRect
var _portrait_frame: PanelContainer
var _name: Label
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
	EventBus.interacted.connect(_remember_source)


func is_open() -> bool:
	return visible


## A scene change with a conversation open must not leave notices held back forever.
func _exit_tree() -> void:
	if visible:
		EventBus.dialogue_interrupted.emit()


## Who speaks a dialogue: {"name", "tag", "color", "icon"}. Narration has no name.
static func speaker_for(dialogue_id: String) -> Dictionary:
	for speaker in SPEAKERS:
		if dialogue_id.begins_with(speaker["prefix"]):
			return speaker
	return NARRATION


func show_lines(lines: Array[String], dialogue_id: String = "") -> void:
	if lines.is_empty():
		EventBus.dialogue_finished.emit(dialogue_id)
		return
	_lines = lines.duplicate()
	_dialogue_id = dialogue_id
	_index = 0
	_opened_on_frame = Engine.get_process_frames()
	_apply_speaker(speaker_for(dialogue_id))
	_anchor = _anchor_position()
	visible = true
	EventBus.dialogue_opened.emit()
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


func _remember_source(source: Node) -> void:
	_last_source = source as Node2D
	_last_source_frame = Engine.get_process_frames()


## Where the conversation is "at": the thing just interacted with, else the player.
func _anchor_position() -> Vector2:
	if is_instance_valid(_last_source) and Engine.get_process_frames() - _last_source_frame <= 2:
		return _last_source.global_position
	var player := get_tree().get_first_node_in_group("player") as Node2D
	return player.global_position if player != null else Vector2.INF


func _process(_delta: float) -> void:
	if not visible or _anchor == Vector2.INF:
		return
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if player != null and player.global_position.distance_to(_anchor) > WALK_AWAY_DISTANCE:
		interrupt()


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


func _apply_speaker(speaker: Dictionary) -> void:
	var color := Color(speaker["color"])
	_stripe.color = color
	_name.visible = not String(speaker["name"]).is_empty()
	_name.text = speaker["name"] if speaker["tag"] == "" else "%s  (%s)" % [speaker["name"], speaker["tag"]]
	_name.add_theme_color_override("font_color", color)
	var icon_path: String = ICON_PATH_FORMAT % speaker["icon"] if speaker["icon"] != "" else ""
	_portrait.texture = load(icon_path) if not icon_path.is_empty() and ResourceLoader.exists(icon_path) else null
	_portrait_frame.visible = _portrait.texture != null


func _show_line() -> void:
	var line := _lines[_index]
	_text.text = line
	_text.visible_characters = 0
	var last := _index >= _lines.size() - 1
	_hint.text = "%d/%d   [E] %s" % [_index + 1, _lines.size(), "Close" if last else "Continue"]
	if _typing != null:
		_typing.kill()
	_typing = create_tween()
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
	panel.add_theme_stylebox_override("panel", UiTheme.banner_style())
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.anchor_right = 1.0
	panel.offset_left = 14.0
	panel.offset_right = -14.0
	panel.offset_top = -86.0
	panel.offset_bottom = -10.0
	panel.gui_input.connect(_on_panel_gui_input)
	_root.add_child(panel)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 7)
	panel.add_child(row)
	_stripe = ColorRect.new()
	_stripe.custom_minimum_size = Vector2(3, 0)
	row.add_child(_stripe)

	_portrait_frame = PanelContainer.new()
	_portrait_frame.add_theme_stylebox_override("panel", UiTheme.slot_style(false))
	_portrait_frame.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(_portrait_frame)
	_portrait = TextureRect.new()
	_portrait.custom_minimum_size = Vector2(32, 32)
	_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_portrait_frame.add_child(_portrait)

	var box := VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 3)
	row.add_child(box)
	_name = Label.new()
	box.add_child(_name)
	_text = Label.new()
	_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_text.custom_minimum_size = Vector2(0, 34)
	box.add_child(_text)
	_hint = Label.new()
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hint.add_theme_color_override("font_color", UiTheme.COLOR_ORANGE)
	box.add_child(_hint)
