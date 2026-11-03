class_name Player
extends CharacterBody2D

const SPEED := 70.0
const SHAKE_PIXELS := 3.0
const SHAKE_STEPS := 6
const SHAKE_STEP_SECONDS := 0.04

@onready var _interactor: Interactor = $Interactor
@onready var _sprite: PlayerSprite = $Sprite
@onready var _camera: Camera2D = $Camera2D

var _spawn_position := Vector2.ZERO


func _ready() -> void:
	_spawn_position = global_position
	EventBus.player_collapsed.connect(respawn)
	EventBus.damage_taken.connect(_shake.unbind(1))


func _shake() -> void:
	var tween := create_tween()
	for step in SHAKE_STEPS:
		var falloff := 1.0 - float(step) / SHAKE_STEPS
		var jitter := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * SHAKE_PIXELS * falloff
		tween.tween_property(_camera, "offset", jitter, SHAKE_STEP_SECONDS)
	tween.tween_property(_camera, "offset", Vector2.ZERO, SHAKE_STEP_SECONDS)


## Moves the player and makes this the spot they return to after a collapse.
func place_at(position_in_world: Vector2) -> void:
	global_position = position_in_world
	_spawn_position = position_in_world


func respawn() -> void:
	global_position = _spawn_position
	velocity = Vector2.ZERO


func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = direction * SPEED * Survival.speed_multiplier()
	move_and_slide()
	_sprite.face(direction, direction != Vector2.ZERO)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_interactor.interact()
