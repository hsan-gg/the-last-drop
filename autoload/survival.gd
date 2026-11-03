extends Node
## Water and health meters. Deliberately soft: running dry slows the player
## and a collapse is a setback, not a game over.

const MAX_VALUE := 100.0
const WATER_DECAY_PER_SECOND := 0.25
const HEALTH_REGEN_PER_SECOND := 1.0
const REGEN_MIN_WATER := 20.0
const COLLAPSE_RECOVERY_HEALTH := 50.0
const EXHAUSTED_SPEED_FACTOR := 0.6

var _water := MAX_VALUE
var _health := MAX_VALUE


func _process(delta: float) -> void:
	tick(delta)


func water() -> float:
	return _water


func health() -> float:
	return _health


func is_exhausted() -> bool:
	return _water <= 0.0


func speed_multiplier() -> float:
	return EXHAUSTED_SPEED_FACTOR if is_exhausted() else 1.0


func tick(seconds: float) -> void:
	var next_water := maxf(_water - WATER_DECAY_PER_SECOND * seconds, 0.0)
	var next_health := _health
	if next_water >= REGEN_MIN_WATER:
		next_health = minf(_health + HEALTH_REGEN_PER_SECOND * seconds, MAX_VALUE)
	_apply(next_water, next_health)


func drink(amount: float) -> void:
	_apply(minf(_water + amount, MAX_VALUE), _health)


func damage(amount: float) -> void:
	EventBus.damage_taken.emit(amount)
	var next_health := maxf(_health - amount, 0.0)
	if next_health > 0.0:
		_apply(_water, next_health)
		return
	_apply(_water, COLLAPSE_RECOVERY_HEALTH)
	EventBus.player_collapsed.emit()


func reset() -> void:
	_apply(MAX_VALUE, MAX_VALUE)


func _apply(next_water: float, next_health: float) -> void:
	if is_equal_approx(next_water, _water) and is_equal_approx(next_health, _health):
		return
	_water = next_water
	_health = next_health
	EventBus.survival_changed.emit(_water, _health)
