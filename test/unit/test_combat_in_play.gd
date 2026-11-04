extends GutTest
## The player and zombies fighting, driven frame by frame without real input.

const PLAYER_SCENE := preload("res://player/player.tscn")
const ENEMY_SCENE := preload("res://world/enemy.tscn")

var _player: Player


func before_each() -> void:
	Combat.enemies_enabled = true
	Survival.set_process(false)
	Survival.reset()
	Gear.reset()
	Progress.reset()
	GameState.reset()
	Inventory.clear()
	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)
	_player.global_position = Vector2.ZERO
	_player.facing = Vector2.RIGHT


func after_each() -> void:
	Combat.enemies_enabled = false
	Survival.reset()
	Survival.set_process(true)
	Gear.reset()
	Progress.reset()
	Inventory.clear()


func _enemy(enemy_id: String, at: Vector2, key: String = "") -> Enemy:
	var enemy: Enemy = ENEMY_SCENE.instantiate()
	enemy.enemy_id = enemy_id
	enemy.spawn_key = key
	enemy.position = at
	add_child_autofree(enemy)
	return enemy


func _advance(enemy: Enemy, seconds: float, step: float = 0.05) -> void:
	for _i in int(seconds / step):
		enemy._physics_process(step)


func _swing(seconds: float = 0.45) -> void:
	_player.combat.attack()
	for _i in int(seconds / 0.05):
		_player.combat._physics_process(0.05)


func test_enemies_do_not_exist_unless_a_run_has_started() -> void:
	Combat.enemies_enabled = false
	var enemy := _enemy("walker", Vector2(200, 0))
	await wait_frames(2)
	assert_false(is_instance_valid(enemy) and not enemy.is_queued_for_deletion(), "peaceful tests never meet a zombie")


func test_a_zombie_ignores_the_player_until_close() -> void:
	var enemy := _enemy("walker", Vector2(400, 0))
	_advance(enemy, 0.5)
	assert_eq(enemy.state(), Enemy.State.IDLE)
	enemy.position = Vector2(60, 0)
	_advance(enemy, 0.2)
	assert_eq(enemy.state(), Enemy.State.CHASE)


func test_a_zombie_that_reaches_the_player_telegraphs_before_it_strikes() -> void:
	var enemy := _enemy("walker", Vector2(14, 0))
	_advance(enemy, 0.1)
	assert_eq(enemy.state(), Enemy.State.WINDUP, "the windup is the warning")
	assert_eq(Survival.health(), Survival.max_health(), "nothing has hit yet")
	_advance(enemy, 0.7)
	assert_lt(Survival.health(), Survival.max_health(), "then the strike lands")


func test_a_sword_swing_hurts_a_zombie_in_front() -> void:
	Gear.grant("rusty_sword")
	var enemy := _enemy("walker", Vector2(18, 0))
	var before := enemy.hp()
	_swing()
	assert_eq(enemy.hp(), before - 8.0)


func test_a_swing_misses_a_zombie_behind() -> void:
	Gear.grant("rusty_sword")
	var enemy := _enemy("walker", Vector2(-18, 0))
	var before := enemy.hp()
	_swing()
	assert_eq(enemy.hp(), before)


func test_levels_make_the_sword_hit_harder() -> void:
	Gear.grant("rusty_sword")
	Progress.add_xp(500)
	var enemy := _enemy("brute", Vector2(18, 0))
	var before := enemy.hp()
	_swing()
	assert_eq(enemy.hp(), before - float(CombatRules.player_damage(8, Progress.level)))
	assert_gt(before - enemy.hp(), 8.0)


func test_killing_a_zombie_pays_xp_counts_a_kill_and_it_stays_dead() -> void:
	Gear.grant("rusty_sword")
	var enemy := _enemy("runner", Vector2(14, 0), "test_1")
	for _i in 6:
		if not enemy.is_dead():
			_swing()
	assert_true(enemy.is_dead())
	assert_eq(GameState.get_counter("kills"), 1)
	assert_true(GameState.has_flag("slain_test_1"))
	assert_eq(Progress.xp, 8 + 25, "8 for the kill plus 25 from the First Blood quest")
	var again := _enemy("runner", Vector2(14, 0), "test_1")
	await wait_frames(2)
	assert_false(is_instance_valid(again) and not again.is_queued_for_deletion(), "a defeated zombie does not respawn")


func test_a_light_hit_staggers_a_walker_but_not_a_brute() -> void:
	var walker := _enemy("walker", Vector2(60, 0))
	walker.take_hit(5.0, Vector2.ZERO, 0.0)
	assert_eq(walker.state(), Enemy.State.STAGGER)
	var brute := _enemy("brute", Vector2(60, 40))
	brute.take_hit(5.0, Vector2.ZERO, 0.0)
	assert_ne(brute.state(), Enemy.State.STAGGER, "a brute shrugs off small hits")


