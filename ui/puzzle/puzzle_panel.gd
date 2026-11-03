class_name PuzzlePanel
extends OverlayPanel
## An ordering puzzle on a terminal. Pick the steps in the right order; a wrong
## pick starts over. Solving sets puzzle_<id>_solved and explains the principle.

enum Phase { IDLE, SOLVING, SOLVED }

const OPTION_KEYS := [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5]
const MAX_OPTIONS := 5
const SOLVED_FLAG_FORMAT := "puzzle_%s_solved"
## A wrong step costs health, so guessing is not free.
const WRONG_DAMAGE := 9.0

var _phase := Phase.IDLE
var _puzzle_id := ""
var _data: Dictionary = {}
var _puzzle: OrderPuzzle
var _title: Label
var _prompt: Label
var _option_buttons: Array[Button] = []
var _feedback: RichTextLabel
var _continue: Button
var _hint: Label


func _ready() -> void:
	_build_shell(Vector2(452, 230), UiTheme.COLOR_TEAL)
	EventBus.player_collapsed.connect(leave)
	_build_contents()
	EventBus.puzzle_requested.connect(_on_puzzle_requested)


func phase() -> Phase:
	return _phase


func options() -> Array[String]:
	return _puzzle.options() if _puzzle != null else []


func open_puzzle(puzzle_id: String, shuffle_seed: int = 0) -> void:
	var data := Content.puzzle(puzzle_id)
	if _phase != Phase.IDLE or data.is_empty():
		return
	_puzzle_id = puzzle_id
	_data = data
	var steps: Array[String] = []
	steps.assign(data["steps"])
	_puzzle = OrderPuzzle.new(steps, shuffle_seed)
	_phase = Phase.SOLVING
	_title.text = data["title"]
	_prompt.text = data["prompt"]
	_feedback.text = ""
	_continue.visible = false
	_hint.text = "Press 1 to %d. A wrong step costs health. Esc leaves." % steps.size()
	_refresh()
	_show_panel()


func choose(option: String) -> void:
	if _phase != Phase.SOLVING:
		return
	var result := _puzzle.choose(option)
	if result["solved"]:
		_phase = Phase.SOLVED
		GameState.set_flag(SOLVED_FLAG_FORMAT % _puzzle_id)
		EventBus.sfx_requested.emit("repair")
		_feedback.text = "[color=#7bc043]UNLOCKED[/color]\n%s" % _data["explanation"]
		_continue.visible = true
		_hint.text = "Press E to continue"
	elif result["correct"]:
		EventBus.sfx_requested.emit("sort_ok")
		_feedback.text = ""
	else:
		GameState.add_to_counter("puzzle_mistakes")
		EventBus.sfx_requested.emit("sort_bad")
		var damage := WRONG_DAMAGE * Difficulty.value("penalty")
		Survival.damage(damage)
		_feedback.text = "[color=#e0584a]NOT THAT ONE  -%d health[/color]\nStart again from the first step." % int(round(damage))
	_refresh()


func continue_flow() -> void:
	if _phase != Phase.SOLVED:
		return
	_close(true)


func leave() -> void:
	if _phase == Phase.SOLVING:
		_close(false)


func _close(solved: bool) -> void:
	var finished_id := _puzzle_id
	_phase = Phase.IDLE
	_hide_panel()
	EventBus.puzzle_finished.emit(finished_id, solved)


func _refresh() -> void:
	var done := _puzzle.placed()
	var choices := _puzzle.options()
	for index in _option_buttons.size():
		var button := _option_buttons[index]
		button.visible = index < choices.size()
		if index >= choices.size():
			continue
		var order := done.find(choices[index])
		button.disabled = _phase != Phase.SOLVING or order >= 0
		if order >= 0:
			button.text = "%d.  %s" % [order + 1, choices[index]]
			button.add_theme_color_override("font_color", UiTheme.COLOR_TEAL)
			button.add_theme_color_override("font_disabled_color", UiTheme.COLOR_TEAL)
		else:
			button.text = "%d  %s" % [index + 1, choices[index]]
			button.remove_theme_color_override("font_color")
			button.remove_theme_color_override("font_disabled_color")


func _on_puzzle_requested(puzzle_id: String) -> void:
	open_puzzle(puzzle_id)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _just_opened():
		return
	var key := event as InputEventKey
	if _phase == Phase.SOLVING and key != null and key.pressed and not key.echo:
		if OPTION_KEYS.has(key.keycode):
			var index: int = OPTION_KEYS.find(key.keycode)
			var choices := _puzzle.options()
			if index < choices.size():
				get_viewport().set_input_as_handled()
				choose(choices[index])
		elif key.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			leave()
	elif _phase == Phase.SOLVED and (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		continue_flow()


func _build_contents() -> void:
	_title = _label("", UiTheme.COLOR_TEAL)
	_box.add_child(_title)
	_prompt = _label("", UiTheme.COLOR_TEXT)
	_prompt.custom_minimum_size = Vector2(0, 20)
	_box.add_child(_prompt)
	for index in MAX_OPTIONS:
		var button := _button("", _on_option_pressed.bind(index))
		_option_buttons.append(button)
		_box.add_child(button)
	_feedback = _rich(42)
	_box.add_child(_feedback)
	var footer := HBoxContainer.new()
	_box.add_child(footer)
	_hint = _label("", UiTheme.COLOR_MUTED)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_hint)
	_continue = _button("Continue", continue_flow)
	_continue.autowrap_mode = TextServer.AUTOWRAP_OFF
	footer.add_child(_continue)


func _on_option_pressed(index: int) -> void:
	var choices := _puzzle.options()
	if index < choices.size():
		choose(choices[index])
