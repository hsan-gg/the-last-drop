class_name ConveyorGame
extends MiniGame
## The sorting line: rubbish rides a conveyor belt towards the shredder. Press
## the bin's number (1-4) to knock the front item into it before it falls off
## the end. Sort enough right and the line is yours; too many misses and the
## belt runs again.

const BELT_Y := 56.0
const BELT_START := 20.0
const BELT_END := 400.0
const SPACING := 52.0

var queue: Array[String] = []
var positions: Array[float] = []
var correct := 0
var missed := 0
var _speed := 34.0
var _need := 8
var _total := 10


func _init() -> void:
	kind = "conveyor"


func _start(data: Dictionary) -> void:
	_speed = float(data.get("speed", 34.0))
	var pool: Array = data.get("pool", ["scrap_metal", "battery", "cardboard", "banana_peel"])
	_total = int(data.get("count", 10))
	_need = int(data.get("need", _total - 2))
	var rng := RandomNumberGenerator.new()
	rng.seed = int(data.get("seed", Time.get_ticks_msec()))
	queue.clear()
	positions.clear()
	for index in _total:
		queue.append(str(pool[rng.randi_range(0, pool.size() - 1)]))
		positions.append(BELT_START - index * SPACING)
	correct = 0
	missed = 0
	_hint.text = "1 General  2 Hazardous  3 Recover  4 Compost   Esc leave"


func _process(delta: float) -> void:
	super(delta)
	if not visible or _phase != Phase.PLAYING or queue.is_empty():
		return
	for index in positions.size():
		positions[index] += _speed * delta
	if positions[0] >= BELT_END:
		_drop_front(false)
		_mistake("It went into the shredder unsorted.", 3.0)


func _board_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key == null:
		return
	var bins := {KEY_1: SortingRules.BIN_GENERAL, KEY_2: SortingRules.BIN_HAZARDOUS, KEY_3: SortingRules.BIN_RECOVERY, KEY_4: SortingRules.BIN_COMPOST}
	if bins.has(key.keycode):
		sort_front(bins[key.keycode])


## Knocks the front item into `bin_id` (only once it is on the belt).
func sort_front(bin_id: String) -> void:
	if queue.is_empty() or positions[0] < BELT_START:
		return
	if SortingRules.correct_bin(queue[0]) == bin_id:
		EventBus.sfx_requested.emit("sort_ok")
		_drop_front(true)
	else:
		var item := ItemDB.display_name(queue[0])
		_drop_front(false)
		_mistake("%s does not go there." % item, 3.0)


func _drop_front(right: bool) -> void:
	queue.remove_at(0)
	positions.remove_at(0)
	if right:
		correct += 1
	else:
		missed += 1
	if queue.is_empty():
		_finish()


func _finish() -> void:
	if correct >= _need:
		_win()
		return
	_say("[color=#f2c94c]%d of %d sorted: you need %d. The belt starts again.[/color]" % [correct, _total, _need])
	_start(_data)


func _draw_board() -> void:
	var belt := Rect2(Vector2(BELT_START - 14, BELT_Y), Vector2(BELT_END - BELT_START + 28, 14))
	_board.draw_rect(belt, Color("#2a2a30"))
	var offset := fposmod(Time.get_ticks_msec() * 0.001 * _speed, 10.0)
	for x in range(int(belt.position.x), int(belt.end.x), 10):
		_board.draw_line(Vector2(x + offset, BELT_Y + 2), Vector2(x + offset, BELT_Y + 12), Color("#3a3a44"), 1.0)
	_board.draw_rect(Rect2(Vector2(BELT_END + 8, BELT_Y - 14), Vector2(14, 34)), Color("#5a2020"))
	_text(Vector2(BELT_END - 20, BELT_Y + 32), "SHREDDER", Color("#e0584a"), 8)
	for index in queue.size():
		var x := positions[index]
		if x < BELT_START - 16:
			continue
		var icon := ItemDB.icon(queue[index])
		var at := Vector2(x - 8, BELT_Y - 16)
		if icon != null:
			_board.draw_texture_rect(icon, Rect2(at, Vector2(16, 16)), false)
		else:
			_board.draw_rect(Rect2(at, Vector2(14, 14)), Color("#a0a0a0"))
		if index == 0:
			_board.draw_rect(Rect2(at - Vector2(2, 2), Vector2(20, 20)), Color(1, 1, 1, 0.7), false, 1.0)
	if not queue.is_empty() and positions[0] >= BELT_START:
		_text(Vector2(10, 18), ItemDB.display_name(queue[0]), UiTheme.COLOR_YELLOW)
	_text(Vector2(10, _board.size.y - 6), "SORTED %d   MISSED %d   NEED %d" % [correct, missed, _need], UiTheme.COLOR_MUTED)
