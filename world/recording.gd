class_name Recording
extends Interactable
## The old recording: the first fragment of the world's history.


func _ready() -> void:
	super()
	interacted.connect(_on_interacted)
	EventBus.flag_changed.connect(_refresh.unbind(2))
	_refresh()


func _on_interacted(_by: Node) -> void:
	GameState.set_flag("recording_found")
	EventBus.sfx_requested.emit("reveal")
	EventBus.celebrate.emit(global_position)
	EventBus.dialogue_requested.emit("recording_1")


func _refresh() -> void:
	set_prompt("Play the recording again" if GameState.has_flag("recording_found") else "Pick up the old recorder")
