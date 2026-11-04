class_name Door
extends Interactable
## A way in or out: a building's front door, the way back out of a room, a
## ladder down into the dark. Interact (or, for a walk-through door, just step
## onto it) and you go to `target_scene`, arriving by its `arrive_marker`.
## A door can stay locked until a story flag or a key item lets you in.

@export_file("*.tscn") var target_scene: String = ""
@export var arrive_marker: String = ""
@export var prompt: String = "Go in"
## Walking onto it is enough (the way out of a room, like stepping out a door).
@export var walk_through: bool = false
@export var required_flag: String = ""
## An item that opens it; used up the first time, then the door stays open.
@export var key_item: String = ""
@export var locked_text: String = "It is locked."
@export var spawn_key: String = ""

var _armed := false
## A door that leads nowhere is a barred gate in a passage: solid until opened.
var _barrier: StaticBody2D
var _bars: Sprite2D


func _ready() -> void:
	super()
	interacted.connect(_on_interacted)
	set_prompt(prompt if is_open() else "Locked")
	if target_scene.is_empty():
		_build_barrier()
	if walk_through:
		collision_mask = Player.PHYSICS_LAYER
		body_entered.connect(_on_body_entered)
		# Do not throw a player who arrives standing on it straight back out.
		get_tree().create_timer(0.6).timeout.connect(func() -> void: _armed = true)


func is_open() -> bool:
	if not required_flag.is_empty() and not GameState.has_flag(required_flag):
		return false
	return key_item.is_empty() or GameState.has_flag(_unlocked_flag())


func is_barrier() -> bool:
	return target_scene.is_empty()


func _build_barrier() -> void:
	_bars = Sprite2D.new()
	_bars.name = "Sprite"
	add_child(_bars)
	_barrier = StaticBody2D.new()
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 16)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	_barrier.add_child(collider)
	add_child(_barrier)
	_show_barrier()


func _show_barrier() -> void:
	var open := is_open()
	_bars.texture = load("res://assets/sprites/breakables/bars_%s.png" % ("open" if open else "closed"))
	_barrier.collision_layer = 0 if open else 1
	if open:
		set_prompt("The gate stands open")


func _unlocked_flag() -> String:
	return "unlocked_%s" % (spawn_key if not spawn_key.is_empty() else key_item)


func _on_body_entered(body: Node) -> void:
	if _armed and body is Player and not Modal.any_open(get_tree()):
		go()


func _on_interacted(_by: Node) -> void:
	go()


## Through the door, unlocking it first if a key is to hand.
func go() -> bool:
	if not is_open():
		if not key_item.is_empty() and (required_flag.is_empty() or GameState.has_flag(required_flag)) and Inventory.remove(key_item):
			GameState.set_flag(_unlocked_flag())
			EventBus.sfx_requested.emit("door_open")
			EventBus.loot_found.emit("Unlocked with the %s" % ItemDB.display_name(key_item))
			set_prompt(prompt)
			if _barrier != null:
				_show_barrier()
			return false
		EventBus.sfx_requested.emit("sort_bad")
		EventBus.text_requested.emit([locked_text] as Array[String])
		return false
	if target_scene.is_empty():
		return false
	EventBus.sfx_requested.emit("door_open")
	SceneManager.arrival_marker = arrive_marker
	SceneManager.change_scene(target_scene)
	return true
