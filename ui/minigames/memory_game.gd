class_name MemoryGame
extends MiniGame
## Match the pairs: each waste item with where it belongs. Arrows move, E turns
## a card. A few misses are free; after that every miss costs a little health.

const GAP := 4.0
const TEXT_SIZE := 8
const SMALL_TEXT_SIZE := 6
const LINE_HEIGHT := 10.0

var board: MemoryBoard
var cursor := 0
var _misses := 0
var _free_misses := 4
var _hide_at := -1.0
var _clock := 0.0


func _init() -> void:
	super()
	kind = "memory"


func _start(data: Dictionary) -> void:
	board = MemoryBoard.new(data.get("pairs", []), int(data.get("seed", Time.get_ticks_msec())))
	cursor = 0
	_misses = 0
	_free_misses = int(data.get("free_misses", board.cards.size() / 2))
	_hide_at = -1.0
	_hint.text = TouchControls.hint("Arrows move   E turn a card   Esc leave", "Tap the cards to turn them   BACK leave")


func _process(delta: float) -> void:
	super(delta)
	_clock += delta
	if _hide_at > 0.0 and _clock >= _hide_at:
		_hide_at = -1.0
		board.hide_misses()


func _board_input(event: InputEvent) -> void:
	var step := arrow_step(event)
	if step != Vector2i.ZERO:
		var grid := layout()
		var columns: int = grid["columns"]
		var column := clampi(cursor % columns + step.x, 0, columns - 1)
		var row := clampi(cursor / columns + step.y, 0, int(grid["rows"]) - 1)
		cursor = mini(row * columns + column, board.cards.size() - 1)
		EventBus.sfx_requested.emit("ui_move")
	elif is_confirm(event):
		turn(cursor)


func card_at(point: Vector2) -> int:
	if board == null:
		return -1
	for index in board.cards.size():
		if card_rect(index).has_point(point):
			return index
	return -1


## How the cards sit on the board: as few rows as keep them wide enough to
## read (two rows for up to twelve cards), each card as big as the board allows.
func layout() -> Dictionary:
	var count := board.cards.size() if board != null else 0
	var rows := 2 if count <= 12 else ceili(count / 6.0)
	var columns := maxi(ceili(count / float(rows)), 1)
	var card := Vector2((_board.size.x - GAP * (columns - 1)) / columns, (_board.size.y - GAP * (rows - 1)) / rows).floor()
	var total := Vector2(columns * (card.x + GAP) - GAP, rows * (card.y + GAP) - GAP)
	return {"rows": rows, "columns": columns, "card": card, "origin": ((_board.size - total) / 2.0).floor()}


func card_rect(index: int) -> Rect2:
	var grid := layout()
	var card: Vector2 = grid["card"]
	var columns: int = grid["columns"]
	return Rect2(grid["origin"] + Vector2(index % columns * (card.x + GAP), index / columns * (card.y + GAP)), card)


## A card's words broken into lines at spaces, and the size they fit at.
static func wrap_words(text: String, width: float) -> Dictionary:
	for size in [TEXT_SIZE, SMALL_TEXT_SIZE]:
		var lines: Array[String] = []
		var fits := true
		for word in text.split(" ", false):
			if UiTheme.FONT_FILE.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
				fits = false
			var joined := word if lines.is_empty() else lines[-1] + " " + word
			if not lines.is_empty() and UiTheme.FONT_FILE.get_string_size(joined, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width:
				lines[-1] = joined
			else:
				lines.append(word)
		if fits or size == SMALL_TEXT_SIZE:
			return {"lines": lines, "size": size}
	return {}


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
	for index in board.cards.size():
		var card: Dictionary = board.cards[index]
		var box := card_rect(index)
		var face_up: bool = card["up"] or card["done"]
		var fill := Color("#1d3a2a") if card["done"] else (Color("#26303c") if face_up else Color("#3a2a48"))
		_board.draw_rect(box, fill)
		if not face_up:
			_board.draw_rect(box.grow(-4.0), Color("#4a3a5a"), false, 1.0)
			_text(Vector2(box.position.x, box.get_center().y + 4), "?", Color("#7a6a8a"), 8, box.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		else:
			var wrapped := wrap_words(str(card["text"]), box.size.x - 6.0)
			var lines: Array = wrapped["lines"]
			var top := box.get_center().y - (lines.size() * LINE_HEIGHT) / 2.0 + LINE_HEIGHT - 2.0
			for line_index in lines.size():
				_text(Vector2(box.position.x, top + line_index * LINE_HEIGHT), lines[line_index], UiTheme.COLOR_TEXT, int(wrapped["size"]), box.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		var border := UiTheme.COLOR_GREEN if card["done"] else Color("#5a4a6a")
		if index == cursor and _phase == Phase.PLAYING:
			border = Color(1, 1, 1, 0.6 + 0.4 * sin(_clock * 8.0))
		_board.draw_rect(box, border, false, 1.0)
