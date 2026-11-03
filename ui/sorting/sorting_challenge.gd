class_name SortingChallenge
extends CanvasLayer
## The waste-sorting minigame. One item at a time: pick a bin, see the
## consequence, learn the principle. Rules live in SortingSession; this class
## is only presentation plus the side effects (health, counters, inventory).

enum Phase { IDLE, CHOOSING, FEEDBACK_WRONG, FEEDBACK_RIGHT, SUMMARY }

const WRONG_SORT_DAMAGE := 8.0
const BIN_PATH_FORMAT := "res://assets/sprites/bins/%s.png"
const BIN_LABELS := {
	SortingRules.BIN_GENERAL: "1 General",
	SortingRules.BIN_HAZARDOUS: "2 Hazardous",
	SortingRules.BIN_RECOVERY: "3 Recover",
}
const BIN_KEYS := {
	KEY_1: SortingRules.BIN_GENERAL,
	KEY_2: SortingRules.BIN_HAZARDOUS,
	KEY_3: SortingRules.BIN_RECOVERY,
}

## Tests turn this off so the tree keeps running.
@export var pauses_game: bool = true

var _phase := Phase.IDLE
var _pile_id := ""
var _session: SortingSession
var _total := 0
var _opened_on_frame := -1

var _root: Control
var _progress: Label
var _item_icon: TextureRect
var _item_name: Label
var _question: Label
var _bin_buttons: Dictionary = {}
var _feedback: RichTextLabel
var _continue: Button
var _hint: Label


func _ready() -> void:
	layer = 15
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	visible = false
	EventBus.sorting_requested.connect(open)


func phase() -> Phase:
	return _phase


func open(pile_id: String, item_ids: Array[String]) -> void:
	if _phase != Phase.IDLE or item_ids.is_empty():
		return
	_pile_id = pile_id
	_session = SortingSession.new(item_ids)
	_total = item_ids.size()
	_opened_on_frame = Engine.get_process_frames()
	visible = true
	if pauses_game:
		get_tree().paused = true
	_show_current_item()


func choose_bin(bin_id: String) -> void:
	if _phase != Phase.CHOOSING:
		return

	var verdict := _session.place(bin_id)
	var lesson := Content.lesson(verdict["lesson_id"])
	if verdict["correct"]:
		GameState.add_to_counter("sort_correct")
		EventBus.sfx_requested.emit("sort_ok")
		_set_feedback(Phase.FEEDBACK_RIGHT, "[color=#7bc043]CORRECT[/color]\n%s\n[color=#f2c94c]In real life:[/color] %s" % [lesson.get("right", ""), lesson.get("real_life", "")])
	else:
		GameState.add_to_counter("sort_mistakes")
		EventBus.sfx_requested.emit("sort_bad")
		Survival.damage(WRONG_SORT_DAMAGE)
		_set_feedback(Phase.FEEDBACK_WRONG, "[color=#e0584a]NOT QUITE[/color]\n%s\n[color=#5fd0c4]%s[/color]" % [lesson.get("wrong", ""), lesson.get("principle", "")])


func continue_flow() -> void:
	match _phase:
		Phase.FEEDBACK_WRONG:
			_show_current_item()
		Phase.FEEDBACK_RIGHT:
			if _session.is_complete():
				_show_summary()
			else:
				_show_current_item()
		Phase.SUMMARY:
			_close()


func _show_current_item() -> void:
	_phase = Phase.CHOOSING
	var item_id := _session.current_item()
	_item_icon.texture = ItemDB.icon(item_id)
	_item_name.text = ItemDB.display_name(item_id)
	_progress.text = "Item %d of %d" % [_total - _session.remaining() + 1, _total]
	_question.text = "Where does this belong?"
	_feedback.text = ""
	_set_bins_enabled(true)
	_continue.visible = false
	_hint.text = "Press 1, 2 or 3, or click a bin"


