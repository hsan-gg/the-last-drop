extends Node
## Story cutscenes from data/cutscenes.json. `play()` shows one and then goes
## on to the next scene; each plays once per run unless forced.

const SCENE := "res://ui/cutscene.tscn"
const DATA_PATH := "res://data/cutscenes.json"
const SEEN_FLAG_FORMAT := "cutscene_seen_%s"

## Tests turn this off so a cutscene never replaces the test runner's scene.
var changes_scene := true
var pending_id := ""
var pending_next := ""

var _data: Dictionary = {}


func _ready() -> void:
	var loaded: Variant = DataLoader.load_json(DATA_PATH)
	_data = loaded if typeof(loaded) == TYPE_DICTIONARY else {}


func exists(cutscene_id: String) -> bool:
	return _data.has(cutscene_id)


func beats(cutscene_id: String) -> Array:
	return _data.get(cutscene_id, []).duplicate(true)


func ids() -> Array:
	return _data.keys()


func has_seen(cutscene_id: String) -> bool:
	return GameState.has_flag(SEEN_FLAG_FORMAT % cutscene_id)


func mark_seen(cutscene_id: String) -> void:
	GameState.set_flag(SEEN_FLAG_FORMAT % cutscene_id)


## Shows the cutscene (once), then moves on to `next_scene`.
func play(cutscene_id: String, next_scene: String) -> void:
	if not exists(cutscene_id) or has_seen(cutscene_id):
		_go(next_scene)
		return
	pending_id = cutscene_id
	pending_next = next_scene
	_go(SCENE)


func finish() -> void:
	mark_seen(pending_id)
	var next := pending_next
	pending_id = ""
	pending_next = ""
	_go(next)


func _go(scene_path: String) -> void:
	if changes_scene and not scene_path.is_empty():
		SceneManager.change_scene(scene_path)
