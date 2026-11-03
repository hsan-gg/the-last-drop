extends CanvasLayer
## Scene changes with a fade, plus the "start a fresh run" entry point.

const FADE_SECONDS := 0.35
const TITLE_SCENE := "res://ui/title.tscn"
const FIRST_AREA := "res://world/outpost.tscn"
const GAME_OVER_SCENE := "res://ui/game_over.tscn"

var _fade: ColorRect
var _changing := false


func _ready() -> void:
	layer = 100
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.modulate.a = 0.0
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_fade)


func change_scene(path: String) -> void:
	if _changing:
		return
	_changing = true
	await _fade_to(1.0)
	get_tree().paused = false
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("SceneManager: cannot load %s (error %d)" % [path, error])
	await get_tree().process_frame
	await _fade_to(0.0)
	_changing = false


## `skip_intro` is for restarts after dying, so the opening is not replayed.
func new_game(_skip_intro: bool = false) -> void:
	reset_run()
	Combat.enemies_enabled = true
	Lives.start_run()
	change_scene(FIRST_AREA)


func go_to_game_over() -> void:
	change_scene(GAME_OVER_SCENE)


func go_to_title() -> void:
	change_scene(TITLE_SCENE)


func reset_run() -> void:
	GameState.reset()
	Inventory.clear()
	Survival.reset()
	Gear.reset()
	Progress.reset()
	Lives.reset()


func _fade_to(alpha: float) -> void:
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_fade, "modulate:a", alpha, FADE_SECONDS)
	await tween.finished
