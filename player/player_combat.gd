class_name PlayerCombat
extends Node
## The player's fighting: attack (J or left click), block (K or right click) and
## what happens when something hits back. Swinging and guarding cost stamina;
## the guard can only be held for a short time and then goes on cooldown, and a
## guard that runs out of stamina breaks. A well-timed parry is free and rewarded.
## The arithmetic lives in CombatRules.

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

const BASE_STAMINA := 100.0
const STAMINA_PER_LEVEL := 4.0
const ATTACK_COST := 14.0
const BLOCK_RAISE_COST := 6.0
const BLOCK_DRAIN_PER_SECOND := 10.0
## The guard can only be held this long before the arm tires.
const BLOCK_MAX_HOLD_SECONDS := 1.6
const BLOCK_COOLDOWN_SECONDS := 1.2
const GUARD_BREAK_COOLDOWN_SECONDS := 2.2
const BLOCKED_HIT_STAMINA_FACTOR := 0.9
const PARRY_STAMINA_REFUND := 18.0
const REGEN_PER_SECOND := 34.0
const REGEN_DELAY_SECONDS := 0.55

var state := State.IDLE
var stamina := BASE_STAMINA

var _clock := 0.0
var _state_started := 0.0
var _swung := false
var _block_started := -10.0
var _invulnerable_until := 0.0
var _block_cooldown_until := 0.0
var _block_cooldown_total := 1.0
var _regen_after := 0.0
var _last_reported_stamina := -1.0
var _player: Player
var _swing: SwordSwing


func _ready() -> void:
	_player = get_parent() as Player
	_swing = _player.get_node_or_null("Swing") as SwordSwing
	stamina = max_stamina()


func is_busy() -> bool:
	return state == State.ATTACK


func is_blocking() -> bool:
	return state == State.BLOCK


func grant_invulnerability(seconds: float) -> void:
	_invulnerable_until = maxf(_invulnerable_until, _clock + seconds)


func max_stamina() -> float:
	return BASE_STAMINA + STAMINA_PER_LEVEL * (Progress.level - 1)


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


## Seconds until the guard can be raised again (0 when it is ready).
func block_cooldown_left() -> float:
	return maxf(_block_cooldown_until - _clock, 0.0)


## 0 just after the guard dropped, 1 when it can be raised again.
func block_cooldown_ratio() -> float:
	return 1.0 - clampf(block_cooldown_left() / maxf(_block_cooldown_total, 0.01), 0.0, 1.0)


## While guarding: how much of the hold is left (1 just raised, 0 about to drop).
func guard_hold_ratio() -> float:
	if state != State.BLOCK:
		return 0.0
	return 1.0 - clampf(seconds_since_block_started() / BLOCK_MAX_HOLD_SECONDS, 0.0, 1.0)


func block_ready() -> bool:
	return block_cooldown_left() <= 0.0 and stamina >= BLOCK_RAISE_COST


func can_attack() -> bool:
	return state == State.IDLE and stamina >= ATTACK_COST


func attack() -> bool:
	if state == State.BLOCK and stamina >= ATTACK_COST:
		lower_guard()  # an attack cancels the guard: swing straight out of it
	if state != State.IDLE:
		return false
	if stamina < ATTACK_COST:
		EventBus.stamina_denied.emit()
		return false
	_spend(ATTACK_COST)
	state = State.ATTACK
	_state_started = _clock
	_swung = false
	var facing := _player.facing
	_player.play_attack(facing, WINDUP_SECONDS + ACTIVE_SECONDS + RECOVER_SECONDS)
	EventBus.sfx_requested.emit("swing")
	if _swing != null:
		_swing.swing(facing, WINDUP_SECONDS + ACTIVE_SECONDS, Gear.weapon_color())
	return true


func raise_guard() -> bool:
	if state != State.IDLE:
		return false
	if not block_ready():
		EventBus.stamina_denied.emit()
		return false
	_spend(BLOCK_RAISE_COST)
	state = State.BLOCK
	_block_started = _clock
	if _swing != null:
		_swing.guard(true, _player.facing)
	return true


func lower_guard() -> void:
	if state != State.BLOCK:
		return
	state = State.IDLE
	_block_cooldown_until = _clock + BLOCK_COOLDOWN_SECONDS
	_block_cooldown_total = BLOCK_COOLDOWN_SECONDS
	_regen_after = _clock + REGEN_DELAY_SECONDS
	if _swing != null:
		_swing.guard(false, _player.facing)
	EventBus.block_state_changed.emit()


