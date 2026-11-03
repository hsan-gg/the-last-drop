extends Node
## Story and progress state: boolean flags (e.g. "water_tested") and numeric
## counters (e.g. "sort_mistakes"). Dictionaries are replaced on every write
## rather than mutated in place.

var _flags: Dictionary = {}
var _counters: Dictionary = {}


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


func get_counter(key: String) -> int:
	return _counters.get(key, 0)


func reset() -> void:
	_flags = {}
	_counters = {}
