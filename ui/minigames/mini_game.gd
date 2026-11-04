class_name MiniGame
extends OverlayPanel
## The shared frame for every hands-on puzzle (circuits, locks, memory, mixes,
## the conveyor, signals): a title, your health, a prompt, a board drawn by the
## puzzle, feedback and a key hint. It runs in the world (time keeps going) and
## reports through the same puzzle_finished signal as the ordering puzzles, so
## any terminal, door or person can ask for one by id from data/puzzles.json.
##
## Subclasses set `kind`, build their board in `_start(data)`, read keys in
## `_board_input(event)`, and call `_win()` or `_mistake(text, damage)`.

enum Phase { IDLE, PLAYING, WON }

const SOLVED_FLAG_FORMAT := "puzzle_%s_solved"
const BOARD_SIZE := Vector2(430, 120)

## Which "type" in data/puzzles.json this panel plays.
var kind := ""
var _phase := Phase.IDLE
var _puzzle_id := ""
var _data: Dictionary = {}
var _title: Label
var _prompt: Label
var _board: Control
var _feedback: RichTextLabel
var _hint: Label


func _ready() -> void:
	in_world = true
	_build_shell(Vector2(452, 252), UiTheme.COLOR_TEAL)
	EventBus.player_collapsed.connect(leave)
	_title = _label("", UiTheme.COLOR_TEAL)
	_box.add_child(_title)
	_add_health_row()
	_prompt = _label("", UiTheme.COLOR_TEXT)
	_box.add_child(_prompt)
	_board = Control.new()
	_board.custom_minimum_size = BOARD_SIZE
	_board.draw.connect(_draw_board)
	_box.add_child(_board)
	_feedback = _rich(30)
	_box.add_child(_feedback)
	_hint = _label("", UiTheme.COLOR_MUTED)
	_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_box.add_child(_hint)
	EventBus.puzzle_requested.connect(_on_puzzle_requested)


func phase() -> Phase:
	return _phase


func puzzle_id() -> String:
	return _puzzle_id


func open_game(id: String) -> void:
	var data := Content.puzzle(id)
	if _phase != Phase.IDLE or data.is_empty() or data.get("type", "order") != kind:
		return
	_puzzle_id = id
	_data = data
	_phase = Phase.PLAYING
	_title.text = data.get("title", "")
	_prompt.text = data.get("prompt", "")
	_feedback.text = ""
	_start(data)
	_show_panel()
	_board.queue_redraw()


func leave() -> void:
	if _phase == Phase.IDLE:
		return
	var id := _puzzle_id
	var solved := _phase == Phase.WON
	_phase = Phase.IDLE
	_hide_panel()
	EventBus.puzzle_finished.emit(id, solved)


func _on_puzzle_requested(id: String) -> void:
	if Content.puzzle(id).get("type", "order") == kind:
		open_game(id)


func _unhandled_input(event: InputEvent) -> void:
	if not visible or _just_opened() or not event.is_pressed() or event.is_echo():
		return
	get_viewport().set_input_as_handled()
	if event.is_action_pressed("ui_cancel"):
		leave()
		return
	if _phase == Phase.WON:
		if event.is_action_pressed("interact") or event.is_action_pressed("ui_accept"):
			leave()
		return
	_board_input(event)
	_board.queue_redraw()


func _process(_delta: float) -> void:
	if visible:
		_board.queue_redraw()


func _win() -> void:
	_phase = Phase.WON
	GameState.set_flag(SOLVED_FLAG_FORMAT % _puzzle_id)
	GameState.add_to_counter("minigames_won")
	for lesson_id: String in _data.get("lessons", []):
		GameState.set_flag("lesson_seen_%s" % lesson_id)
	var xp := int(_data.get("xp", 25))
	if xp > 0:
		Progress.add_xp(xp)
	EventBus.sfx_requested.emit("task_done")
	_feedback.text = "[color=#7bc043]DONE[/color]  %s" % _data.get("explanation", "")
	_hint.text = "E  continue"


func _mistake(text: String, damage: float = 6.0) -> void:
	EventBus.sfx_requested.emit("wrong")
	GameState.add_to_counter("puzzle_mistakes")
	var hurt := damage * Difficulty.value("penalty")
	if hurt > 0.0:
		Survival.damage(hurt)
		_flash_health(hurt)
		_feedback.text = "[color=#e0584a]%s  -%d health[/color]" % [text, roundi(hurt)]
	else:
		_feedback.text = "[color=#e0584a]%s[/color]" % text


func _say(text: String) -> void:
	_feedback.text = text


# ---------------------------------------------------------------- for subclasses

func _start(_data_in: Dictionary) -> void:
	pass


func _board_input(_event: InputEvent) -> void:
	pass


func _draw_board() -> void:
	pass


## Arrow-key movement as a grid step, or zero.
static func arrow_step(event: InputEvent) -> Vector2i:
	if event.is_action_pressed("ui_left") or event.is_action_pressed("move_left"):
		return Vector2i.LEFT
	if event.is_action_pressed("ui_right") or event.is_action_pressed("move_right"):
		return Vector2i.RIGHT
	if event.is_action_pressed("ui_up") or event.is_action_pressed("move_up"):
		return Vector2i.UP
	if event.is_action_pressed("ui_down") or event.is_action_pressed("move_down"):
		return Vector2i.DOWN
	return Vector2i.ZERO


static func is_confirm(event: InputEvent) -> bool:
	return event.is_action_pressed("interact") or event.is_action_pressed("ui_accept")


func _text(at: Vector2, text: String, color: Color = UiTheme.COLOR_TEXT, size: int = 8, width: float = -1.0, align: HorizontalAlignment = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	_board.draw_string(UiTheme.FONT_FILE, at, text, align, width, size, color)
