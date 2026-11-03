class_name ArchiveTerminal
extends Interactable
## A records terminal. Once its repair is done (and its puzzle solved, if it has
## one) it plays its dialogue. Which dialogue depends on whether this is the last
## built chapter; the ending itself is triggered by Chapters, not here.

const OFF := preload("res://assets/sprites/terminal_off.png")
const ON := preload("res://assets/sprites/terminal_on.png")

## An ordering puzzle to solve before the records unlock; empty for none.
@export var puzzle_id: String = ""
## Prompt shown once the terminal is ready to use.
@export var ready_prompt: String = "Read the archive"
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


func _refresh() -> void:
	var powered := GameState.has_flag(required_flag)
	_sprite.texture = ON if powered else OFF
	set_prompt(ready_prompt if powered else "Check the terminal")
