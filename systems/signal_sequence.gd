class_name SignalSequence
extends RefCounted
## Repeat the signal: a sequence of lights plays; press them back in order.
## Each round adds one; get one wrong and that round replays.

var lights := 4
var target_length := 6
var sequence: Array[int] = []
var _typed := 0
var _rng := RandomNumberGenerator.new()


func _init(light_count: int, length: int, seed_value: int, start_length: int = 3) -> void:
	lights = light_count
	target_length = length
	_rng.seed = seed_value
	for _i in start_length:
		sequence.append(_rng.randi_range(0, lights - 1))


## "right" (keep going), "round" (round complete), "won", or "wrong".
func press(light: int) -> String:
	if light != sequence[_typed]:
		_typed = 0
		return "wrong"
	_typed += 1
	if _typed < sequence.size():
		return "right"
	_typed = 0
	if sequence.size() >= target_length:
		return "won"
	sequence.append(_rng.randi_range(0, lights - 1))
	return "round"
