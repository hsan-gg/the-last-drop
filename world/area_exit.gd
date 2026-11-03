class_name AreaExit
extends Interactable
## A gate to another area. A gate onward stays shut until its story flag is set
## and its region has been lit with the generator; a gate back is always open
## and drops you at the onward gate of the area you return to.

@export_file("*.tscn") var target_scene: String = ""
@export var required_flag: String = ""
@export var prompt: String = "Open the gate"
## A story cutscene to play (once) on the way through.
@export var cutscene: String = ""
## The area whose generator must be running before this gate opens ("" for none).
@export var requires_lit: String = ""
## Where to arrive in the target area: a map marker ("" means the usual start).
@export var arrive_marker: String = ""


func _ready() -> void:
	super()
	set_prompt(prompt)
	interacted.connect(_on_interacted)


func is_open() -> bool:
	return story_ready() and power_ready()


func story_ready() -> bool:
	return required_flag.is_empty() or GameState.has_flag(required_flag)


func power_ready() -> bool:
	return requires_lit.is_empty() or GameState.has_flag(RegionGenerator.lit_flag(requires_lit))


func _on_interacted(_by: Node) -> void:
	if not story_ready():
		EventBus.dialogue_requested.emit("exit_locked")
		return
	if not power_ready():
		EventBus.text_requested.emit([
			"The gate's motor is dead. It runs on the same power line as the lights.",
			"Clear the zombies here and start the generator, then the gate will open.",
		] as Array[String])
		return
	EventBus.sfx_requested.emit("click")
	SceneManager.arrival_marker = arrive_marker
	if cutscene.is_empty() or Cutscenes.has_seen(cutscene):
		SceneManager.change_scene(target_scene)
	else:
		Cutscenes.play(cutscene, target_scene)
