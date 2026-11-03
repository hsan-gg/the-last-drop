extends GutTest
## Side quests are data: progress comes from counters and flags, rewards pay out once.


func before_each() -> void:
	GameState.reset()
	Survival.set_process(false)
	Survival.reset()
	Gear.reset()
	Progress.reset()


func after_each() -> void:
	Survival.reset()
	Survival.set_process(true)
	Gear.reset()
	Progress.reset()


func _quest(quest_id: String) -> Dictionary:
	for quest: Dictionary in Content.quests():
		if quest["id"] == quest_id:
			return quest
	return {}


func test_every_quest_is_well_formed() -> void:
	var seen := {}
	for quest: Dictionary in Content.quests():
		assert_false(seen.has(quest["id"]), "duplicate %s" % quest["id"])
		seen[quest["id"]] = true
		for key in ["area", "title", "text", "goal", "reward"]:
			assert_true(quest.has(key), "%s missing %s" % [quest["id"], key])
		assert_false(Content.area(quest["area"]).is_empty(), "%s names unknown area" % quest["id"])
		assert_true(quest["goal"]["type"] in ["counter", "flags", "level", "clear", "codex"], quest["id"])
		var reward: Dictionary = quest["reward"]
		assert_gt(int(reward.get("xp", 0)), 0, "%s pays no XP" % quest["id"])
		assert_true(quest["difficulty"] in QuestRules.DIFFICULTY_ORDER, "%s: unknown difficulty" % quest["id"])
		assert_true(quest["category"] in ["combat", "sort", "learn", "explore", "puzzle"], "%s: unknown category" % quest["id"])
		if reward.has("gear"):
			assert_false(Content.gear_item(reward["gear"]).is_empty(), "%s rewards unknown gear" % quest["id"])


func test_counter_progress_is_clamped_to_the_target() -> void:
	var quest := _quest("sharp_eye")
	assert_eq(QuestRules.progress(quest)["current"], 0)
	GameState.add_to_counter("sort_correct", 99)
	var progress := QuestRules.progress(quest)
	assert_eq(progress["current"], progress["target"])
	assert_true(progress["complete"])


func test_flag_quests_need_every_flag() -> void:
	var quest := _quest("safe_route")
	assert_false(QuestRules.progress(quest)["complete"])
	GameState.set_flag("puzzle_hazard_route_solved")
	assert_true(QuestRules.progress(quest)["complete"])


func test_a_finished_quest_is_marked_done_and_paid_once() -> void:
	Survival.damage(30.0)
	var health_before := Survival.health()
	GameState.add_to_counter("perfect_piles")  # QuestTracker completes it as the counter changes
	assert_true(QuestRules.is_done("clean_hands"))
	assert_gt(Survival.health(), health_before, "health reward paid")
	var health_after := Survival.health()
	assert_eq(QuestRules.complete_ready(), [] as Array[String], "not completed twice")
	assert_eq(Survival.health(), health_after, "not paid twice")


func test_only_quests_for_reached_areas_are_visible() -> void:
	assert_eq(QuestRules.visible_quests().size(), 0)
	GameState.set_flag("area_outpost_reached")
	var areas := {}
	for quest in QuestRules.visible_quests():
		areas[quest["area"]] = true
	assert_eq(areas.keys(), ["outpost"])


func test_the_tracker_announces_completion_from_a_counter_change() -> void:
	watch_signals(EventBus)
	GameState.add_to_counter("quiz_correct", 2)
	assert_signal_emitted_with_parameters(EventBus, "quest_completed", ["quick_learner"])


func test_every_area_has_an_easy_a_medium_and_a_hard_quest() -> void:
	var seen := {}
	for quest: Dictionary in Content.quests():
		seen["%s/%s" % [quest["area"], quest["difficulty"]]] = true
	for area_id in ["outpost", "factory", "dump", "river"]:
		for difficulty in ["easy", "medium", "hard"]:
			assert_true(seen.has("%s/%s" % [area_id, difficulty]), "%s has no %s quest" % [area_id, difficulty])


func test_harder_quests_pay_more_xp_on_average() -> void:
	var totals := {"easy": 0, "medium": 0, "hard": 0}
	var counts := {"easy": 0, "medium": 0, "hard": 0}
	for quest: Dictionary in Content.quests():
		totals[quest["difficulty"]] += int(quest["reward"]["xp"])
		counts[quest["difficulty"]] += 1
	assert_lt(totals["easy"] / counts["easy"], totals["medium"] / counts["medium"])
	assert_lt(totals["medium"] / counts["medium"], totals["hard"] / counts["hard"])


func test_quests_sort_easiest_first() -> void:
	var order := QuestRules.sorted_by_difficulty(Content.quests())
	var rank := -1
	for quest in order:
		var this_rank: int = QuestRules.DIFFICULTY_ORDER[quest["difficulty"]]
		assert_gte(this_rank, rank, "%s is out of order" % quest["id"])
		rank = this_rank


func test_finishing_a_quest_pays_xp_once() -> void:
	GameState.add_to_counter("kills")
	assert_true(QuestRules.is_done("first_blood"))
	assert_eq(Progress.xp, 25)
	GameState.add_to_counter("kills")
	assert_eq(Progress.xp, 25, "paid once")


func test_a_level_quest_completes_when_the_level_is_reached() -> void:
	assert_false(QuestRules.is_done("battle_ready"))
	Progress.add_xp(ProgressionRules.xp_needed(1) + ProgressionRules.xp_needed(2))
	assert_eq(Progress.level, 3)
	assert_true(QuestRules.is_done("battle_ready"))


func test_a_gear_reward_is_granted_and_worn() -> void:
	GameState.add_to_counter("brute_kills", 2)
	assert_true(QuestRules.is_done("brute_breaker"))
	assert_true(Gear.is_owned("solar_saber"))
	assert_eq(Gear.equipped("weapon"), "solar_saber")


func test_each_main_objective_pays_a_little_xp_once() -> void:
	GameState.set_flag("water_tested")
	var after_first := Progress.xp
	assert_eq(after_first, QuestTracker.OBJECTIVE_XP)
	GameState.set_flag("water_tested")
	assert_eq(Progress.xp, after_first, "not paid twice")
