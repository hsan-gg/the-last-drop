extends GutTest
## A run survives being saved and loaded.


func before_each() -> void:
	SaveGame.path = "user://test_save.json"
	SaveGame.delete()
	GameState.reset()
	Inventory.clear()
	Gear.reset()
	Progress.reset()
	Runes.reset()
	MapMemory.reset()


func after_each() -> void:
	SaveGame.delete()
	SaveGame.path = SaveGame.PATH
	GameState.reset()
	Inventory.clear()
	Gear.reset()
	Progress.reset()
	Runes.reset()
	MapMemory.reset()
	Lives.reset()


func test_a_snapshot_round_trips_through_json() -> void:
	GameState.set_flag("water_secure")
	GameState.add_to_counter("kills", 7)
	Inventory.add("bandage", 2)
	Gear.grant("rusty_sword")
	Progress.add_xp(150)
	Runes.grant("ember")
	MapMemory.reveal("outpost", Vector2i(5, 5), 1)
	var text := JSON.stringify(SaveGame.snapshot())
	GameState.reset()
	Inventory.clear()
	Gear.reset()
	Progress.reset()
	Runes.reset()
	MapMemory.reset()
	SaveGame.restore(JSON.parse_string(text))
	assert_true(GameState.has_flag("water_secure"))
	assert_eq(GameState.get_counter("kills"), 7)
	assert_eq(Inventory.count("bandage"), 2)
	assert_eq(Gear.equipped("weapon"), "rusty_sword")
	assert_eq(Progress.level, 2)
	assert_true(Runes.has("ember"))
	assert_true(MapMemory.is_seen("outpost", Vector2i(5, 5)))
	assert_true(Lives.active, "a continued run is live")


func test_nothing_is_saved_outside_a_run_and_a_new_game_starts_clean() -> void:
	Lives.reset()
	assert_false(SaveGame.save_now())
	assert_false(SaveGame.has_save())


func test_a_broken_save_is_ignored() -> void:
	var file := FileAccess.open(SaveGame.path, FileAccess.WRITE)
	file.store_string("not json")
	file.close()
	assert_eq(SaveGame.read(), {})
