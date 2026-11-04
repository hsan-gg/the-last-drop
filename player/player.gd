class_name Player
extends CharacterBody2D

## The player's physics layer (value 8); walls are 1, zombies 4, interactables 2.
const PHYSICS_LAYER := 8
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
	# Own layer (8) so zombies can tell the player from walls; floating motion so
	# neither body ever rides on the other (the default "grounded" mode carries
	# a body standing on another one along with it, which glued zombies to you).
	collision_layer = Player.PHYSICS_LAYER
	collision_mask = 1 | Enemy.PHYSICS_LAYER
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	var swing := SwordSwing.new()
	swing.name = "Swing"  # PlayerCombat finds it by this name
	add_child(swing)
	combat = PlayerCombat.new()
	combat.name = "Combat"
	add_child(combat)
	var caster := RuneCaster.new()
	caster.name = "RuneCaster"
	add_child(caster)
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
	combat.grant_invulnerability(Survival.COLLAPSE_GRACE_SECONDS)


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
