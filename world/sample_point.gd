class_name SamplePoint
extends Interactable
## A water test spot: dip a strip, read what it says. Each point teaches
## something different, and testing all of them sets samples_done.

const SAMPLES_NEEDED := 3
const ALL_DONE_FLAG := "samples_done"

@export var sample_id: String = ""
@export var dialogue_id: String = ""

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	super()
	interacted.connect(_on_interacted)
	_refresh()


func is_tested() -> bool:
	return GameState.has_flag(_flag())


func _on_interacted(_by: Node) -> void:
	if not is_tested():
		GameState.set_flag(_flag())
		EventBus.sfx_requested.emit("reveal")
		GameState.add_to_counter("samples")
		if GameState.get_counter("samples") >= SAMPLES_NEEDED:
			GameState.set_flag(ALL_DONE_FLAG)
		_refresh()
	EventBus.dialogue_requested.emit(dialogue_id)


func _flag() -> String:
	return "sample_%s" % sample_id


func _refresh() -> void:
	_sprite.modulate = Color(0.75, 1.0, 0.75) if is_tested() else Color.WHITE
	set_prompt("Read the strip again" if is_tested() else "Test the water here")
