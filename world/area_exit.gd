class_name AreaExit
extends Interactable
## A gate to another area. Stays shut until its required story flag is set.

@export_file("*.tscn") var target_scene: String = ""
@export var required_flag: String = ""
@export var prompt: String = "Open the gate"


func _ready() -> void:
	super()
	set_prompt(prompt)
	interacted.connect(_on_interacted)


func is_open() -> bool:
	return required_flag.is_empty() or GameState.has_flag(required_flag)


func _on_interacted(_by: Node) -> void:
	if not is_open():
		EventBus.dialogue_requested.emit("exit_locked")
		return
	EventBus.sfx_requested.emit("click")
	SceneManager.change_scene(target_scene)
