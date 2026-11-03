class_name Player
extends CharacterBody2D

const SPEED := 70.0
const SHAKE_PIXELS := 3.0
const SHAKE_STEPS := 6
const SHAKE_STEP_SECONDS := 0.04

@onready var _interactor: Interactor = $Interactor
@onready var _sprite: PlayerSprite = $Sprite
@onready var _camera: Camera2D = $Camera2D

## The direction the player last moved or aimed; attacks and the guard use it.
var facing := Vector2.DOWN

var combat: PlayerCombat

var _spawn_position := Vector2.ZERO


func _ready() -> void:
	add_to_group("player")
	collision_mask = 1 | 4  # walls and zombies: walking into a zombie stops you instead of shoving it
	add_child(SwordSwing.new())
	combat = PlayerCombat.new()
	combat.name = "Combat"
	add_child(combat)
	var guard_meter := GuardMeter.new()
	guard_meter.name = "GuardMeter"
	add_child(guard_meter)
	var visuals := GearVisuals.new()
	visuals.name = "GearVisuals"
	add_child(visuals)
	_spawn_position = global_position
	EventBus.player_collapsed.connect(respawn)
	EventBus.damage_taken.connect(_shake)


func _shake(amount: float) -> void:
	var weight := clampf(amount / 25.0, 0.2, 1.0)
	var tween := create_tween()
	for step in SHAKE_STEPS:
		var falloff := 1.0 - float(step) / SHAKE_STEPS
		var jitter := Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * SHAKE_PIXELS * falloff * weight
		tween.tween_property(_camera, "offset", jitter, SHAKE_STEP_SECONDS)
	tween.tween_property(_camera, "offset", Vector2.ZERO, SHAKE_STEP_SECONDS)


## Moves the player and makes this the spot they return to after a collapse.
func place_at(position_in_world: Vector2) -> void:
	global_position = position_in_world
	_spawn_position = position_in_world


func respawn() -> void:
	global_position = _spawn_position
	velocity = Vector2.ZERO


## Plays the swing animation for `seconds` in the given direction.
func play_attack(direction: Vector2, seconds: float) -> void:
	_sprite.play_attack(direction, seconds)


## An enemy hit. Returns {"outcome", "damage"} from the combat rules.
func receive_hit(raw_damage: float, from_position: Vector2) -> Dictionary:
	return combat.receive_hit(raw_damage, from_position)


func _physics_process(_delta: float) -> void:
	var direction := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if direction != Vector2.ZERO and not combat.is_busy():
		facing = direction.normalized()
	velocity = direction * SPEED * Survival.speed_multiplier() * combat.move_factor()
	move_and_slide()
	if not combat.is_busy():
		_sprite.face(facing if combat.is_blocking() else direction, direction != Vector2.ZERO)
	_sprite.scale = Vector2(1.08, 0.92) if combat.is_blocking() else Vector2.ONE


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact"):
		_interactor.interact()
