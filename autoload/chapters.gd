extends Node
## The campaign order, read from data/chapters.json. A chapter is playable once
## its status is "built"; the ending triggers at the last built chapter, so the
## game always has an ending while later chapters are still in production.

const CHAPTERS_PATH := "res://data/chapters.json"
const STATUS_BUILT := "built"

const ENDING_SCENE := "res://ui/ending.tscn"

## Tests turn this off: a scene change would replace the test runner.
var ending_enabled := true

var _chapters: Array = []


func _ready() -> void:
	var loaded: Variant = DataLoader.load_json(CHAPTERS_PATH)
	_chapters = loaded if typeof(loaded) == TYPE_ARRAY else []
	EventBus.dialogue_finished.connect(_on_dialogue_finished.unbind(1))


func all() -> Array:
	return _chapters.duplicate(true)


func chapter(chapter_id: String) -> Dictionary:
	for entry: Dictionary in _chapters:
		if entry["id"] == chapter_id:
			return entry.duplicate(true)
	return {}


func is_built(chapter_id: String) -> bool:
	return chapter(chapter_id).get("status", "") == STATUS_BUILT


## True when no built chapter comes after this one, so finishing it ends the game.
func is_final_built(chapter_id: String) -> bool:
	var number: int = chapter(chapter_id).get("number", -1)
	if number < 0 or not is_built(chapter_id):
		return false
	for entry: Dictionary in _chapters:
		if entry.get("status", "") == STATUS_BUILT and int(entry["number"]) > number:
			return false
	return true


func chapter_for_area(area_id: String) -> Dictionary:
	for entry: Dictionary in _chapters:
		if (entry.get("areas", []) as Array).has(area_id):
			return entry.duplicate(true)
	return {}


## The last built chapter ends the game once every flag in its ending_requires is set.
func ending_ready(chapter_id: String) -> bool:
	if not is_final_built(chapter_id):
		return false
	for flag: String in chapter(chapter_id).get("ending_requires", []):
		if not GameState.has_flag(flag):
			return false
	return true


func _on_dialogue_finished() -> void:
	if not ending_enabled:
		return
	var scene := get_tree().current_scene
	if scene is GameArea and ending_ready(chapter_for_area((scene as GameArea).area_id).get("id", "")):
		ending_enabled = false
		Cutscenes.play("finale", ENDING_SCENE)
