extends GutTest
## Errands between areas: a part found in one area brings something in another back to life.

const REQUEST_SCENE := preload("res://world/request_point.tscn")


func before_each() -> void:
	GameState.reset()
	Inventory.clear()
	Progress.reset()
	Gear.reset()


func after_each() -> void:
	Progress.reset()
	Gear.reset()
	Inventory.clear()


func _point(id: String) -> RequestPoint:
	var point: RequestPoint = REQUEST_SCENE.instantiate()
	point.request_id = id
	add_child_autofree(point)
	return point


func test_without_the_part_it_says_where_to_look() -> void:
	var point := _point("radio")
	watch_signals(EventBus)
	point.interact(null)
	assert_false(point.is_done())
	assert_signal_emitted(EventBus, "text_requested")


func test_bringing_the_part_completes_the_errand_and_pays() -> void:
	var point := _point("fountain")
	Inventory.add("filter_cartridge")
	point.interact(null)
	assert_true(point.is_done())
	assert_eq(Inventory.count("filter_cartridge"), 0, "the part is used")
	assert_eq(Inventory.count("purified_water"), 2)
	assert_eq(Gear.equipped("body"), "riot_jacket")
	assert_true(QuestRules.is_done("errand_fountain"))


func test_every_errand_part_is_found_in_a_different_area_from_where_it_is_needed() -> void:
	for id in ["radio", "garden", "fountain"]:
		var request := Content.request(id)
		var found_in := ""
		for area_id in ["outpost", "factory", "dump", "river", "fields", "industry", "sanctuary"]:
			for definition: Dictionary in Content.area(area_id)["entities"].values():
				if definition["scene"] == "item_pickup" and definition["props"]["item_id"] == request["needs"]:
					found_in = area_id
		assert_false(found_in.is_empty(), "%s: its part is somewhere" % id)
		assert_ne(found_in, request["area"], "%s: you have to travel for it" % id)
		assert_true(ResourceLoader.exists("res://assets/sprites/%s.png" % request["sprite"]))
		assert_true(ResourceLoader.exists("res://assets/sprites/items/%s.png" % request["needs"]))


func test_the_rail_cart_runs_only_between_lit_regions_you_have_visited() -> void:
	MapMemory.reset()
	assert_eq(TravelPanel.stops_from("outpost"), [] as Array[String])
	MapMemory.reveal("factory", Vector2i(1, 1), 1)
	GameState.set_flag("region_lit_factory")
	MapMemory.reveal("dump", Vector2i(1, 1), 1)
	assert_eq(TravelPanel.stops_from("outpost"), ["factory"] as Array[String], "the dump has no power yet")
	assert_eq(TravelPanel.stops_from("factory"), [] as Array[String], "not to where you already are")
	MapMemory.reset()


func test_every_region_has_a_rail_cart() -> void:
	for area_id in TravelPanel.ORDER:
		var layout := MapBuilder.load_layout(Content.area(area_id)["layout"])
		assert_eq(MapBuilder.markers(layout, TravelPanel.CART_MARKER).size(), 1, area_id)