func _show_summary() -> void:
	var recovered := _session.recovered_items()
	for item_id in recovered:
		Inventory.add(item_id)
	GameState.set_flag("pile_sorted_%s" % _pile_id)

	var names: Array[String] = []
	for item_id in recovered:
		names.append(ItemDB.display_name(item_id))
	var summary := ", ".join(names) if not names.is_empty() else "nothing reusable"
	_set_feedback(Phase.SUMMARY, "[color=#5fd0c4]PILE SORTED[/color]\nYou recovered: %s.\nHazards went where they cannot hurt anyone." % summary)
	_item_icon.texture = null
	_item_name.text = ""
	_question.text = ""
	EventBus.sfx_requested.emit("pickup")


func _set_feedback(next_phase: Phase, bbcode: String) -> void:
	_phase = next_phase
	_feedback.text = bbcode
	_set_bins_enabled(false)
	_continue.visible = true
	_continue.text = "Done" if next_phase == Phase.SUMMARY else "Continue"
	_hint.text = "[E] %s" % _continue.text


func _set_bins_enabled(enabled: bool) -> void:
	for button: Button in _bin_buttons.values():
		button.disabled = not enabled


func _close() -> void:
	_phase = Phase.IDLE
	visible = false
	if pauses_game:
		get_tree().paused = false
	var finished_pile := _pile_id
	_session = null
	EventBus.sorting_finished.emit(finished_pile)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or Engine.get_process_frames() == _opened_on_frame:
		return
	var key := event as InputEventKey
	if _phase == Phase.CHOOSING and key != null and key.pressed and not key.echo and BIN_KEYS.has(key.keycode):
		get_viewport().set_input_as_handled()
		choose_bin(BIN_KEYS[key.keycode])
	elif _phase != Phase.CHOOSING and (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		continue_flow()


func _build() -> void:
	_root = Control.new()
	_root.theme = UiTheme.get_theme()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.62)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.add_child(dim)

	var panel := PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.offset_left = -214.0
	panel.offset_right = 214.0
	panel.offset_top = -124.0
	panel.offset_bottom = 124.0
	_root.add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 5)
	panel.add_child(box)

	var header := HBoxContainer.new()
	box.add_child(header)
	var title := Label.new()
	title.text = "SORT THE WASTE"
	title.add_theme_color_override("font_color", UiTheme.COLOR_ORANGE)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	_progress = Label.new()
	_progress.add_theme_color_override("font_color", UiTheme.COLOR_MUTED)
	header.add_child(_progress)

	var item_row := HBoxContainer.new()
	item_row.alignment = BoxContainer.ALIGNMENT_CENTER
	item_row.add_theme_constant_override("separation", 10)
	box.add_child(item_row)
	_item_icon = TextureRect.new()
	_item_icon.custom_minimum_size = Vector2(36, 36)
	_item_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_item_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	item_row.add_child(_item_icon)
	_item_name = Label.new()
	_item_name.add_theme_font_size_override("font_size", 16)
	_item_name.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	item_row.add_child(_item_name)

	_question = Label.new()
	_question.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_question.add_theme_color_override("font_color", UiTheme.COLOR_MUTED)
	box.add_child(_question)

	var bins := HBoxContainer.new()
	bins.add_theme_constant_override("separation", 6)
	box.add_child(bins)
	for bin_id: String in SortingRules.BINS:
		var button := Button.new()
		button.text = BIN_LABELS[bin_id]
		button.icon = load(BIN_PATH_FORMAT % bin_id)
		button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.vertical_icon_alignment = VERTICAL_ALIGNMENT_TOP
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.custom_minimum_size = Vector2(0, 52)
		button.pressed.connect(choose_bin.bind(bin_id))
		bins.add_child(button)
		_bin_buttons[bin_id] = button

	_feedback = RichTextLabel.new()
	_feedback.bbcode_enabled = true
	_feedback.fit_content = false
	_feedback.scroll_active = false
	_feedback.custom_minimum_size = Vector2(0, 66)
	_feedback.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_feedback)

	var footer := HBoxContainer.new()
	box.add_child(footer)
	_hint = Label.new()
	_hint.add_theme_color_override("font_color", UiTheme.COLOR_MUTED)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_hint)
	_continue = Button.new()
	_continue.text = "Continue"
	_continue.pressed.connect(continue_flow)
	footer.add_child(_continue)
