extends GutTest
## Guards the JSON content: every reference must resolve, so a typo in data/
## fails a test instead of showing up as a blank screen in the game.

const KNOWN_REPAIR_DIALOGUE_KEY := "dialogue"


func test_every_item_lesson_exists_with_all_fields() -> void:
	for item_id in ["battery", "chemical_can", "plastic_bottle", "scrap_metal", "pipe_section", "copper_wire", "glass_shard"]:
		var lesson := Content.lesson(ItemDB.get_item(item_id)["lesson_id"])
		for key in ["title", "wrong", "right", "principle", "real_life"]:
			assert_true(lesson.has(key), "%s lesson missing %s" % [item_id, key])


func test_every_repair_dialogue_exists() -> void:
	for repair_id in ["treatment_unit", "generator"]:
		var dialogue_id: String = Content.repair(repair_id)[KNOWN_REPAIR_DIALOGUE_KEY]
		assert_false(Content.dialogue(dialogue_id).is_empty(), dialogue_id)


func test_every_repair_requirement_is_a_real_item() -> void:
	for repair_id in ["treatment_unit", "generator"]:
		for item_id: String in Content.repair(repair_id)["requires"]:
			assert_true(ItemDB.has_item(item_id), "%s requires unknown %s" % [repair_id, item_id])


func test_story_dialogue_exists() -> void:
	for dialogue_id in ["intro", "water_contaminated", "water_needs_treatment", "water_clean", "recording_1", "exit_locked", "factory_arrival", "terminal_locked", "archive_truth"]:
		assert_false(Content.dialogue(dialogue_id).is_empty(), dialogue_id)


func test_unknown_content_is_empty_not_an_error() -> void:
	assert_eq(Content.lesson("nope"), {})
	assert_eq(Content.dialogue("nope"), [])
	assert_eq(Content.repair("nope"), {})


func test_content_getters_return_copies() -> void:
	var repair := Content.repair("treatment_unit")
	repair["requires"]["scrap_metal"] = 99
	assert_eq(int(Content.repair("treatment_unit")["requires"]["scrap_metal"]), 1)


func test_objectives_have_the_required_fields() -> void:
	for objective: Dictionary in Content.objectives():
		for key in ["id", "area", "text", "done_flag"]:
			assert_true(objective.has(key), "%s missing %s" % [objective.get("id", "?"), key])


func test_every_catalogue_item_has_a_lesson_and_an_icon() -> void:
	var items: Variant = DataLoader.load_json("res://data/items.json")
	assert_gt(items.size(), 0)
	for item: Dictionary in items:
		if item["category"] in ["consumable", "keepsake", "material"]:  # used, carried, or crafted with: never sorted
			assert_not_null(ItemDB.icon(item["id"]), "%s has no icon" % item["id"])
			continue
		var lesson := Content.lesson(item["lesson_id"])
		assert_false(lesson.is_empty(), "%s has no lesson" % item["id"])
		assert_not_null(ItemDB.icon(item["id"]), "%s has no icon" % item["id"])


func test_every_repair_dialogue_and_requirement_resolves() -> void:
	var repairs: Variant = DataLoader.load_json("res://data/repairs.json")
	for repair: Dictionary in repairs:
		assert_false(Content.dialogue(repair["dialogue"]).is_empty(), repair["id"])
		for item_id: String in repair["requires"]:
			assert_true(ItemDB.has_item(item_id), "%s requires unknown %s" % [repair["id"], item_id])
			assert_false(ItemDB.is_hazardous(item_id), "%s requires a hazardous item" % repair["id"])
