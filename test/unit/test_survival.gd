extends GutTest


func before_each() -> void:
	Survival.set_process(false)
	Survival.reset()


func after_each() -> void:
	Survival.reset()
	Survival.set_process(true)


func test_starts_full() -> void:
	assert_eq(Survival.water(), Survival.MAX_VALUE)
	assert_eq(Survival.health(), Survival.MAX_VALUE)


func test_water_decays_over_time() -> void:
	Survival.tick(10.0)
	assert_almost_eq(Survival.water(), 100.0 - 10.0 * Survival.WATER_DECAY_PER_SECOND, 0.001)


func test_water_never_goes_below_zero() -> void:
	Survival.tick(100000.0)
	assert_eq(Survival.water(), 0.0)
	assert_true(Survival.is_exhausted())


func test_exhaustion_slows_the_player() -> void:
	assert_eq(Survival.speed_multiplier(), 1.0)
	Survival.tick(100000.0)
	assert_eq(Survival.speed_multiplier(), Survival.EXHAUSTED_SPEED_FACTOR)


func test_drinking_restores_water_up_to_the_maximum() -> void:
	Survival.tick(100.0)
	Survival.drink(1000.0)
	assert_eq(Survival.water(), Survival.MAX_VALUE)


func test_damage_reduces_health() -> void:
	Survival.damage(30.0)
	assert_eq(Survival.health(), 70.0)


func test_health_regenerates_while_hydrated() -> void:
	Survival.damage(30.0)
	Survival.tick(5.0)
	assert_gt(Survival.health(), 70.0)


func test_health_does_not_regenerate_when_dehydrated() -> void:
	Survival.tick(100000.0)
	Survival.damage(30.0)
	var before := Survival.health()
	Survival.tick(5.0)
	assert_eq(Survival.health(), before)


func test_lethal_damage_collapses_the_player_and_recovers_partially() -> void:
	watch_signals(EventBus)
	Survival.damage(1000.0)
	assert_signal_emitted(EventBus, "player_collapsed")
	assert_eq(Survival.health(), Survival.COLLAPSE_RECOVERY_HEALTH)


func test_changes_emit_survival_changed_but_no_change_does_not() -> void:
	watch_signals(EventBus)
	Survival.drink(10.0)
	assert_signal_not_emitted(EventBus, "survival_changed")
	Survival.damage(5.0)
	assert_signal_emitted(EventBus, "survival_changed")
