extends GutTest


func _session(ids: Array[String]) -> SortingSession:
	return SortingSession.new(ids)


func test_starts_on_the_first_item() -> void:
	var session := _session(["battery", "plastic_bottle"])
	assert_eq(session.current_item(), "battery")
	assert_eq(session.remaining(), 2)
	assert_false(session.is_complete())


func test_correct_bin_advances_to_the_next_item() -> void:
	var session := _session(["battery", "plastic_bottle"])
	var verdict := session.place(SortingRules.BIN_HAZARDOUS)
	assert_true(verdict["correct"])
	assert_eq(session.current_item(), "plastic_bottle")


func test_wrong_bin_keeps_the_same_item_and_counts_a_mistake() -> void:
	var session := _session(["battery"])
	var verdict := session.place(SortingRules.BIN_GENERAL)
	assert_false(verdict["correct"])
	assert_eq(session.current_item(), "battery")
	assert_eq(session.mistakes(), 1)


func test_session_completes_after_every_item_is_placed_correctly() -> void:
	var session := _session(["battery", "glass_shard"])
	session.place(SortingRules.BIN_HAZARDOUS)
	var last := session.place(SortingRules.BIN_GENERAL)
	assert_true(last["complete"])
	assert_true(session.is_complete())
	assert_eq(session.current_item(), "")


func test_only_recovery_items_are_handed_back() -> void:
	var session := _session(["battery", "scrap_metal", "glass_shard", "pipe_section"])
	session.place(SortingRules.BIN_HAZARDOUS)
	session.place(SortingRules.BIN_RECOVERY)
	session.place(SortingRules.BIN_GENERAL)
	session.place(SortingRules.BIN_RECOVERY)
	assert_eq(session.recovered_items(), ["scrap_metal", "pipe_section"])


func test_wrong_guesses_do_not_award_items() -> void:
	var session := _session(["scrap_metal"])
	session.place(SortingRules.BIN_GENERAL)
	assert_eq(session.recovered_items(), [])


func test_placing_after_completion_is_a_no_op() -> void:
	var session := _session(["glass_shard"])
	session.place(SortingRules.BIN_GENERAL)
	assert_eq(session.place(SortingRules.BIN_GENERAL), {})
	assert_eq(session.mistakes(), 0)


func test_input_array_is_not_mutated() -> void:
	var items: Array[String] = ["battery"]
	var session := SortingSession.new(items)
	session.place(SortingRules.BIN_HAZARDOUS)
	assert_eq(items, ["battery"])
