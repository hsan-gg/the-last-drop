extends CanvasLayer
## Scene changes with a fade, plus the "start a fresh run" entry point.

const FADE_SECONDS := 0.35
const TITLE_SCENE := "res://ui/title.tscn"
const FIRST_AREA := "res://world/outpost.tscn"
const GAME_OVER_SCENE := "res://ui/game_over.tscn"
## Keys pressed during a fade, or just after it, belong to the old screen (a
## player mashing Esc to skip a cutscene must not open the menu on arrival).
const INPUT_GRACE_SECONDS := 0.4

var _fade: ColorRect
var _changing := false
## A change asked for while another was fading; it runs as soon as that one ends.
var _queued_path := ""
var _settle_until := 0.0
## Set by a gate before travelling: the map marker to arrive next to ("" = the start).
var arrival_marker := ""


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
		_queued_path = path
		return
	_changing = true
	await _fade_to(1.0)
	get_tree().paused = false
	Notices.clear()  # a conversation torn down mid-way must not hold notices forever
	var error := get_tree().change_scene_to_file(path)
	if error != OK:
		push_error("SceneManager: cannot load %s (error %d)" % [path, error])
	await get_tree().process_frame
	await _fade_to(0.0)
	_changing = false
	_settle_until = Time.get_ticks_msec() / 1000.0 + INPUT_GRACE_SECONDS
	if not _queued_path.is_empty():
		var next := _queued_path
		_queued_path = ""
		change_scene(next)


## True while a scene change is fading or has only just finished.
func is_settling() -> bool:
	return _changing or Time.get_ticks_msec() / 1000.0 < _settle_until


func _input(event: InputEvent) -> void:
	if event is InputEventKey and is_settling():
		get_viewport().set_input_as_handled()


## `skip_intro` is for restarts after dying, so the opening is not replayed.
func new_game(skip_intro: bool = false) -> void:
	reset_run()
	Combat.enemies_enabled = true
	Lives.start_run()
	if skip_intro:
		change_scene(FIRST_AREA)
	else:
		Cutscenes.play("intro", FIRST_AREA)


func go_to_game_over() -> void:
	change_scene(GAME_OVER_SCENE)


func go_to_title() -> void:
	change_scene(TITLE_SCENE)


func reset_run() -> void:
	arrival_marker = ""
	GameState.reset()
	Inventory.clear()
	Survival.reset()
	Gear.reset()
	Progress.reset()
	Lives.reset()
	MapMemory.reset()
	Chapters.reset()
	Runes.reset()
	Notices.clear()
	Tutorial.reset_run()


func _fade_to(alpha: float) -> void:
	var tween := create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	tween.tween_property(_fade, "modulate:a", alpha, FADE_SECONDS)
	await tween.finished
