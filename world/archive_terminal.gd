class_name ArchiveTerminal
extends Interactable
## The factory terminal. With power restored it links to the Last Sanctuary's
## archive, delivers the truth, then hands over to the ending.

const ENDING_SCENE := "res://ui/ending.tscn"
const TRUTH_DIALOGUE := "archive_truth"
const OFF := preload("res://assets/sprites/terminal_off.png")
const ON := preload("res://assets/sprites/terminal_on.png")

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	super()
	interacted.connect(_on_interacted)
	EventBus.flag_changed.connect(_refresh.unbind(2))
	EventBus.dialogue_finished.connect(_on_dialogue_finished)
	_refresh()


func _on_interacted(_by: Node) -> void:
	if not GameState.has_flag("power_restored"):
		EventBus.dialogue_requested.emit("terminal_locked")
		return
	GameState.set_flag("archive_read")
	EventBus.sfx_requested.emit("reveal")
	EventBus.dialogue_requested.emit(TRUTH_DIALOGUE)


func _on_dialogue_finished(dialogue_id: String) -> void:
	if dialogue_id == TRUTH_DIALOGUE:
		SceneManager.change_scene(ENDING_SCENE)


func _refresh() -> void:
	var powered := GameState.has_flag("power_restored")
	_sprite.texture = ON if powered else OFF
	set_prompt("Read the archive" if powered else "Check the terminal")
