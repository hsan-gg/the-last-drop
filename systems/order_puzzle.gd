class_name OrderPuzzle
extends RefCounted
## Put the steps in order. A wrong pick starts the sequence over (no other
## penalty); the options are shuffled so the answer is never handed over.

var _steps: Array[String]
var _options: Array[String]
var _progress := 0
var _mistakes := 0


func _init(steps: Array[String], shuffle_seed: int = 0) -> void:
	_steps = steps.duplicate()
	_options = _shuffled(steps, shuffle_seed)


func options() -> Array[String]:
	return _options.duplicate()


## Steps placed correctly so far, in order.
func placed() -> Array[String]:
	return _steps.slice(0, _progress)


func mistakes() -> int:
	return _mistakes


func is_solved() -> bool:
	return _progress >= _steps.size()


func choose(option: String) -> Dictionary:
	if is_solved():
		return {"correct": true, "solved": true}
	if option == _steps[_progress]:
		_progress += 1
		return {"correct": true, "solved": is_solved()}
	_mistakes += 1
	_progress = 0
	return {"correct": false, "solved": false}


func _shuffled(steps: Array[String], shuffle_seed: int) -> Array[String]:
	var rng := RandomNumberGenerator.new()
	if shuffle_seed == 0:
		rng.randomize()
	else:
		rng.seed = shuffle_seed
	var result: Array[String] = steps.duplicate()
	for attempt in 8:
		for index in range(result.size() - 1, 0, -1):
			var other := rng.randi_range(0, index)
			var swap := result[index]
			result[index] = result[other]
			result[other] = swap
		if result != steps or steps.size() < 2:
			break
	return result
