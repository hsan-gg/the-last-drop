extends GutTest
## People and what they say: talks follow the story, take and give things, and
## the data is consistent.

const NPC_SCENE := preload("res://world/npc.tscn")


func before_each() -> void:
	GameState.reset()
	Inventory.clear()
	Progress.reset()
	Gear.reset()
	Runes.reset()


func after_each() -> void:
	Progress.reset()
	Gear.reset()
	Runes.reset()
	Inventory.clear()


func _npc(id: String) -> Npc:
	var npc: Npc = NPC_SCENE.instantiate()
	npc.npc_id = id
	add_child_autofree(npc)
	return npc


func test_a_first_meeting_then_chatter() -> void:
	var tobi := _npc("tobi")
	assert_eq(tobi.current_talk()["id"], "intro")
	assert_true(tobi.has_news(), "a ! over their head")
	watch_signals(EventBus)
	tobi.interact(null)
	assert_signal_emitted(EventBus, "speech_requested")
	assert_true(GameState.has_flag("talked_tobi_intro"))
	assert_eq(tobi.current_talk()["id"], "chatter")
	assert_false(tobi.has_news())


func test_talks_follow_the_story() -> void:
	var tobi := _npc("tobi")
	tobi.interact(null)
	GameState.set_flag("water_secure")
	assert_eq(tobi.current_talk()["id"], "water")


func test_bringing_a_photo_back_takes_it_and_pays() -> void:
	var tobi := _npc("tobi")
	tobi.interact(null)
	Inventory.add("memory_shard_factory")
	assert_eq(tobi.current_talk()["id"], "shard_factory")
	tobi.interact(null)
	assert_eq(Inventory.count("memory_shard_factory"), 0)
	assert_gt(Progress.xp + (Progress.level - 1) * 1000, 0)


func test_the_last_photo_brings_his_memory_back() -> void:
	var tobi := _npc("tobi")
	tobi.interact(null)
	Inventory.add("memory_shard_industry")
	tobi.interact(null)
	assert_true(GameState.has_flag("tobi_remembered"))


func test_halden_gives_the_ember_rune_once_the_power_is_back() -> void:
	var halden := _npc("halden")
	halden.interact(null)
	assert_false(Runes.has("ember"))
	GameState.set_flag("power_restored")
	halden.interact(null)
	assert_true(Runes.has("ember"))
	assert_eq(Runes.in_slot(1), "ember")


func test_counters_can_gate_a_talk() -> void:
	var nana := _npc("nana_ru")
	nana.interact(null)
	assert_ne(nana.current_talk()["id"], "scatter")
	GameState.add_to_counter("perfect_piles")
	assert_eq(nana.current_talk()["id"], "scatter")


func test_the_cast_data_is_consistent() -> void:
	for npc: Dictionary in Content.all_npcs():
		assert_true(ResourceLoader.exists("res://assets/sprites/npcs/%s.png" % npc["sprite"]), npc["id"])
		var has_chatter := false
		for talk: Dictionary in npc["talks"]:
			assert_false(talk["lines"].is_empty(), "%s/%s" % [npc["id"], talk["id"]])
			for line: String in talk["lines"]:
				assert_lte(line.length(), 140, "%s: keep lines short" % npc["id"])
			for item_id: String in talk.get("items", {}):
				assert_true(ItemDB.has_item(item_id), item_id)
			var gives: Dictionary = talk.get("gives", {})
			for item_id: String in gives.get("items", {}):
				assert_true(ItemDB.has_item(item_id), item_id)
			if gives.has("rune"):
				assert_true(Runes.DEFINITIONS.has(gives["rune"]), gives["rune"])
			if gives.has("gear"):
				assert_false(Gear.definition(gives["gear"]).is_empty(), gives["gear"])
			has_chatter = has_chatter or talk.get("repeat", false)
		assert_true(has_chatter, "%s has something to say any time" % npc["id"])


func test_everyone_lives_somewhere() -> void:
	var placed := {}
	for area_id in ["outpost", "factory", "dump", "river", "fields", "industry", "sanctuary"]:
		for definition: Dictionary in Content.area(area_id).get("entities", {}).values():
			if definition["scene"] == "npc":
				placed[definition["props"]["npc_id"]] = true
	for npc: Dictionary in Content.all_npcs():
		assert_true(placed.has(npc["id"]), "%s is placed on a map" % npc["id"])


func test_kip_races_you_and_the_clock_decides() -> void:
	Challenges.reset()
	var kip := _npc("kip")
	kip.interact(null)
	assert_false(Challenges.active().is_empty(), "the race is on")
	GameState.set_flag("pile_sorted_dump_east")
	assert_true(GameState.has_flag("kip_race_won"))
	assert_eq(kip.current_talk()["id"], "won")
	Challenges.reset()


func test_running_out_of_time_loses_the_race() -> void:
	Challenges.reset()
	Challenges.start({"seconds": 1.0, "goal_flag": "never", "win_flag": "test_won", "lose_flag": "test_lost"})
	Challenges._process(1.5)
	assert_true(GameState.has_flag("test_lost"))
	assert_true(Challenges.active().is_empty())


func test_unit7_drill_counts_kills_from_when_it_starts() -> void:
	Challenges.reset()
	GameState.add_to_counter("kills", 5)
	var unit := _npc("unit7")
	unit.interact(null)
	unit.interact(null)
	assert_eq(Challenges.active().get("label", ""), "Unit-7 drill")
	GameState.add_to_counter("kills", 2)
	assert_false(GameState.has_flag("unit7_drill_passed"), "earlier kills do not count")
	GameState.add_to_counter("kills")
	assert_true(GameState.has_flag("unit7_drill_passed"))
	Challenges.reset()
