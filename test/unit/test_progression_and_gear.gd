extends GutTest
## XP curve, levelling, and gear ownership.


func before_each() -> void:
	Survival.set_process(false)
	Survival.reset()
	Gear.reset()
	Progress.reset()
	GameState.reset()


func after_each() -> void:
	Survival.reset()
	Survival.set_process(true)
	Gear.reset()
	Progress.reset()


func test_each_level_needs_more_xp_than_the_last() -> void:
	for level in range(1, ProgressionRules.MAX_LEVEL - 1):
		assert_gt(ProgressionRules.xp_needed(level + 1), ProgressionRules.xp_needed(level))


func test_enough_xp_levels_up_and_carries_the_rest_over() -> void:
	var need := ProgressionRules.xp_needed(1)
	var result := ProgressionRules.apply_xp(1, 0, need + 10)
	assert_eq(result["level"], 2)
	assert_eq(result["xp"], 10)
	assert_eq(result["levels_gained"], 1)


func test_one_big_reward_can_give_several_levels() -> void:
	assert_gte(ProgressionRules.apply_xp(1, 0, 700)["levels_gained"], 3)


func test_the_level_cap_holds() -> void:
	var result := ProgressionRules.apply_xp(ProgressionRules.MAX_LEVEL, 0, 99999)
	assert_eq(result["level"], ProgressionRules.MAX_LEVEL)
	assert_eq(result["xp"], 0)


func test_the_whole_game_reaches_about_level_ten() -> void:
	var total := 0
	for level in range(1, ProgressionRules.MAX_LEVEL):
		total += ProgressionRules.xp_needed(level)
	assert_between(total, 5000, 7000, "level 10 is earned over the whole game, not handed out early")


func test_levelling_up_raises_max_health_and_heals() -> void:
	Survival.damage(50.0)
	watch_signals(EventBus)
	Progress.add_xp(ProgressionRules.xp_needed(1))
	assert_eq(Progress.level, 2)
	assert_eq(Survival.max_health(), ProgressionRules.max_health(2))
	assert_eq(Survival.health(), Survival.max_health(), "a level up heals fully")
	assert_signal_emitted_with_parameters(EventBus, "level_up", [2])


func test_survival_health_never_exceeds_the_cap() -> void:
	Survival.set_max_health(60.0)
	assert_eq(Survival.health(), 60.0)
	Survival.heal(500.0)
	assert_eq(Survival.health(), 60.0)


func test_a_new_run_resets_progress() -> void:
	Progress.add_xp(500)
	Progress.reset()
	assert_eq(Progress.level, 1)
	assert_eq(Progress.xp, 0)
	assert_eq(Survival.max_health(), ProgressionRules.BASE_HEALTH)


func test_gear_starts_with_fists_equipped() -> void:
	assert_eq(Gear.equipped("weapon"), "fists")
	assert_eq(Gear.weapon_damage(), 3)
	assert_eq(Gear.armor(), 0)


func test_a_better_weapon_is_worn_at_once() -> void:
	assert_true(Gear.grant("rusty_sword"))
	assert_eq(Gear.equipped("weapon"), "rusty_sword")
	assert_eq(Gear.weapon_damage(), 8)


func test_a_weaker_weapon_is_kept_but_not_worn() -> void:
	Gear.grant("scrap_blade")
	Gear.grant("rusty_sword")
	assert_eq(Gear.equipped("weapon"), "scrap_blade")
	assert_true(Gear.is_owned("rusty_sword"))
	assert_true(Gear.equip("rusty_sword"))
	assert_eq(Gear.weapon_damage(), 8)


func test_armor_adds_up_across_slots() -> void:
	Gear.grant("hard_hat")
	Gear.grant("cloth_wrap")
	assert_eq(Gear.armor(), 4)


func test_gear_cannot_be_granted_twice_or_equipped_unowned() -> void:
	assert_true(Gear.grant("hard_hat"))
	assert_false(Gear.grant("hard_hat"))
	assert_false(Gear.equip("solar_saber"))
	assert_false(Gear.grant("no_such_gear"))
	assert_eq(GameState.get_counter("gear_found"), 1)


func test_every_gear_item_is_well_formed() -> void:
	for item: Dictionary in Content.all_gear():
		assert_true(item["slot"] in Gear.SLOTS, item["id"])
		assert_gt(int(item.get("damage", 0)) + int(item.get("armor", 0)), 0, "%s has no stats" % item["id"])
		assert_false(String(item["name"]).is_empty())


func test_every_enemy_is_well_formed_and_drops_real_things() -> void:
	for enemy_id in ["walker", "runner", "brute"]:
		var enemy := Content.enemy(enemy_id)
		for key in ["hp", "speed", "damage", "reach", "windup", "cooldown", "aggro", "xp"]:
			assert_true(enemy.has(key), "%s missing %s" % [enemy_id, key])
		for drop: Dictionary in enemy["drops"]:
			if drop.has("item"):
				assert_true(ItemDB.has_item(drop["item"]), "%s drops unknown item" % enemy_id)
			else:
				assert_false(Content.gear_item(drop["gear"]).is_empty(), "%s drops unknown gear" % enemy_id)
