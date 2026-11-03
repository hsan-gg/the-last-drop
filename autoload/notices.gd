extends Node
## Holds back on-screen notices (objectives, quests, XP, loot, level ups) so
## nothing talks over a conversation. A notice never appears in the same moment
## it was raised: it waits a couple of frames, because talking to something
## often changes a flag and opens a conversation in the same instant, and the
## notice must lose that race. After a conversation ends there is a short,
## calm pause before held notices arrive.

const SETTLE_FRAMES := 2
const AFTER_TALK_SECONDS := 0.45

var _holding := false
var _waiting: Array[Dictionary] = []
var _resume_at := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	EventBus.dialogue_opened.connect(_hold)
	EventBus.dialogue_finished.connect(_release.unbind(1))
	EventBus.dialogue_interrupted.connect(_release)


func is_holding() -> bool:
	return _holding


func waiting() -> int:
	return _waiting.size()


## Runs `action` shortly, once no conversation is open.
func run(action: Callable) -> void:
	_waiting.append({"action": action, "frame": Engine.get_process_frames()})


func clear() -> void:
	_holding = false
	_waiting.clear()
	_resume_at = 0.0


func _process(_delta: float) -> void:
	if _holding or _waiting.is_empty() or _now() < _resume_at:
		return
	var ready: Array[Dictionary] = []
	var later: Array[Dictionary] = []
	for entry in _waiting:
		(ready if Engine.get_process_frames() - int(entry["frame"]) >= SETTLE_FRAMES else later).append(entry)
	_waiting = later
	for entry in ready:
		var action: Callable = entry["action"]
		if action.is_valid():
			action.call()


func _hold() -> void:
	_holding = true


func _release() -> void:
	_holding = false
	_resume_at = _now() + AFTER_TALK_SECONDS


func _now() -> float:
	return Time.get_ticks_msec() / 1000.0
