extends Node
## Holds back on-screen notices (objective banners, quest and XP toasts, level
## ups) while a conversation is open, and shows them the moment it ends, so
## nothing talks over the dialogue.

var _holding := false
var _waiting: Array[Callable] = []


func _ready() -> void:
	EventBus.dialogue_opened.connect(_hold)
	EventBus.dialogue_finished.connect(_release.unbind(1))
	EventBus.dialogue_interrupted.connect(_release)


func is_holding() -> bool:
	return _holding


func waiting() -> int:
	return _waiting.size()


## Runs `action` now, or right after the current conversation ends.
func run(action: Callable) -> void:
	if _holding:
		_waiting.append(action)
	else:
		action.call()


func _hold() -> void:
	_holding = true


func _release() -> void:
	_holding = false
	var batch := _waiting.duplicate()
	_waiting.clear()
	for action: Callable in batch:
		if action.is_valid():
			action.call()
