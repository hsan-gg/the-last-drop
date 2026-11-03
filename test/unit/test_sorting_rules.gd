extends GutTest


func test_hazardous_items_belong_in_the_hazardous_bin() -> void:
	assert_eq(SortingRules.correct_bin("battery"), SortingRules.BIN_HAZARDOUS)
	assert_eq(SortingRules.correct_bin("chemical_can"), SortingRules.BIN_HAZARDOUS)


func test_recyclable_and_reusable_items_belong_in_the_recovery_bin() -> void:
	for item_id in ["plastic_bottle", "scrap_metal", "pipe_section", "copper_wire"]:
		assert_eq(SortingRules.correct_bin(item_id), SortingRules.BIN_RECOVERY, item_id)


func test_general_waste_belongs_in_the_general_bin() -> void:
	assert_eq(SortingRules.correct_bin("glass_shard"), SortingRules.BIN_GENERAL)


func test_unknown_item_has_no_correct_bin() -> void:
	assert_eq(SortingRules.correct_bin("nope"), "")


func test_every_item_in_the_catalogue_has_a_bin_and_a_lesson() -> void:
	for item_id in ["battery", "chemical_can", "plastic_bottle", "scrap_metal", "pipe_section", "copper_wire", "glass_shard"]:
		assert_ne(SortingRules.correct_bin(item_id), "", "%s needs a bin" % item_id)
		var lesson := Content.lesson(ItemDB.get_item(item_id).get("lesson_id", ""))
		assert_false(lesson.is_empty(), "%s needs a lesson" % item_id)


func test_evaluate_correct_choice() -> void:
	var verdict := SortingRules.evaluate("battery", SortingRules.BIN_HAZARDOUS)
	assert_true(verdict["correct"])
	assert_eq(verdict["lesson_id"], "battery_leak")


func test_evaluate_wrong_choice_reports_the_right_bin() -> void:
	var verdict := SortingRules.evaluate("battery", SortingRules.BIN_GENERAL)
	assert_false(verdict["correct"])
	assert_eq(verdict["correct_bin"], SortingRules.BIN_HAZARDOUS)


func test_evaluate_unknown_item_is_never_correct() -> void:
	assert_false(SortingRules.evaluate("nope", SortingRules.BIN_GENERAL)["correct"])
	assert_false(SortingRules.evaluate("nope", "")["correct"])
