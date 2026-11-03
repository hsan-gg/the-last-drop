class_name ArchiveTerminal
extends Interactable
## A records terminal. Once its repair is done it plays its dialogue. In the last
## built chapter that dialogue is followed by the ending; earlier chapters just
## record the archive as read and let the player continue.

const ENDING_SCENE := "res://ui/ending.tscn"
const OFF := preload("res://assets/sprites/terminal_off.png")
const ON := preload("res://assets/sprites/terminal_on.png")

## An ordering puzzle to solve before the records unlock; empty for none.
@export var puzzle_id: String = ""
@export var chapter_id: String = "factory"
@export var required_flag: String = "power_restored"
@export var read_flag: String = "archive_read"
## Played when this is the last built chapter.
@export var final_dialogue: String = "archive_truth"
## Played when the story continues to another chapter.
@export var continue_dialogue: String = "archive_partial"

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	super()
	interacted.connect(_on_interacted)
	EventBus.flag_changed.connect(_refresh.unbind(2))
	EventBus.dialogue_finished.connect(_on_dialogue_finished)
	EventBus.puzzle_finished.connect(_on_puzzle_finished)
	_refresh()


func _on_interacted(_by: Node) -> void:
	if not GameState.has_flag(required_flag):
		EventBus.dialogue_requested.emit("terminal_locked")
		return
	if not puzzle_id.is_empty() and not GameState.has_flag(PuzzlePanel.SOLVED_FLAG_FORMAT % puzzle_id):
		EventBus.puzzle_requested.emit(puzzle_id)
		return
	_read_records()


func _read_records() -> void:
	GameState.set_flag(read_flag)
	EventBus.sfx_requested.emit("reveal")
	EventBus.dialogue_requested.emit(_dialogue_to_play())


func _on_puzzle_finished(finished_id: String, solved: bool) -> void:
	if solved and finished_id == puzzle_id:
		_read_records()


func _dialogue_to_play() -> String:
	return final_dialogue if Chapters.is_final_built(chapter_id) else continue_dialogue


func _on_dialogue_finished(dialogue_id: String) -> void:
	if dialogue_id == final_dialogue and Chapters.is_final_built(chapter_id):
		SceneManager.change_scene(ENDING_SCENE)


func _refresh() -> void:
	var powered := GameState.has_flag(required_flag)
	_sprite.texture = ON if powered else OFF
	set_prompt("Read the archive" if powered else "Check the terminal")
