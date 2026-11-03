extends Node
## Story and progress state: boolean flags (e.g. "water_tested") and numeric
## counters (e.g. "sort_mistakes"). Dictionaries are replaced on every write
## rather than mutated in place.

var _flags: Dictionary = {}
var _counters: Dictionary = {}
## Seeds the random pile contents, so a run keeps its piles but each run differs.
var run_seed := 0


func set_flag(key: String, value: Variant = true) -> void:
	_flags = _flags.merged({key: value}, true)
	EventBus.flag_changed.emit(key, value)


func get_flag(key: String, default: Variant = false) -> Variant:
	return _flags.get(key, default)


func has_flag(key: String) -> bool:
	return bool(_flags.get(key, false))


func add_to_counter(key: String, amount: int = 1) -> void:
	_counters = _counters.merged({key: get_counter(key) + amount}, true)
	EventBus.counter_changed.emit(key, _counters[key])


func set_counter(key: String, value: int) -> void:
	_counters = _counters.merged({key: value}, true)
	EventBus.counter_changed.emit(key, value)


func has_counter(key: String) -> bool:
	return _counters.has(key)


func get_counter(key: String) -> int:
	return _counters.get(key, 0)


## How many set flags start with `prefix` (e.g. every slain_outpost_ flag).
func count_flags_with_prefix(prefix: String) -> int:
	var total := 0
	for key: String in _flags:
		if key.begins_with(prefix) and bool(_flags[key]):
			total += 1
	return total


func reset() -> void:
	_flags = {}
	_counters = {}
	run_seed = randi()
