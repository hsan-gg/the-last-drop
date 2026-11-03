class_name PlayerCombat
extends Node
## The player's fighting: attack (J or left click), block (K or right click, hold)
## and what happens when something hits back. The arithmetic lives in CombatRules.

enum State { IDLE, ATTACK, BLOCK }

const WINDUP_SECONDS := 0.07
const ACTIVE_SECONDS := 0.12
const RECOVER_SECONDS := 0.2
const REACH := 26.0
const ARC_HALF_ANGLE := 70.0
const KNOCKBACK := 120.0
const HIT_STOP_SECONDS := 0.05
const HURT_INVULNERABLE_SECONDS := 0.55
const BLOCK_INVULNERABLE_SECONDS := 0.2
const PARRY_INVULNERABLE_SECONDS := 0.45
const PARRY_XP := 6
const ATTACK_MOVE_FACTOR := 0.35
const BLOCK_MOVE_FACTOR := 0.5
const BODY_OFFSET := Vector2(0, -6)

var state := State.IDLE

var _clock := 0.0
var _state_started := 0.0
var _swung := false
var _block_started := -10.0
var _invulnerable_until := 0.0
var _player: Player
var _swing: SwordSwing


func _ready() -> void:
	_player = get_parent() as Player
	_swing = _player.get_node_or_null("Swing") as SwordSwing


func is_busy() -> bool:
	return state == State.ATTACK


func is_blocking() -> bool:
	return state == State.BLOCK


func move_factor() -> float:
	match state:
		State.ATTACK:
			return ATTACK_MOVE_FACTOR
		State.BLOCK:
			return BLOCK_MOVE_FACTOR
	return 1.0


## Seconds the guard has been up; large when it is not.
func seconds_since_block_started() -> float:
	return _clock - _block_started


func attack() -> void:
	if state != State.IDLE:
		return
	state = State.ATTACK
	_state_started = _clock
	_swung = false
	var facing := _player.facing
	_player.play_attack(facing, WINDUP_SECONDS + ACTIVE_SECONDS + RECOVER_SECONDS)
	EventBus.sfx_requested.emit("swing")
	if _swing != null:
		_swing.swing(facing, WINDUP_SECONDS + ACTIVE_SECONDS, Gear.weapon_color())


func raise_guard() -> void:
	if state != State.IDLE:
		return
	state = State.BLOCK
	_block_started = _clock
	if _swing != null:
		_swing.guard(true, _player.facing)


func lower_guard() -> void:
	if state != State.BLOCK:
		return
	state = State.IDLE
	if _swing != null:
		_swing.guard(false, _player.facing)


func _physics_process(delta: float) -> void:
	_clock += delta
	if Input.is_action_just_pressed("attack"):
		attack()
	if Input.is_action_just_pressed("block"):
		raise_guard()
	if state == State.BLOCK and not Input.is_action_pressed("block"):
		lower_guard()
	if state == State.BLOCK and _swing != null:
		_swing.guard(true, _player.facing)
	if state == State.ATTACK:
		_run_attack()


func _run_attack() -> void:
	var elapsed := _clock - _state_started
	if not _swung and elapsed >= WINDUP_SECONDS:
		_swung = true
		_strike()
	if elapsed >= WINDUP_SECONDS + ACTIVE_SECONDS + RECOVER_SECONDS:
		state = State.IDLE


func _strike() -> void:
	var damage := CombatRules.player_damage(Gear.weapon_damage(), Progress.level)
	var origin := _player.global_position + BODY_OFFSET
	var hit_any := false
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy == null or enemy.is_dead():
			continue
		if CombatRules.in_arc(origin, _player.facing, enemy.global_position + BODY_OFFSET, REACH, ARC_HALF_ANGLE):
			enemy.take_hit(damage, origin, KNOCKBACK)
			hit_any = true
	if hit_any:
		EventBus.sfx_requested.emit("hit")
		Juicee.hit_stop(self, HIT_STOP_SECONDS)
		Juicee.shake_camera(self, 1.5, 0.1)


## An enemy strike lands on the player. Returns {"outcome", "damage"}.
func receive_hit(raw_damage: float, from_position: Vector2) -> Dictionary:
	if _clock < _invulnerable_until:
		return {"outcome": "ignored", "damage": 0}
	var covers := CombatRules.guard_covers(_player.facing, _player.global_position, from_position)
	var result := CombatRules.resolve_hit(raw_damage, Gear.armor(), is_blocking(), covers, seconds_since_block_started())
	match result["outcome"]:
		CombatRules.OUTCOME_PARRIED:
			_invulnerable_until = _clock + PARRY_INVULNERABLE_SECONDS
			EventBus.sfx_requested.emit("parry")
			GameState.add_to_counter("parries")
			Progress.add_xp(PARRY_XP)
			FloatingText.spawn(_player.get_parent(), "PARRY!", _player.global_position, Color("#7fe0ff"))
			if _swing != null:
				_swing.parry_flash()
		CombatRules.OUTCOME_BLOCKED:
			_invulnerable_until = _clock + BLOCK_INVULNERABLE_SECONDS
			EventBus.sfx_requested.emit("block")
			GameState.add_to_counter("blocks")
			Survival.damage(result["damage"])
			FloatingText.spawn(_player.get_parent(), str(result["damage"]), _player.global_position, Color("#a0d8ff"))
		_:
			_invulnerable_until = _clock + HURT_INVULNERABLE_SECONDS
			EventBus.sfx_requested.emit("hurt")
			Survival.damage(result["damage"])
			FloatingText.spawn(_player.get_parent(), str(result["damage"]), _player.global_position, Color("#ff6a5a"))
	EventBus.player_hit.emit(result["outcome"], result["damage"])
	return result
