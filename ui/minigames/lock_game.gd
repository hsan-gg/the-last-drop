class_name LockGame
extends MiniGame
## A combination lock. The code is written down somewhere in the world (a note
## in a house, a log in another region); once you have read it, the clue shows
## here. Left/Right pick a dial, Up/Down turn it, E tries the handle.

const DIAL := Vector2(30, 40)

var digits: Array[int] = []
var selected := 0
var _code := ""


func _init() -> void:
	super()
	touch_dpad = true
	kind = "lock"


func _start(data: Dictionary) -> void:
	_code = str(data.get("code", "000"))
	digits.clear()
	for _i in _code.length():
		digits.append(0)
	selected = 0
	var clue_flag: String = data.get("clue_flag", "")
	if clue_flag.is_empty() or GameState.has_flag(clue_flag):
		_say("[color=#f2c94c]Your note:[/color] %s" % data.get("clue", ""))
	else:
		_say("[color=#9fb0bb]%s[/color]" % data.get("no_clue", "You do not know the code. Someone must have written it down."))
	_hint.text = TouchControls.hint("Left/Right dial   Up/Down turn   E try   Esc leave", "Tap the top or bottom of a dial to turn it   OK try   BACK leave")


func _board_input(event: InputEvent) -> void:
	var step := arrow_step(event)
	if step.x != 0:
		selected = wrapi(selected + step.x, 0, digits.size())
		EventBus.sfx_requested.emit("ui_move")
	elif step.y != 0:
		digits[selected] = wrapi(digits[selected] - step.y, 0, 10)
		EventBus.sfx_requested.emit("click")
	elif is_confirm(event):
		try_code()


## Which dial a point is on, and whether it is the upper half: {"dial", "up"}.
func dial_at(point: Vector2) -> Dictionary:
	var total := Vector2(digits.size() * (DIAL.x + 8) - 8, DIAL.y)
	var origin := ((_board.size - total) / 2.0).floor() - Vector2(0, 8)
	for index in digits.size():
		var box := Rect2(origin + Vector2(index * (DIAL.x + 8), 0), DIAL).grow(4.0)
		if box.has_point(point):
			return {"dial": index, "up": point.y < box.get_center().y}
	return {}


func _board_tap(point: Vector2) -> void:
	var hit := dial_at(point)
	if hit.is_empty():
		return
	selected = hit["dial"]
	digits[selected] = wrapi(digits[selected] + (-1 if hit["up"] else 1), 0, 10)
	EventBus.sfx_requested.emit("click")


func entered() -> String:
	return "".join(PackedStringArray(digits.map(func(d: int) -> String: return str(d))))


func try_code() -> void:
	if entered() == _code:
		EventBus.sfx_requested.emit("door_open")
		_win()
	else:
		_mistake("The handle will not turn. The lock sparks.", 4.0)


func _draw_board() -> void:
	var total := Vector2(digits.size() * (DIAL.x + 8) - 8, DIAL.y)
	var origin := ((_board.size - total) / 2.0).floor() - Vector2(0, 8)
	_board.draw_rect(Rect2(origin - Vector2(10, 10), total + Vector2(20, 20)), Color("#2a2420"))
	_board.draw_rect(Rect2(origin - Vector2(10, 10), total + Vector2(20, 20)), Color("#8a6a3a"), false, 2.0)
	for index in digits.size():
		var at := origin + Vector2(index * (DIAL.x + 8), 0)
		var picked := index == selected and _phase == Phase.PLAYING
		_board.draw_rect(Rect2(at, DIAL), Color("#14100e"))
		_board.draw_rect(Rect2(at, DIAL), Color("#f2c94c") if picked else Color("#5a4a30"), false, 1.0)
		_text(at + Vector2(0, 12), str(wrapi(digits[index] - 1, 0, 10)), Color("#5a4a30"), 8, DIAL.x, HORIZONTAL_ALIGNMENT_CENTER)
		_text(at + Vector2(0, 27), str(digits[index]), Color("#7bc043") if _phase == Phase.WON else UiTheme.COLOR_TEXT, 16, DIAL.x, HORIZONTAL_ALIGNMENT_CENTER)
		_text(at + Vector2(0, 38), str(wrapi(digits[index] + 1, 0, 10)), Color("#5a4a30"), 8, DIAL.x, HORIZONTAL_ALIGNMENT_CENTER)
