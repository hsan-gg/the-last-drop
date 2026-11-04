class_name MemoryGame
extends MiniGame
## Match the pairs: each waste item with where it belongs. Arrows move, E turns
## a card. A few misses are free; after that every miss costs a little health.

const GAP := 4.0
## Card text sizes, largest first: a layout is chosen so every word fits whole
## at the largest size that can manage it.
const TEXT_SIZES: Array[int] = [8, 7, 6]
const LINE_HEIGHT := 10.0
const PADDING := 6.0

var board: MemoryBoard
var cursor := 0
var _misses := 0
var _layout_cache: Dictionary = {}
var _layout_cache_for := Vector2.ZERO
var _free_misses := 4
var _hide_at := -1.0
var _clock := 0.0


func _init() -> void:
	super()
	kind = "memory"
	board_size = Vector2(430, 134)  # room for three or four rows when the words are long
	panel_size = Vector2(452, 266)


func _start(data: Dictionary) -> void:
	board = MemoryBoard.new(data.get("pairs", []), int(data.get("seed", Time.get_ticks_msec())))
	cursor = 0
	_layout_cache = {}
	_free_misses = int(data.get("free_misses", board.cards.size() / 2))
	_misses = GameState.get_counter(_misses_key())  # tries used before are still used
	_hide_at = -1.0
	_hint.text = TouchControls.hint("Arrows move   E turn a card   Esc leave", "Tap the cards to turn them   BACK leave")
	if _misses > 0:
		_say("[color=#9fb0bb]%d free tries left.[/color]" % free_tries_left())


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


## The free tries you have used are remembered per puzzle: leaving and coming
## back does not hand them out again.
func _misses_key() -> String:
	return "memory_misses_%s" % _puzzle_id


func free_tries_left() -> int:
	return maxi(_free_misses - _misses, 0)


func card_at(point: Vector2) -> int:
	if board == null:
		return -1
	for index in board.cards.size():
		if card_rect(index).has_point(point):
			return index
	return -1


## How the cards sit on the board: the largest text that lets every word of
## every card fit whole, using as few rows as that allows (two rows for short
## words, more rows of wider cards for long ones like "Precipitation").
func layout() -> Dictionary:
	if not _layout_cache.is_empty() and _layout_cache_for == _board.size:
		return _layout_cache
	_layout_cache = _compute_layout()
	_layout_cache_for = _board.size
	return _layout_cache


func _compute_layout() -> Dictionary:
	var count := board.cards.size() if board != null else 0
	var texts: Array[String] = []
	if board != null:
		for entry: Dictionary in board.cards:
			texts.append(str(entry["text"]))
	var fallback := {}
	for size in TEXT_SIZES:
		for rows in [2, 3, 4, 5, 6]:
			var option := _grid(count, rows)
			fallback = option
			if _fits(texts, option["card"], size):
				option["text_size"] = size
				return option
	fallback["text_size"] = TEXT_SIZES[-1]
	return fallback


func _grid(count: int, rows: int) -> Dictionary:
	rows = mini(rows, maxi(count, 1))
	var columns := maxi(ceili(count / float(rows)), 1)
	var card := Vector2((_board.size.x - GAP * (columns - 1)) / columns, (_board.size.y - GAP * (rows - 1)) / rows).floor()
	var total := Vector2(columns * (card.x + GAP) - GAP, rows * (card.y + GAP) - GAP)
	return {"rows": rows, "columns": columns, "card": card, "origin": ((_board.size - total) / 2.0).floor()}


func _fits(texts: Array[String], card: Vector2, size: int) -> bool:
	for text in texts:
		var wrapped := wrap_words(text, card.x - PADDING, size)
		if not wrapped["whole"] or wrapped["lines"].size() * LINE_HEIGHT > card.y - 2.0:
			return false
	return true


func card_rect(index: int) -> Rect2:
	var grid := layout()
	var card: Vector2 = grid["card"]
	var columns: int = grid["columns"]
	return Rect2(grid["origin"] + Vector2(index % columns * (card.x + GAP), index / columns * (card.y + GAP)), card)


## A card's words broken into lines at spaces. "whole" is false when a single
## word is wider than a line (it would be cut).
static func wrap_words(text: String, width: float, size: int) -> Dictionary:
	var lines: Array[String] = []
	var whole := true
	for word in text.split(" ", false):
		if UiTheme.FONT_FILE.get_string_size(word, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x > width:
			whole = false
		var joined := word if lines.is_empty() else lines[-1] + " " + word
		if not lines.is_empty() and UiTheme.FONT_FILE.get_string_size(joined, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x <= width:
			lines[-1] = joined
		else:
			lines.append(word)
	return {"lines": lines, "whole": whole}


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
			GameState.add_to_counter(_misses_key())
			_hide_at = _clock + 0.9
			if _misses > _free_misses:
				_mistake("Those do not go together.", 3.0)
			else:
				EventBus.sfx_requested.emit("sort_bad")
				_say("[color=#9fb0bb]Not a pair. %d free tries left.[/color]" % (_free_misses - _misses))


func _draw_board() -> void:
	if board == null:
		return
	var grid := layout()
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
			var text_size: int = grid["text_size"]
			var wrapped := wrap_words(str(card["text"]), box.size.x - PADDING, text_size)
			var lines: Array = wrapped["lines"]
			var top := box.get_center().y - (lines.size() * LINE_HEIGHT) / 2.0 + LINE_HEIGHT - 2.0
			for line_index in lines.size():
				_text(Vector2(box.position.x, top + line_index * LINE_HEIGHT), lines[line_index], UiTheme.COLOR_TEXT, text_size, box.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		var border := UiTheme.COLOR_GREEN if card["done"] else Color("#5a4a6a")
		if index == cursor and _phase == Phase.PLAYING:
			border = Color(1, 1, 1, 0.6 + 0.4 * sin(_clock * 8.0))
		_board.draw_rect(box, border, false, 1.0)