func _physics_process(delta: float) -> void:
	_clock += delta
	var hands_free := not Modal.any_open(get_tree())
	if hands_free and Input.is_action_just_pressed("attack"):
		attack()
	if hands_free and Input.is_action_just_pressed("block"):
		raise_guard()
	if state == State.BLOCK:
		_hold_guard(delta, Input.is_action_pressed("block"))
	elif state == State.ATTACK:
		_run_attack()
	_regenerate(delta)
	_report_stamina()


func _hold_guard(delta: float, button_down: bool) -> void:
	_spend(BLOCK_DRAIN_PER_SECOND * delta)
	if _swing != null:
		_swing.guard(true, _player.facing)
	if not button_down:
		lower_guard()
	elif seconds_since_block_started() >= BLOCK_MAX_HOLD_SECONDS:
		lower_guard()  # the arm tires: the guard drops and goes on cooldown
	elif stamina <= 0.0:
		_break_guard()


func _break_guard() -> void:
	state = State.IDLE
	_block_cooldown_until = _clock + GUARD_BREAK_COOLDOWN_SECONDS
	_block_cooldown_total = GUARD_BREAK_COOLDOWN_SECONDS
	_regen_after = _clock + GUARD_BREAK_COOLDOWN_SECONDS
	if _swing != null:
		_swing.guard(false, _player.facing)
		_swing.break_guard()
	FloatingText.spawn(_player.get_parent(), "GUARD BROKEN", _player.global_position, Color("#ff9a5a"))
	EventBus.block_state_changed.emit()


func _regenerate(delta: float) -> void:
	if state == State.BLOCK or _clock < _regen_after:
		return
	stamina = minf(stamina + REGEN_PER_SECOND * Difficulty.value("stamina_regen") * delta, max_stamina())


func _spend(amount: float) -> void:
	stamina = maxf(stamina - amount, 0.0)
	_regen_after = _clock + REGEN_DELAY_SECONDS


func _report_stamina() -> void:
	if absf(stamina - _last_reported_stamina) >= 0.5:
		_last_reported_stamina = stamina
		EventBus.stamina_changed.emit(stamina, max_stamina())


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


## An enemy strike lands on the player. Returns {"outcome", "damage"}.
func receive_hit(raw_damage: float, from_position: Vector2) -> Dictionary:
	if _clock < _invulnerable_until:
		return {"outcome": "ignored", "damage": 0}
	var covers := CombatRules.guard_covers(_player.facing, _player.global_position, from_position)
	var result := CombatRules.resolve_hit(raw_damage, Gear.armor(), is_blocking(), covers, seconds_since_block_started(), Difficulty.value("parry_window"))
	if result["outcome"] == CombatRules.OUTCOME_BLOCKED:
		stamina = maxf(stamina - raw_damage * BLOCKED_HIT_STAMINA_FACTOR, 0.0)
		if stamina <= 0.0:  # too heavy a blow to hold: the guard breaks and the hit lands in full
			_break_guard()
			result = CombatRules.resolve_hit(raw_damage, Gear.armor(), false, false, 99.0)
	match result["outcome"]:
		CombatRules.OUTCOME_PARRIED:
			_invulnerable_until = _clock + PARRY_INVULNERABLE_SECONDS
			stamina = minf(stamina + PARRY_STAMINA_REFUND, max_stamina())
			EventBus.sfx_requested.emit("parry")
			GameState.add_to_counter("parries")
			Progress.add_xp(PARRY_XP)
			FloatingText.spawn(_player.get_parent(), "PARRY!", _player.global_position, Color("#7fe0ff"))
			if _swing != null:
				_swing.parry_flash(_player.facing)
		CombatRules.OUTCOME_BLOCKED:
			_invulnerable_until = _clock + BLOCK_INVULNERABLE_SECONDS
			EventBus.sfx_requested.emit("block")
			GameState.add_to_counter("blocks")
			Survival.damage(result["damage"])
			FloatingText.spawn(_player.get_parent(), str(result["damage"]), _player.global_position, Color("#a0d8ff"))
			if _swing != null:
				_swing.clash(_player.facing)
		_:
			_invulnerable_until = _clock + HURT_INVULNERABLE_SECONDS
			EventBus.sfx_requested.emit("hurt")
			Survival.damage(result["damage"])
			FloatingText.spawn(_player.get_parent(), str(result["damage"]), _player.global_position, Color("#ff6a5a"))
	EventBus.player_hit.emit(result["outcome"], result["damage"])
	return result