func test_a_plain_hit_lands_in_full_and_armor_helps() -> void:
	var bare := _player.receive_hit(20.0, Vector2(30, 0))
	assert_eq(bare["outcome"], CombatRules.OUTCOME_HIT)
	assert_eq(bare["damage"], 20)

	Survival.reset()
	Gear.grant("scrap_plate")
	_player.combat._clock += 5.0  # past the invulnerability window
	var armored := _player.receive_hit(20.0, Vector2(30, 0))
	assert_lt(armored["damage"], 20)


func test_a_fresh_hit_gives_a_moment_of_invulnerability() -> void:
	_player.receive_hit(10.0, Vector2(30, 0))
	assert_eq(_player.receive_hit(10.0, Vector2(30, 0))["outcome"], "ignored", "no stun-locking")


func test_raising_the_guard_just_in_time_parries() -> void:
	_player.combat.raise_guard()
	var result := _player.receive_hit(20.0, Vector2(30, 0))
	assert_eq(result["outcome"], CombatRules.OUTCOME_PARRIED)
	assert_eq(Survival.health(), Survival.max_health(), "a parry takes no damage")
	assert_eq(GameState.get_counter("parries"), 1)
	assert_gt(Progress.xp, 0, "parrying is rewarded")


func test_a_guard_held_a_while_only_blocks() -> void:
	_player.combat.raise_guard()
	_player.combat._clock += 1.0
	var result := _player.receive_hit(20.0, Vector2(30, 0))
	assert_eq(result["outcome"], CombatRules.OUTCOME_BLOCKED)
	assert_eq(result["damage"], 4)
	assert_eq(GameState.get_counter("blocks"), 1)


func test_the_guard_does_not_cover_attacks_from_behind() -> void:
	_player.combat.raise_guard()
	var result := _player.receive_hit(20.0, Vector2(-30, 0))
	assert_eq(result["outcome"], CombatRules.OUTCOME_HIT)


func test_a_parried_zombie_is_stunned() -> void:
	var enemy := _enemy("walker", Vector2(14, 0))
	_advance(enemy, 0.1)
	_player.combat.raise_guard()
	_advance(enemy, 0.7)
	assert_eq(enemy.state(), Enemy.State.STAGGER)


func test_blocking_and_attacking_slow_the_player() -> void:
	assert_eq(_player.combat.move_factor(), 1.0)
	_player.combat.raise_guard()
	assert_lt(_player.combat.move_factor(), 1.0)
	_player.combat.lower_guard()
	_player.combat.attack()
	assert_lt(_player.combat.move_factor(), 1.0)


func test_the_sword_swing_is_drawn_when_attacking() -> void:
	Gear.grant("rusty_sword")
	var swing := _player.get_node_or_null("Swing") as SwordSwing
	assert_not_null(swing, "combat finds the swing visuals by name")
	_player.combat.attack()
	assert_true(swing._swinging, "attacking starts the blade animation")
	var start: float = swing.swing_pose(0.0)["angle"]
	var later: float = swing.swing_pose(0.15)["angle"]
	assert_gt(absf(later - start), 1.5, "the blade sweeps through a wide arc")


func test_attacking_cancels_the_guard_into_a_swing() -> void:
	_player.combat.raise_guard()
	assert_true(_player.combat.attack(), "an attack breaks out of the guard")
	assert_false(_player.combat.is_blocking())
	assert_true(_player.combat.is_busy())


func test_a_zombie_mid_swing_is_not_interrupted_by_a_hit() -> void:
	Gear.grant("rusty_sword")
	var enemy := _enemy("walker", Vector2(14, 0))
	_advance(enemy, 0.1)
	assert_eq(enemy.state(), Enemy.State.WINDUP)
	enemy.take_hit(5.0, Vector2.ZERO, 120.0)
	assert_eq(enemy.state(), Enemy.State.WINDUP, "its attack is committed")
	_advance(enemy, 0.7)
	assert_lt(Survival.health(), Survival.max_health(), "and the blow still lands")


func test_a_zombie_that_is_only_walking_still_flinches() -> void:
	var enemy := _enemy("walker", Vector2(40, 0))
	_advance(enemy, 0.1)
	assert_eq(enemy.state(), Enemy.State.CHASE)
	enemy.take_hit(5.0, Vector2.ZERO, 120.0)
	assert_eq(enemy.state(), Enemy.State.STAGGER)


# ------------------------------------------------------------- stamina and the guard

