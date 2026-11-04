extends GutTest
## The Scatter rune's shotgun: two shells, then a reload from the rare shells
## you carry; shells turn up in a few chests and, now and then, on the Spoiled.


func before_each() -> void:
	Runes.reset()
	Inventory.clear()


func after_each() -> void:
	Runes.reset()
	Inventory.clear()


func _reload_fully() -> void:
	Runes._process(Runes.RELOAD_SECONDS + 0.05)


func test_the_gun_comes_loaded_with_a_couple_of_spares() -> void:
	Runes.grant(Runes.SCATTER)
	assert_eq(Runes.loaded_shells, Runes.MAGAZINE)
	assert_eq(Runes.spare_shells(), Runes.STARTING_SPARE_SHELLS)


func test_two_blasts_then_it_reloads_from_the_shells_you_carry() -> void:
	Runes.grant(Runes.SCATTER)
	assert_true(Runes.take_shell())
	assert_true(Runes.take_shell())
	assert_eq(Runes.loaded_shells, 0)
	assert_true(Runes.is_reloading(), "an empty gun reloads by itself")
	assert_false(Runes.take_shell(), "no firing mid-reload")
	_reload_fully()
	assert_eq(Runes.loaded_shells, 2)
	assert_eq(Runes.spare_shells(), 0, "the spares went into the gun")


func test_with_no_shells_left_the_gun_stays_empty() -> void:
	Runes.grant(Runes.SCATTER)
	Inventory.remove(Runes.SHELL_ITEM, Runes.STARTING_SPARE_SHELLS)
	Runes.take_shell()
	Runes.take_shell()
	assert_false(Runes.is_reloading())
	assert_false(Runes.take_shell())
	assert_false(Runes.start_reload())


func test_finding_shells_with_an_empty_gun_loads_it() -> void:
	Runes.grant(Runes.SCATTER)
	Inventory.remove(Runes.SHELL_ITEM, Runes.STARTING_SPARE_SHELLS)
	Runes.take_shell()
	Runes.take_shell()
	Inventory.add(Runes.SHELL_ITEM, 1)
	assert_true(Runes.is_reloading())
	_reload_fully()
	assert_eq(Runes.loaded_shells, 1, "only one to load")


func test_the_shotgun_uses_shells_not_energy() -> void:
	Runes.grant(Runes.SCATTER)
	Runes.energy = 0.0
	assert_true(Runes.take_shell())


func test_shells_are_rare_drops_and_only_once_you_have_the_gun() -> void:
	var enemies: Array = DataLoader.load_json("res://data/enemies.json")
	for enemy: Dictionary in enemies:
		var found := false
		for drop: Dictionary in enemy.get("drops", []):
			if drop.get("item", "") == Runes.SHELL_ITEM:
				found = true
				assert_lte(float(drop["chance"]), 0.3, "%s: rare" % enemy["id"])
				assert_eq(drop.get("needs_rune", ""), Runes.SCATTER)
		assert_true(found, "%s can drop shells" % enemy["id"])


func test_a_few_chests_hold_shells() -> void:
	var chests := 0
	for area: Dictionary in DataLoader.load_json("res://data/areas.json"):
		for entity: Dictionary in area.get("entities", {}).values():
			if entity.get("scene", "") == "chest" and entity.get("props", {}).get("items", {}).has(Runes.SHELL_ITEM):
				chests += 1
	assert_between(chests, 3, 10, "some chests, not most")


func test_the_loaded_shells_are_saved() -> void:
	Runes.grant(Runes.SCATTER)
	Runes.take_shell()
	var data := SaveGame.snapshot()
	Runes.loaded_shells = 2
	SaveGame.restore(data)
	assert_eq(Runes.loaded_shells, 1)
