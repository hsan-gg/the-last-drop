class_name CircuitGame
extends MiniGame
## Reconnect the line: turn each wire (or pipe) piece until every lamp (or tap)
## is joined to the source. Arrows move, E turns the piece under the cursor.

const CELL := 24.0
const WIRE_ON := Color("#ffd84a")
const PIPE_ON := Color("#5fd0ff")
const OFF := Color("#5a5f6a")

var board: CircuitBoard
var cursor := Vector2i.ZERO
var _style := "wire"


func _init() -> void:
	super()
	touch_dpad = true
	kind = "circuit"


func _start(data: Dictionary) -> void:
	var size: Array = data.get("size", [5, 4])
	board = CircuitBoard.new(int(size[0]), int(size[1]), int(data.get("seed", 1)))
	_style = data.get("style", "wire")
	cursor = board.source
	_hint.text = TouchControls.hint("Arrows move   E turn   Esc leave", "Tap a tile to turn it, or arrows + OK   BACK leave")


func _board_input(event: InputEvent) -> void:
	var step := arrow_step(event)
	if step != Vector2i.ZERO:
		cursor = Vector2i(clampi(cursor.x + step.x, 0, board.width - 1), clampi(cursor.y + step.y, 0, board.height - 1))
		EventBus.sfx_requested.emit("ui_move")
	elif is_confirm(event):
		turn(cursor)


func cell_at(point: Vector2) -> Vector2i:
	if board == null:
		return Vector2i(-1, -1)
	var origin := ((_board.size - Vector2(board.width, board.height) * CELL) / 2.0).floor()
	var cell := Vector2i(((point - origin) / CELL).floor())
	if cell.x < 0 or cell.y < 0 or cell.x >= board.width or cell.y >= board.height:
		return Vector2i(-1, -1)
	return cell


func _board_tap(point: Vector2) -> void:
	var cell := cell_at(point)
	if cell.x >= 0:
		cursor = cell
		turn(cell)


func turn(cell: Vector2i) -> void:
	board.rotate(cell)
	EventBus.sfx_requested.emit("click")
	if board.is_solved():
		_win()


func _draw_board() -> void:
	if board == null:
		return
	var origin := ((_board.size - Vector2(board.width, board.height) * CELL) / 2.0).floor()
	var lit := board.powered()
	var on := PIPE_ON if _style == "pipe" else WIRE_ON
	for y in board.height:
		for x in board.width:
			var cell := Vector2i(x, y)
			var at := origin + Vector2(x, y) * CELL
			_board.draw_rect(Rect2(at, Vector2(CELL, CELL)), Color("#141a22"))
			_board.draw_rect(Rect2(at, Vector2(CELL, CELL)), Color("#26303c"), false, 1.0)
			var centre := at + Vector2(CELL, CELL) / 2.0
			var color := on if lit.has(cell) else OFF
			var width := 4.0 if _style == "pipe" else 2.0
			var mask := board.piece(cell)
			for side in CircuitBoard.SIDES:
				if mask & side:
					var direction := Vector2(CircuitBoard.STEP[side])
					_board.draw_line(centre, centre + direction * CELL / 2.0, color, width)
			_board.draw_circle(centre, width * 0.6, color)
			if cell == board.source:
				_board.draw_rect(Rect2(centre - Vector2(5, 5), Vector2(10, 10)), Color("#e0584a"))
				_board.draw_rect(Rect2(centre - Vector2(3, 3), Vector2(6, 6)), on)
			elif board.is_end(cell):
				_board.draw_circle(centre, 4.5, Color("#0c0f14"))
				_board.draw_circle(centre, 3.5, on if lit.has(cell) else Color("#3a3f48"))
	var focus := origin + Vector2(cursor) * CELL
	var pulse := 0.6 + 0.4 * sin(Time.get_ticks_msec() * 0.008)
	_board.draw_rect(Rect2(focus, Vector2(CELL, CELL)).grow(-1.0), Color(1, 1, 1, pulse), false, 1.0)
	var ends := 0
	var lit_ends := 0
	for y in board.height:
		for x in board.width:
			if board.is_end(Vector2i(x, y)):
				ends += 1
				lit_ends += 1 if lit.has(Vector2i(x, y)) else 0
	_text(Vector2(4, _board.size.y - 4), "%s %d / %d" % ["TAPS" if _style == "pipe" else "LAMPS", lit_ends, ends], UiTheme.COLOR_MUTED)
