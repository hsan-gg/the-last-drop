extends GutTest


func test_known_items_are_loaded() -> void:
	for item_id in ["battery", "plastic_bottle", "scrap_metal", "pipe_section"]:
		assert_true(ItemDB.has_item(item_id), "%s should exist" % item_id)


func test_unknown_item_is_absent_and_empty() -> void:
	assert_false(ItemDB.has_item("nope"))
	assert_eq(ItemDB.get_item("nope"), {})


func test_hazard_flag_follows_category() -> void:
	assert_true(ItemDB.is_hazardous("battery"))
	assert_false(ItemDB.is_hazardous("plastic_bottle"))
	assert_false(ItemDB.is_hazardous("nope"))


func test_get_item_returns_a_copy() -> void:
	var item := ItemDB.get_item("battery")
	item["category"] = "reusable"
	assert_true(ItemDB.is_hazardous("battery"))
