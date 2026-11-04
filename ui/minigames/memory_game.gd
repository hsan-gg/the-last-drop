class_name MemoryGame
extends MiniGame
## Match the pairs: each waste item with where it belongs. Arrows move, E turns
## a card. A few misses are free; after that every miss costs a little health.

const CARD := Vector2(66, 26)
const COLUMNS := 4

var board: MemoryBoard
var cursor := 0
var _misses := 0
var _free_misses := 4
var _hide_at := -1.0
var _clock := 0.0


func _init() -> void:
	super()
	touch_dpad = true
	kind = "memory"


func _start(data: Dictionary) -> void:
	board = MemoryBoard.new(data.get("pairs", []), int(data.get("seed", Time.get_ticks_msec())))
	cursor = 0
	_misses = 0
	_free_misses = int(data.get("free_misses", board.cards.size() / 2))
	_hide_at = -1.0
	_hint.text = TouchControls.hint("Arrows move   E turn a card   Esc leave", "Tap a card, or arrows + OK   BACK leave")


func _process(delta: float) -> void:
	super(delta)
	_clock += delta
	if _hide_at > 0.0 and _clock >= _hide_at:
		_hide_at = -1.0
		board.hide_misses()


func _board_input(event: InputEvent) -> void:
	var step := arrow_step(event)
	if step != Vector2i.ZERO:
		var rows := ceili(board.cards.size() / float(COLUMNS))
		var column := clampi(cursor % COLUMNS + step.x, 0, COLUMNS - 1)
		var row := clampi(cursor / COLUMNS + step.y, 0, rows - 1)
		cursor = mini(row * COLUMNS + column, board.cards.size() - 1)
		EventBus.sfx_requested.emit("ui_move")
	elif is_confirm(event):
		turn(cursor)


func card_at(point: Vector2) -> int:
	if board == null:
		return -1
	var rows := ceili(board.cards.size() / float(COLUMNS))
	var total := Vector2(COLUMNS * (CARD.x + 4) - 4, rows * (CARD.y + 4) - 4)
	var origin := ((_board.size - total) / 2.0).floor()
	for index in board.cards.size():
		var at := origin + Vector2(index % COLUMNS * (CARD.x + 4), index / COLUMNS * (CARD.y + 4))
		if Rect2(at, CARD).has_point(point):
			return index
	return -1


func _board_tap(point: Vector2) -> void:
	var index := card_at(point)
	if index >= 0:
		cursor = index
		turn(index)


func turn(index: int) -> void:
	if _hide_at > 0.0:  # still showing the last miss: tidy it away first
		_hide_at = -1.0
		board.hide_misses()
	match board.flip(index):
		MemoryBoard.Flip.FIRST:
			EventBus.sfx_requested.emit("card_flip")
		MemoryBoard.Flip.MATCH:
			EventBus.sfx_requested.emit("sort_ok")
			_say("[color=#7bc043]A pair![/color]")
			if board.is_solved():
				_win()
		MemoryBoard.Flip.MISS:
			_misses += 1
			_hide_at = _clock + 0.9
			if _misses > _free_misses:
				_mistake("Those do not go together.", 3.0)
			else:
				EventBus.sfx_requested.emit("sort_bad")
				_say("[color=#9fb0bb]Not a pair. %d free tries left.[/color]" % (_free_misses - _misses))


func _draw_board() -> void:
	if board == null:
		return
	var rows := ceili(board.cards.size() / float(COLUMNS))
	var total := Vector2(COLUMNS * (CARD.x + 4) - 4, rows * (CARD.y + 4) - 4)
	var origin := ((_board.size - total) / 2.0).floor()
	for index in board.cards.size():
		var card: Dictionary = board.cards[index]
		var at := origin + Vector2(index % COLUMNS * (CARD.x + 4), index / COLUMNS * (CARD.y + 4))
		var face_up: bool = card["up"] or card["done"]
		var fill := Color("#1d3a2a") if card["done"] else (Color("#26303c") if face_up else Color("#3a2a48"))
		_board.draw_rect(Rect2(at, CARD), fill)
		if not face_up:
			_board.draw_rect(Rect2(at + Vector2(4, 4), CARD - Vector2(8, 8)), Color("#4a3a5a"), false, 1.0)
			_text(at + Vector2(0, 17), "?", Color("#7a6a8a"), 8, CARD.x, HORIZONTAL_ALIGNMENT_CENTER)
		else:
			_text(at + Vector2(2, 11), str(card["text"]).substr(0, 8), UiTheme.COLOR_TEXT, 8, CARD.x - 4, HORIZONTAL_ALIGNMENT_CENTER)
			if str(card["text"]).length() > 8:
				_text(at + Vector2(2, 21), str(card["text"]).substr(8, 8), UiTheme.COLOR_TEXT, 8, CARD.x - 4, HORIZONTAL_ALIGNMENT_CENTER)
		var border := UiTheme.COLOR_GREEN if card["done"] else Color("#5a4a6a")
		if index == cursor and _phase == Phase.PLAYING:
			border = Color(1, 1, 1, 0.6 + 0.4 * sin(_clock * 8.0))
		_board.draw_rect(Rect2(at, CARD), border, false, 1.0)
