extends Node
## The four difficulty levels. Each is a set of multipliers over the Medium
## game, defined in data/difficulties.json and chosen when a run starts. They
## change visible things (zombie strength and numbers, lives, penalties, XP,
## thirst, healing), and the title screen says what each one does.

const DATA_PATH := "res://data/difficulties.json"
const DEFAULT_ID := "medium"

var current_id := DEFAULT_ID

var _levels: Array = []


func _ready() -> void:
	var loaded: Variant = DataLoader.load_json(DATA_PATH)
	_levels = loaded if typeof(loaded) == TYPE_ARRAY else []


func all() -> Array:
	return _levels.duplicate(true)


func definition(difficulty_id: String) -> Dictionary:
	for level: Dictionary in _levels:
		if level["id"] == difficulty_id:
			return level.duplicate()
	return {}


func current() -> Dictionary:
	var level := definition(current_id)
	return level if not level.is_empty() else definition(DEFAULT_ID)


## A multiplier or setting of the current difficulty, e.g. value("enemy_hp").
func value(key: String) -> float:
	return float(current().get(key, 1.0))


func select(difficulty_id: String) -> void:
	if not definition(difficulty_id).is_empty():
		current_id = difficulty_id
		Settings.set_value("difficulty", difficulty_id)


## Called when a run starts: the saved choice becomes the run's difficulty.
func begin_run() -> void:
	var saved := str(Settings.value("difficulty"))
	current_id = saved if not definition(saved).is_empty() else DEFAULT_ID
