class_name QuizPanel
extends OverlayPanel
## "Field Check": one multiple-choice question after a pile is sorted. A right
## answer refreshes the player; a wrong one only teaches. Either way it is asked once.

enum Phase { IDLE, ASKING, FEEDBACK }

const CORRECT_WATER_REWARD := 12.0
const WRONG_DAMAGE := 12.0
const OPTION_KEYS := [KEY_1, KEY_2, KEY_3]

var _phase := Phase.IDLE
var _quiz: Dictionary = {}
var _was_correct := false
var _question: Label
var _options: Array[Button] = []
var _feedback: RichTextLabel
var _continue: Button
var _hint: Label


func _ready() -> void:
	in_world = true
	_build_shell(Vector2(420, 204), UiTheme.COLOR_ORANGE)
	EventBus.player_collapsed.connect(abandon)
	_build_contents()
	EventBus.quiz_requested.connect(_on_quiz_requested)


func phase() -> Phase:
	return _phase


func current_quiz() -> Dictionary:
	return _quiz


func open_quiz(quiz: Dictionary) -> void:
	if _phase != Phase.IDLE or quiz.is_empty():
		return
	_quiz = quiz
	_phase = Phase.ASKING
	_question.text = quiz["question"]
	var choices: Array = quiz["options"]
	for index in _options.size():
		_options[index].visible = index < choices.size()
		_options[index].disabled = false
		if index < choices.size():
			_options[index].text = "%d  %s" % [index + 1, choices[index]]
	_feedback.text = ""
	_continue.visible = false
	_hint.text = TouchControls.hint("Press 1, 2 or 3", "Tap an answer, or 1, 2 or 3")
	_show_panel()


func answer(index: int) -> void:
	if _phase != Phase.ASKING:
		return
	_phase = Phase.FEEDBACK
	_was_correct = QuizRules.is_correct(_quiz, index)
	GameState.set_flag(QuizRules.ANSWERED_FLAG_FORMAT % _quiz["id"])
	for option in _options:
		option.disabled = true
	if _was_correct:
		Survival.drink(CORRECT_WATER_REWARD)
		EventBus.sfx_requested.emit("sort_ok")
		_feedback.text = "[color=#7bc043]CORRECT[/color]  +water\n%s" % _quiz["explanation"]
	else:
		EventBus.sfx_requested.emit("wrong")
		var correct_text: String = _quiz["options"][int(_quiz["answer"])]
		var damage := WRONG_DAMAGE * Difficulty.value("penalty")
		Survival.damage(damage)
		_flash_health(damage)
		_feedback.text = "[color=#e0584a]NOT QUITE  -%d health[/color]\nThe answer: %s\n%s" % [int(round(damage)), correct_text, _quiz["explanation"]]
	# Counters last, so a quest that completes on this answer fires after the feedback is set.
	if not _was_correct:
		EventBus.penalty_spawn.emit("quiz")
	GameState.add_to_counter("quiz_correct" if _was_correct else "quiz_wrong")
	_continue.visible = true
	_hint.text = TouchControls.hint("Press E to continue", "Tap OK to continue")


func continue_flow() -> void:
	if _phase != Phase.FEEDBACK:
		return
	_phase = Phase.IDLE
	_hide_panel()
	EventBus.quiz_finished.emit(_was_correct)


## Knocked out mid-question: the panel closes without a verdict.
func abandon() -> void:
	if _phase == Phase.IDLE:
		return
	_phase = Phase.IDLE
	_hide_panel()


func leave() -> void:
	abandon()


func _on_quiz_requested(lesson_ids: Array) -> void:
	open_quiz(QuizRules.pick(lesson_ids))


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _just_opened():
		return
	var key := event as InputEventKey
	if _phase == Phase.ASKING and key != null and key.pressed and not key.echo and OPTION_KEYS.has(key.keycode):
		get_viewport().set_input_as_handled()
		answer(OPTION_KEYS.find(key.keycode))
	elif _phase == Phase.FEEDBACK and (event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")):
		get_viewport().set_input_as_handled()
		continue_flow()


func _build_contents() -> void:
	_box.add_child(_label("FIELD CHECK", UiTheme.COLOR_ORANGE))
	_add_health_row()
	_question = _label("", UiTheme.COLOR_TEXT, 8)
	_question.custom_minimum_size = Vector2(0, 20)
	_box.add_child(_question)
	for index in 3:
		var option := _button("", answer.bind(index))
		_options.append(option)
		_box.add_child(option)
	_feedback = _rich(46)
	_box.add_child(_feedback)
	var footer := HBoxContainer.new()
	_box.add_child(footer)
	_hint = _label("", UiTheme.COLOR_MUTED)
	_hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(_hint)
	_continue = _button("Continue", continue_flow)
	_continue.autowrap_mode = TextServer.AUTOWRAP_OFF
	footer.add_child(_continue)