func _tick(seconds: float, step: float = 0.05) -> void:
	for _i in int(seconds / step):
		_player.combat._physics_process(step)


func test_attacking_costs_stamina() -> void:
	var before := _player.combat.stamina
	_player.combat.attack()
	assert_eq(_player.combat.stamina, before - PlayerCombat.ATTACK_COST)


func test_you_cannot_swing_with_no_stamina() -> void:
	_player.combat.stamina = 3.0
	watch_signals(EventBus)
	assert_false(_player.combat.attack())
	assert_false(_player.combat.is_busy())
	assert_signal_emitted(EventBus, "stamina_denied")


func test_stamina_comes_back_after_a_short_delay() -> void:
	_player.combat.stamina = 20.0
	_player.combat._regen_after = _player.combat._clock + PlayerCombat.REGEN_DELAY_SECONDS
	_tick(0.3)
	assert_eq(_player.combat.stamina, 20.0, "no regeneration straight after spending")
	_tick(1.0)
	assert_gt(_player.combat.stamina, 40.0)


func test_the_guard_can_only_be_held_for_a_while_then_goes_on_cooldown() -> void:
	Input.action_press("block")
	assert_true(_player.combat.raise_guard())
	_tick(PlayerCombat.BLOCK_MAX_HOLD_SECONDS + 0.2)
	assert_false(_player.combat.is_blocking(), "the arm tires and the guard drops")
	assert_gt(_player.combat.block_cooldown_left(), 0.0)
	assert_false(_player.combat.raise_guard(), "on cooldown")
	Input.action_release("block")
	await wait_physics_frames(2)  # let the engine forget the press this frame
	_tick(PlayerCombat.BLOCK_COOLDOWN_SECONDS + 0.2)
	assert_true(_player.combat.raise_guard(), "ready again")


func test_holding_the_guard_drains_stamina() -> void:
	Input.action_press("block")
	_player.combat.raise_guard()
	var after_raise := _player.combat.stamina
	_tick(0.5)
	Input.action_release("block")
	assert_lt(_player.combat.stamina, after_raise)


func test_a_blow_too_heavy_for_the_guard_breaks_it() -> void:
	_player.combat.raise_guard()
	_player.combat._clock += 1.0
	_player.combat.stamina = 10.0
	var result := _player.receive_hit(40.0, Vector2(30, 0))
	assert_eq(result["outcome"], CombatRules.OUTCOME_HIT, "the hit lands in full once the guard breaks")
	assert_false(_player.combat.is_blocking())
	assert_gte(_player.combat.block_cooldown_left(), PlayerCombat.GUARD_BREAK_COOLDOWN_SECONDS - 0.01)


func test_a_light_blocked_hit_drains_stamina_but_holds() -> void:
	_player.combat.raise_guard()
	_player.combat._clock += 1.0
	var before := _player.combat.stamina
	var result := _player.receive_hit(10.0, Vector2(30, 0))
	assert_eq(result["outcome"], CombatRules.OUTCOME_BLOCKED)
	assert_lt(_player.combat.stamina, before)
	assert_true(_player.combat.is_blocking())


func test_a_parry_costs_nothing_and_refunds_stamina() -> void:
	_player.combat.raise_guard()
	_player.combat.stamina = 30.0
	_player.receive_hit(20.0, Vector2(30, 0))
	assert_gt(_player.combat.stamina, 30.0)


func test_levels_raise_the_stamina_pool() -> void:
	var base := _player.combat.max_stamina()
	Progress.add_xp(500)
	assert_gt(_player.combat.max_stamina(), base)


func test_the_guard_bar_shows_while_blocking_and_cooling_down() -> void:
	var meter := _player.get_node("GuardMeter") as GuardMeter
	assert_false(meter.is_showing(), "hidden when the guard is idle and ready")
	_player.combat.raise_guard()
	assert_true(meter.is_showing())
	assert_almost_eq(_player.combat.guard_hold_ratio(), 1.0, 0.05)
	_player.combat.lower_guard()
	assert_true(meter.is_showing(), "shows the cooldown refilling")
	assert_lt(_player.combat.block_cooldown_ratio(), 0.1)


func test_a_blocked_zombie_finishes_its_swing_animation() -> void:
	var enemy := _enemy("walker", Vector2(14, 0))
	_advance(enemy, 0.1)
	_player.combat.raise_guard()
	_player.combat._block_started = -10.0  # held a while: a block, not a parry
	var windup := float(enemy.definition()["windup"])
	_advance(enemy, windup + 0.1)
	assert_eq(enemy.state(), Enemy.State.RECOVER)
	assert_true(String(enemy._sprite.animation).begins_with("attack"), "the swing is still playing out")
