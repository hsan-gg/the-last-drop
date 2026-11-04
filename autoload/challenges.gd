extends Node
## Timed challenges people set you ("race me to the east heap!"). An NPC talk
## with a "challenge" starts one: {"seconds", "goal_flag", "win_flag",
## "lose_flag", "label"}. If the goal flag is set before the time runs out you
## win, otherwise you lose; either sets a flag the story can react to.

var _active: Dictionary = {}
var _left := 0.0


func _ready() -> void:
	EventBus.flag_changed.connect(_on_flag_changed)


func active() -> Dictionary:
	return _active


func seconds_left() -> float:
	return _left


func start(spec: Dictionary) -> void:
	if not _active.is_empty() or GameState.has_flag(spec["win_flag"]) or GameState.has_flag(spec["lose_flag"]):
		return
	_active = spec.duplicate()
	_left = float(spec["seconds"])
	EventBus.challenge_changed.emit(String(spec.get("label", "Challenge")), _left)


func reset() -> void:
	_active = {}
	_left = 0.0
	EventBus.challenge_changed.emit("", 0.0)


func _process(delta: float) -> void:
	if _active.is_empty() or get_tree().paused:
		return
	_left -= delta
	EventBus.challenge_changed.emit(String(_active.get("label", "Challenge")), maxf(_left, 0.0))
	if _left <= 0.0:
		_finish(false)


func _on_flag_changed(flag: String, value: bool) -> void:
	if value and not _active.is_empty() and flag == _active["goal_flag"]:
		_finish(true)


func _finish(won: bool) -> void:
	var spec := _active
	_active = {}
	GameState.set_flag(spec["win_flag"] if won else spec["lose_flag"])
	EventBus.challenge_changed.emit("", 0.0)
	EventBus.banner_requested.emit("YOU WIN!" if won else "TIME'S UP", String(spec.get("win_text" if won else "lose_text", "")), Color("#8fd27a") if won else Color("#ff9a5a"))
