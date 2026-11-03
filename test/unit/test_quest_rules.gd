extends GutTest
## Side quests are data: progress comes from counters and flags, rewards pay out once.


func before_each() -> void:
	GameState.reset()
	Survival.set_process(false)
	Survival.reset()


func after_each() -> void:
	Survival.reset()
	Survival.set_process(true)


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
		assert_true(quest["goal"]["type"] in ["counter", "flags"], quest["id"])
		var reward: Dictionary = quest["reward"]
		assert_gt(float(reward.get("water", 0)) + float(reward.get("health", 0)), 0.0, "%s pays nothing" % quest["id"])


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
