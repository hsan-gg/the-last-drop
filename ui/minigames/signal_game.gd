class_name SignalGame
extends MiniGame
## Repeat the signal: lights flash in a pattern (a radio handshake, a robot's
## diagnostic); press them back in the same order with the arrow keys or 1-4.
## Each round adds one light.

const COLORS: Array[Color] = [Color("#e0584a"), Color("#7bc043"), Color("#3aa0e0"), Color("#f2c94c")]
const ARROWS := ["UP", "RIGHT", "DOWN", "LEFT"]
const FLASH_SECONDS := 0.42

var sequence: SignalSequence
var _showing := false
var _show_index := 0
var _show_clock := 0.0
var _lit := -1
var _lit_clock := 0.0


func _init() -> void:
	super()
	kind = "signal"


func _start(data: Dictionary) -> void:
	sequence = SignalSequence.new(4, int(data.get("length", 6)), int(data.get("seed", Time.get_ticks_msec())), int(data.get("start", 3)))
	_play_sequence()
	_hint.text = TouchControls.hint("Watch, then repeat: arrows or 1-4   Esc leave", "Watch, then repeat: tap the lights or 1-4   BACK leave")


func _play_sequence() -> void:
	_showing = true
	_show_index = 0
	_show_clock = -0.5


func _process(delta: float) -> void:
	super(delta)
	if not visible:
		return
	_lit_clock -= delta
	if _lit_clock <= 0.0:
		_lit = -1
	if not _showing:
		return
	_show_clock += delta
	if _show_clock >= FLASH_SECONDS:
		_show_clock = 0.0
		if _show_index >= sequence.sequence.size():
			_showing = false
			_say("[color=#9fb0bb]Your turn.[/color]")
			return
		_light(sequence.sequence[_show_index])
		_show_index += 1


func _light(index: int) -> void:
	_lit = index
	_lit_clock = FLASH_SECONDS * 0.7
	AudioManager.play("voice", 0.8 + index * 0.25)


func _board_input(event: InputEvent) -> void:
	if _showing:
		return
	var light := -1
	var step := arrow_step(event)
	if step == Vector2i.UP:
		light = 0
	elif step == Vector2i.RIGHT:
		light = 1
	elif step == Vector2i.DOWN:
		light = 2
	elif step == Vector2i.LEFT:
		light = 3
	var key := event as InputEventKey
	if key != null and key.keycode >= KEY_1 and key.keycode <= KEY_4:
		light = key.keycode - KEY_1
	if light >= 0:
		press(light)


func press(light: int) -> void:
	_light(light)
	match sequence.press(light):
		"wrong":
			_mistake("Static. The pattern starts over.", 3.0)
			_play_sequence()
		"round":
			EventBus.sfx_requested.emit("sort_ok")
			_say("[color=#7bc043]Good. Again, one longer.[/color]")
			_play_sequence()
		"won":
			_win()


const SPOTS := [Vector2(0, -34), Vector2(42, 0), Vector2(0, 34), Vector2(-42, 0)]


func light_at(point: Vector2) -> int:
	for index in 4:
		if point.distance_to(_board.size / 2.0 + SPOTS[index]) <= 18.0:
			return index
	return -1


func _board_tap(point: Vector2) -> void:
	var light := light_at(point)
	if light >= 0:
		press(light)


func _draw_board() -> void:
	var centre := _board.size / 2.0
	var spots := SPOTS
	_board.draw_circle(centre, 22.0, Color("#141a22"))
	for index in 4:
		var color: Color = COLORS[index]
		var lit := index == _lit
		var at: Vector2 = centre + spots[index]
		if lit:
			_board.draw_circle(at, 18.0, Color(color.r, color.g, color.b, 0.35))
		_board.draw_circle(at, 12.0, color if lit else color.darkened(0.65))
		_board.draw_arc(at, 12.0, 0.0, TAU, 20, color.darkened(0.2), 1.0)
		_text(at + Vector2(-32, 24 if index != 0 else -16), "%d %s" % [index + 1, ARROWS[index]], UiTheme.COLOR_MUTED, 8, 64, HORIZONTAL_ALIGNMENT_CENTER)
	if sequence != null:
		_text(Vector2(8, 14), "LENGTH %d / %d" % [sequence.sequence.size(), sequence.target_length], UiTheme.COLOR_MUTED)
