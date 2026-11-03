extends Node
## Read-only story content: lessons, dialogue, repair recipes and objectives.
## Everything is loaded from data/*.json so writers can edit without code.

const LESSONS_PATH := "res://data/lessons.json"
const DIALOGUE_PATH := "res://data/dialogue.json"
const REPAIRS_PATH := "res://data/repairs.json"
const OBJECTIVES_PATH := "res://data/objectives.json"
const AREAS_PATH := "res://data/areas.json"
const QUIZZES_PATH := "res://data/quizzes.json"
const PUZZLES_PATH := "res://data/puzzles.json"
const QUESTS_PATH := "res://data/quests.json"

var _areas: Dictionary = {}
var _lessons: Dictionary = {}
var _dialogue: Dictionary = {}
var _repairs: Dictionary = {}
var _objectives: Array = []
var _quizzes: Array = []
var _puzzles: Dictionary = {}
var _quests: Array = []


func _ready() -> void:
	_areas = DataLoader.index_by_id(AREAS_PATH)
	_lessons = DataLoader.index_by_id(LESSONS_PATH)
	_dialogue = DataLoader.index_by_id(DIALOGUE_PATH)
	_repairs = DataLoader.index_by_id(REPAIRS_PATH)
	var objectives: Variant = DataLoader.load_json(OBJECTIVES_PATH)
	_objectives = objectives if typeof(objectives) == TYPE_ARRAY else []
	var quizzes: Variant = DataLoader.load_json(QUIZZES_PATH)
	_quizzes = quizzes if typeof(quizzes) == TYPE_ARRAY else []
	var quests: Variant = DataLoader.load_json(QUESTS_PATH)
	_quests = quests if typeof(quests) == TYPE_ARRAY else []
	_puzzles = DataLoader.index_by_id(PUZZLES_PATH)


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


func quizzes() -> Array:
	return _quizzes.duplicate(true)


func puzzle(puzzle_id: String) -> Dictionary:
	return _puzzles.get(puzzle_id, {}).duplicate(true)


func quests() -> Array:
	return _quests.duplicate(true)
