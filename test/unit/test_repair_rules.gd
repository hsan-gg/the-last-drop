extends GutTest


func before_each() -> void:
	Inventory.clear()
	GameState.reset()


func _stock_treatment_materials() -> void:
	Inventory.add("scrap_metal")
	Inventory.add("pipe_section")
	Inventory.add("plastic_bottle")


func test_unknown_repair_cannot_be_done() -> void:
	assert_false(RepairRules.exists("nope"))
	assert_false(RepairRules.can_repair("nope"))
	assert_false(RepairRules.perform("nope"))


func test_missing_lists_every_shortfall() -> void:
	Inventory.add("scrap_metal")
	assert_eq(RepairRules.missing("treatment_unit"), {"pipe_section": 1, "plastic_bottle": 1})


func test_cannot_repair_without_materials() -> void:
	assert_false(RepairRules.can_repair("treatment_unit"))
	assert_false(RepairRules.perform("treatment_unit"))
	assert_false(GameState.has_flag("treatment_repaired"))


func test_failed_repair_consumes_nothing() -> void:
	Inventory.add("scrap_metal")
	RepairRules.perform("treatment_unit")
	assert_eq(Inventory.count("scrap_metal"), 1)


func test_repair_consumes_materials_and_sets_the_flag() -> void:
	_stock_treatment_materials()
	assert_true(RepairRules.perform("treatment_unit"))
	assert_eq(Inventory.snapshot(), {})
	assert_true(GameState.has_flag("treatment_repaired"))
	assert_true(RepairRules.is_done("treatment_unit"))


func test_repair_cannot_be_done_twice() -> void:
	_stock_treatment_materials()
	RepairRules.perform("treatment_unit")
	_stock_treatment_materials()
	assert_false(RepairRules.perform("treatment_unit"))
	assert_eq(Inventory.count("scrap_metal"), 1)


func test_hazardous_items_are_never_required_by_a_repair() -> void:
	for repair_id in ["treatment_unit", "generator"]:
		for item_id: String in Content.repair(repair_id)["requires"]:
			assert_false(ItemDB.is_hazardous(item_id), "%s requires hazardous %s" % [repair_id, item_id])
