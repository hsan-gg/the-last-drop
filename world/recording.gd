class_name Recording
extends Interactable
## An old recording: a fragment of the world's history. Each chapter places one,
## configured from data/areas.json.

@export var dialogue_id: String = "recording_1"
@export var found_flag: String = "recording_found"


func _ready() -> void:
	super()
	interacted.connect(_on_interacted)
	EventBus.flag_changed.connect(_refresh.unbind(2))
	_refresh()


func _on_interacted(_by: Node) -> void:
	GameState.set_flag(found_flag)
	EventBus.sfx_requested.emit("reveal")
	EventBus.celebrate.emit(global_position)
	EventBus.dialogue_requested.emit(dialogue_id)


func _refresh() -> void:
	set_prompt("Play the recording again" if GameState.has_flag(found_flag) else "Pick up the old recorder")
