extends GutTest


func before_each() -> void:
	GameState.reset()


func test_first_unfinished_objective_is_current() -> void:
	assert_eq(ObjectivesTracker.current("outpost")["id"], "find_water")


func test_objective_advances_as_flags_are_set() -> void:
	GameState.set_flag("water_tested")
	assert_eq(ObjectivesTracker.current("outpost")["id"], "sort_outpost")


func test_a_completed_area_has_no_current_objective() -> void:
	for objective: Dictionary in Content.objectives():
		GameState.set_flag(objective["done_flag"])
	assert_eq(ObjectivesTracker.current("outpost"), {})
	assert_eq(ObjectivesTracker.current("factory"), {})


func test_objectives_are_scoped_to_their_area() -> void:
	assert_eq(ObjectivesTracker.current("factory")["id"], "sort_factory")


func test_unknown_area_has_no_objective() -> void:
	assert_eq(ObjectivesTracker.current("nowhere"), {})


func test_counters_start_at_zero_and_accumulate() -> void:
	assert_eq(GameState.get_counter("sort_mistakes"), 0)
	GameState.add_to_counter("sort_mistakes")
	GameState.add_to_counter("sort_mistakes", 2)
	assert_eq(GameState.get_counter("sort_mistakes"), 3)


func test_reset_clears_counters() -> void:
	GameState.add_to_counter("sort_mistakes")
	GameState.reset()
	assert_eq(GameState.get_counter("sort_mistakes"), 0)


func test_tone_thresholds() -> void:
	assert_eq(EndingRules.tone(0), "careful")
	assert_eq(EndingRules.tone(1), "learning")
	assert_eq(EndingRules.tone(3), "learning")
	assert_eq(EndingRules.tone(4), "reckless")


func test_epilogue_combines_choice_and_tone() -> void:
	var expected: Array[String] = []
	expected.append_array(Content.dialogue("ending_share"))
	expected.append_array(Content.dialogue("ending_tone_careful"))
	assert_eq(EndingRules.epilogue_lines(EndingRules.CHOICE_SHARE, 0), expected)


func test_every_choice_and_tone_has_content() -> void:
	for choice in [EndingRules.CHOICE_PRESERVE, EndingRules.CHOICE_SHARE]:
		for mistakes in [0, 2, 9]:
			assert_gt(EndingRules.epilogue_lines(choice, mistakes).size(), 1, "%s/%d" % [choice, mistakes])
