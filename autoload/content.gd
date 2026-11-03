extends Node
## Read-only story content: lessons, dialogue, repair recipes and objectives.
## Everything is loaded from data/*.json so writers can edit without code.

const LESSONS_PATH := "res://data/lessons.json"
const DIALOGUE_PATH := "res://data/dialogue.json"
const REPAIRS_PATH := "res://data/repairs.json"
const OBJECTIVES_PATH := "res://data/objectives.json"
const AREAS_PATH := "res://data/areas.json"

var _areas: Dictionary = {}
var _lessons: Dictionary = {}
var _dialogue: Dictionary = {}
var _repairs: Dictionary = {}
var _objectives: Array = []


func _ready() -> void:
	_areas = DataLoader.index_by_id(AREAS_PATH)
	_lessons = DataLoader.index_by_id(LESSONS_PATH)
	_dialogue = DataLoader.index_by_id(DIALOGUE_PATH)
	_repairs = DataLoader.index_by_id(REPAIRS_PATH)
	var objectives: Variant = DataLoader.load_json(OBJECTIVES_PATH)
	_objectives = objectives if typeof(objectives) == TYPE_ARRAY else []


func area(area_id: String) -> Dictionary:
	return _areas.get(area_id, {}).duplicate(true)


func lesson(lesson_id: String) -> Dictionary:
	return _lessons.get(lesson_id, {}).duplicate()


func dialogue(dialogue_id: String) -> Array[String]:
	var lines: Array[String] = []
	for line: Variant in _dialogue.get(dialogue_id, {}).get("lines", []):
		lines.append(str(line))
	return lines


func repair(repair_id: String) -> Dictionary:
	return _repairs.get(repair_id, {}).duplicate(true)


func objectives() -> Array:
	return _objectives.duplicate(true)
