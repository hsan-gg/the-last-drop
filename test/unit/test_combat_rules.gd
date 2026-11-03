extends GutTest
## The numbers behind a fight.


func test_armor_never_makes_you_immune() -> void:
	assert_eq(CombatRules.armor_multiplier(0.0), 1.0)
	assert_lt(CombatRules.armor_multiplier(10.0), 1.0)
	assert_gt(CombatRules.armor_multiplier(999.0), 0.0)
	assert_lt(CombatRules.armor_multiplier(20.0), CombatRules.armor_multiplier(10.0), "more armor, less damage")


func test_an_unblocked_hit_lands_in_full_without_armor() -> void:
	var result := CombatRules.resolve_hit(10.0, 0.0, false, false, 99.0)
	assert_eq(result["outcome"], CombatRules.OUTCOME_HIT)
	assert_eq(result["damage"], 10)


func test_armor_reduces_a_hit_but_never_below_one() -> void:
	assert_lt(CombatRules.resolve_hit(10.0, 20.0, false, false, 99.0)["damage"], 10)
	assert_eq(CombatRules.resolve_hit(1.0, 500.0, false, false, 99.0)["damage"], CombatRules.MIN_DAMAGE)


func test_a_block_cuts_damage_sharply() -> void:
	var result := CombatRules.resolve_hit(20.0, 0.0, true, true, 1.0)
	assert_eq(result["outcome"], CombatRules.OUTCOME_BLOCKED)
	assert_eq(result["damage"], 4)


func test_a_block_raised_just_in_time_is_a_parry() -> void:
	var result := CombatRules.resolve_hit(20.0, 0.0, true, true, CombatRules.PARRY_WINDOW - 0.01)
	assert_eq(result["outcome"], CombatRules.OUTCOME_PARRIED)
	assert_eq(result["damage"], 0)


func test_a_block_held_too_long_is_only_a_block() -> void:
	assert_eq(CombatRules.resolve_hit(20.0, 0.0, true, true, CombatRules.PARRY_WINDOW + 0.05)["outcome"], CombatRules.OUTCOME_BLOCKED)


func test_blocking_does_nothing_against_a_hit_from_behind() -> void:
	var result := CombatRules.resolve_hit(20.0, 0.0, true, false, 1.0)
	assert_eq(result["outcome"], CombatRules.OUTCOME_HIT)
	assert_eq(result["damage"], 20)


func test_the_swing_arc_covers_the_front_only() -> void:
	var origin := Vector2.ZERO
	assert_true(CombatRules.in_arc(origin, Vector2.RIGHT, Vector2(15, 0), 22.0, 65.0))
	assert_true(CombatRules.in_arc(origin, Vector2.RIGHT, Vector2(12, 10), 22.0, 65.0))
	assert_false(CombatRules.in_arc(origin, Vector2.RIGHT, Vector2(-15, 0), 22.0, 65.0), "behind")
	assert_false(CombatRules.in_arc(origin, Vector2.RIGHT, Vector2(40, 0), 22.0, 65.0), "out of reach")
	assert_false(CombatRules.in_arc(origin, Vector2.RIGHT, Vector2(0, 20), 22.0, 65.0), "straight to the side")


func test_the_guard_covers_a_cone_in_front() -> void:
	assert_true(CombatRules.guard_covers(Vector2.UP, Vector2.ZERO, Vector2(0, -30)))
	assert_false(CombatRules.guard_covers(Vector2.UP, Vector2.ZERO, Vector2(0, 30)))


func test_player_damage_grows_with_level_and_weapon() -> void:
	assert_eq(CombatRules.player_damage(8, 1), 8)
	assert_gt(CombatRules.player_damage(8, 5), 8)
	assert_gt(CombatRules.player_damage(12, 1), CombatRules.player_damage(8, 1))
