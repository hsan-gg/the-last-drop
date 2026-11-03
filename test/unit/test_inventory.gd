extends GutTest
## Requires the GUT addon (https://github.com/bitwes/Gut) in res://addons/gut.


func before_each() -> void:
	Inventory.clear()


func test_add_known_item_increases_count() -> void:
	assert_true(Inventory.add("battery"))
	assert_eq(Inventory.count("battery"), 1)


func test_add_accumulates() -> void:
	Inventory.add("battery", 2)
	Inventory.add("battery")
	assert_eq(Inventory.count("battery"), 3)


func test_add_unknown_item_is_rejected() -> void:
	assert_false(Inventory.add("not_an_item"))
	assert_eq(Inventory.count("not_an_item"), 0)


func test_add_non_positive_amount_is_rejected() -> void:
	assert_false(Inventory.add("battery", 0))
	assert_false(Inventory.add("battery", -1))
	assert_eq(Inventory.count("battery"), 0)


func test_remove_decreases_count_and_drops_empty_entry() -> void:
	Inventory.add("battery", 2)
	assert_true(Inventory.remove("battery"))
	assert_eq(Inventory.count("battery"), 1)
	assert_true(Inventory.remove("battery"))
	assert_false(Inventory.snapshot().has("battery"))


func test_remove_more_than_owned_fails_and_changes_nothing() -> void:
	Inventory.add("battery")
	assert_false(Inventory.remove("battery", 2))
	assert_eq(Inventory.count("battery"), 1)


func test_snapshot_is_a_copy() -> void:
	Inventory.add("battery")
	var snapshot := Inventory.snapshot()
	snapshot["battery"] = 99
	assert_eq(Inventory.count("battery"), 1)


func test_inventory_changed_signal_fires_on_add() -> void:
	watch_signals(EventBus)
	Inventory.add("battery")
	assert_signal_emitted(EventBus, "inventory_changed")
