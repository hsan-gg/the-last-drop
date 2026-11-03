extends GutTest
## Plays the real scenes from the first water inspection to the final archive,
## driving the same interactables the player would. Scene changes are never
## triggered here, since they would replace the test runner.

const OUTPOST := preload("res://world/outpost.tscn")
const FACTORY := preload("res://world/factory.tscn")
const DUMP := preload("res://world/dump.tscn")
const RIVER := preload("res://world/river.tscn")
const OUTPOST_ITEMS: Array[String] = ["battery", "plastic_bottle", "chemical_can", "scrap_metal", "glass_shard", "pipe_section"]

var _area: Node


func before_each() -> void:
	Chapters.ending_enabled = false
	Inventory.clear()
	GameState.reset()
	Survival.set_process(false)
	Survival.reset()


func after_each() -> void:
	Chapters.ending_enabled = true
	Survival.reset()
	Survival.set_process(true)


## Piles are random in the game; these fixed contents keep the scripted runs exact.
const FIXED_PILES := {
	"outpost": ["battery", "plastic_bottle", "chemical_can", "scrap_metal", "glass_shard", "pipe_section"],
	"factory": ["battery", "copper_wire", "chemical_can", "battery", "scrap_metal"],
	"dump_west": ["food_scraps", "cardboard", "tin_can", "greasy_pizza_box", "phone"],
	"dump_centre": ["fluorescent_tube", "glass_jar", "textile_scrap", "scrap_metal", "food_scraps", "tin_can"],
	"dump_east": ["phone", "cardboard", "textile_scrap", "glass_jar", "greasy_pizza_box", "fluorescent_tube"],
	"river_bank": ["charcoal", "paint_tin", "textile_scrap", "plastic_bottle", "tin_can"],
	"river_camp": ["sand_sack", "kettle", "pipe_section", "cardboard", "glass_jar", "paint_tin"],
}


func _enter(scene: PackedScene) -> void:
	_area = scene.instantiate()
	for pile: ScrapPile in _area.find_children("*", "ScrapPile", true, false):
		pile.pool = [] as Array[String]
	add_child_autofree(_area)
	await wait_physics_frames(2)
	for pile: ScrapPile in _area.find_children("*", "ScrapPile", true, false):
		var fixed: Array[String] = []
		fixed.assign(FIXED_PILES.get(pile.pile_id, pile.item_ids))
		pile.item_ids = fixed
	for overlay in _area.find_children("*", "DialogueBox", true, false):
		overlay.pauses_game = false
	for overlay in _area.find_children("*", "SortingChallenge", true, false):
		overlay.pauses_game = false
	for overlay_type in ["QuizPanel", "PuzzlePanel", "QuestJournal"]:
		for overlay in _area.find_children("*", overlay_type, true, false):
			overlay.pauses_game = false


func _find(type_name: String) -> Node:
	return _area.find_children("*", type_name, true, false)[0]


func _sorting() -> SortingChallenge:
	return _find("SortingChallenge")


func _dialogue() -> DialogueBox:
	return _find("DialogueBox")


## Opens the terminal's puzzle and solves it, as a player would.
func _solve_puzzle(puzzle_id: String) -> void:
	var panel: PuzzlePanel = _find("PuzzlePanel")
	assert_eq(panel.phase(), PuzzlePanel.Phase.SOLVING, "terminal opened %s" % puzzle_id)
	for step: String in Content.puzzle(puzzle_id)["steps"]:
		panel.choose(step)
	assert_eq(panel.phase(), PuzzlePanel.Phase.SOLVED)
	panel.continue_flow()


## Sorts every item in `pile` correctly, clicking through each lesson.
func _sort_pile_correctly(pile: ScrapPile) -> void:
	pile.interact(null)
	for item_id in pile.item_ids:
		assert_eq(_sorting().phase(), SortingChallenge.Phase.CHOOSING)
		_sorting().choose_bin(SortingRules.correct_bin(item_id))
		_sorting().continue_flow()
	assert_eq(_sorting().phase(), SortingChallenge.Phase.SUMMARY)
	_sorting().continue_flow()
	await wait_physics_frames(2)


func test_both_areas_build_with_every_configured_entity() -> void:
	await _enter(OUTPOST)
	assert_not_null(_find("Player"))
	for type_name in ["ScrapPile", "WaterSource", "RepairStation", "Recording", "AreaExit"]:
		assert_gt(_area.find_children("*", type_name, true, false).size(), 0, type_name)
	_area.queue_free()
	await wait_physics_frames(2)

	await _enter(FACTORY)
	for type_name in ["ScrapPile", "RepairStation", "ArchiveTerminal"]:
		assert_gt(_area.find_children("*", type_name, true, false).size(), 0, type_name)


func test_the_player_spawns_on_open_ground() -> void:
	await _enter(OUTPOST)
	var player: Player = _find("Player")
	var spawn := MapBuilder.cell_center(MapBuilder.markers(MapBuilder.load_layout("res://data/maps/outpost.txt"), "@")[0]["cell"])
	assert_eq(player.global_position, spawn)


func test_the_intro_plays_once_per_run() -> void:
	watch_signals(EventBus)
	await _enter(OUTPOST)
	assert_signal_emitted_with_parameters(EventBus, "dialogue_requested", ["intro"])
	var after_first_visit: int = get_signal_emit_count(EventBus, "dialogue_requested")
	_area.queue_free()
	await wait_physics_frames(2)

	await _enter(OUTPOST)
	assert_eq(get_signal_emit_count(EventBus, "dialogue_requested"), after_first_visit)


func test_water_is_unsafe_until_the_treatment_unit_is_repaired() -> void:
	await _enter(OUTPOST)
	var water: WaterSource = _find("WaterSource")

	water.interact(null)
	assert_true(GameState.has_flag("water_tested"))
	assert_false(GameState.has_flag("water_secure"))

	Survival.damage(30.0)
	Survival.tick(100.0)
	var thirsty := Survival.water()
	water.interact(null)
	assert_eq(Survival.water(), thirsty, "untreated water must not be drinkable")
	assert_false(GameState.has_flag("water_secure"))


func test_a_wrong_sort_teaches_costs_health_and_retries_the_same_item() -> void:
	await _enter(OUTPOST)
	var pile: ScrapPile = _find("ScrapPile")
	pile.interact(null)
	assert_eq(_sorting().phase(), SortingChallenge.Phase.CHOOSING)

	var health := Survival.health()
	_sorting().choose_bin(SortingRules.BIN_GENERAL)
	assert_eq(_sorting().phase(), SortingChallenge.Phase.FEEDBACK_WRONG)
	assert_lt(Survival.health(), health)
	assert_eq(GameState.get_counter("sort_mistakes"), 1)

	_sorting().continue_flow()
	assert_eq(_sorting().phase(), SortingChallenge.Phase.CHOOSING)
	_sorting().choose_bin(SortingRules.BIN_HAZARDOUS)
	assert_eq(_sorting().phase(), SortingChallenge.Phase.FEEDBACK_RIGHT, "the same battery should now be accepted")


func test_a_wrong_sort_never_gives_the_player_the_item() -> void:
	await _enter(OUTPOST)
	_find("ScrapPile").interact(null)
	_sorting().choose_bin(SortingRules.BIN_GENERAL)
	assert_eq(Inventory.snapshot(), {})


func test_full_outpost_loop_sort_repair_drink_record_unlock() -> void:
	await _enter(OUTPOST)
	var pile: ScrapPile = _find("ScrapPile")
	var water: WaterSource = _find("WaterSource")
	var gate: AreaExit = _find("AreaExit")
	var recording: Recording = _find("Recording")
	var treatment: RepairStation = _area.find_children("*", "RepairStation", true, false)[0]

	assert_eq(ObjectivesTracker.current("outpost")["id"], "find_water")
	water.interact(null)
	assert_eq(ObjectivesTracker.current("outpost")["id"], "sort_outpost")

	treatment.interact(null)
	assert_false(GameState.has_flag("treatment_repaired"), "cannot repair with no materials")

	await _sort_pile_correctly(pile)
	assert_freed(pile, "sorted pile")
	assert_true(GameState.has_flag("pile_sorted_outpost"))
	assert_eq(Inventory.snapshot(), {"plastic_bottle": 1, "scrap_metal": 1, "pipe_section": 1}, "only recoverable items are kept")
	assert_false(Inventory.has("battery"), "hazards are not recovered")
	assert_eq(GameState.get_counter("sort_mistakes"), 0)

	assert_false(gate.is_open(), "the gate stays shut before the recording")
	treatment.interact(null)
	assert_true(GameState.has_flag("treatment_repaired"))
	assert_eq(Inventory.snapshot(), {}, "the repair consumed the materials")

	Survival.tick(200.0)
	var before := Survival.water()
	water.interact(null)
	assert_gt(Survival.water(), before, "clean water restores the water meter")
	assert_true(GameState.has_flag("water_secure"))

	recording.interact(null)
	assert_true(GameState.has_flag("recording_found"))
	assert_true(gate.is_open())
	assert_eq(ObjectivesTracker.current("outpost")["id"], "go_factory")


func test_revisiting_a_sorted_area_does_not_respawn_the_pile() -> void:
	await _enter(OUTPOST)
	await _sort_pile_correctly(_find("ScrapPile"))
	_area.queue_free()
	await wait_physics_frames(2)

	await _enter(OUTPOST)
	assert_eq(_area.find_children("*", "ScrapPile", true, false).size(), 0)


func test_factory_loop_to_the_archive() -> void:
	await _enter(FACTORY)
	var pile: ScrapPile = _find("ScrapPile")
	var generator: RepairStation = _find("RepairStation")
	var terminal: ArchiveTerminal = _find("ArchiveTerminal")

	terminal.interact(null)
	assert_false(GameState.has_flag("archive_read"), "terminal needs power first")

	generator.interact(null)
	assert_false(GameState.has_flag("power_restored"), "no materials yet")

	await _sort_pile_correctly(pile)
	assert_eq(Inventory.snapshot(), {"copper_wire": 1, "scrap_metal": 1})
	generator.interact(null)
	assert_true(GameState.has_flag("power_restored"))

	terminal.interact(null)
	assert_false(GameState.has_flag("archive_read"), "the terminal wants its puzzle solved first")
	_solve_puzzle("hazard_route")
	assert_true(GameState.has_flag("archive_read"))


func test_a_collapse_returns_the_player_to_their_start() -> void:
	await _enter(OUTPOST)
	var player: Player = _find("Player")
	var start := player.global_position
	player.global_position = start + Vector2(120, 80)
	Survival.damage(1000.0)
	assert_eq(player.global_position, start)
	assert_eq(Survival.health(), Survival.COLLAPSE_RECOVERY_HEALTH)


func test_dump_loop_from_the_gate_to_the_records() -> void:
	await _enter(DUMP)
	var piles: Array = _area.find_children("*", "ScrapPile", true, false)
	var shelter: RepairStation = _find("RepairStation")
	var recording: Recording = _find("Recording")
	var terminal: ArchiveTerminal = _find("ArchiveTerminal")
	assert_eq(piles.size(), 3)

	terminal.interact(null)
	assert_false(GameState.has_flag("dump_records_read"), "the terminal needs the shelter's solar cell")
	shelter.interact(null)
	assert_false(GameState.has_flag("shelter_built"), "no materials yet")

	for pile: ScrapPile in piles:
		await _sort_pile_correctly(pile)
	assert_eq(GameState.get_counter("sort_mistakes"), 0)
	assert_eq(Inventory.snapshot(), {"cardboard": 2, "tin_can": 2, "glass_jar": 2, "textile_scrap": 2, "scrap_metal": 1})
	assert_eq(ObjectivesTracker.current("dump")["id"], "repair_shelter")

	shelter.interact(null)
	assert_true(GameState.has_flag("shelter_built"))
	assert_eq(Inventory.snapshot(), {"cardboard": 1, "tin_can": 2, "glass_jar": 2, "textile_scrap": 1})

	recording.interact(null)
	assert_true(GameState.has_flag("recording_2_found"))
	assert_false(GameState.has_flag("recording_found"), "chapter 2 must not reuse the outpost flag")

	terminal.interact(null)
	_solve_puzzle("waste_hierarchy")
	assert_true(GameState.has_flag("dump_records_read"))
	assert_eq(ObjectivesTracker.current("dump")["id"], "go_river", "the way on is the last objective here")


func test_dump_gate_in_the_factory_opens_only_after_the_archive() -> void:
	await _enter(FACTORY)
	var gate: AreaExit = _find("AreaExit")
	assert_false(gate.is_open())
	GameState.set_flag("archive_read")
	assert_true(gate.is_open())
	assert_eq(gate.target_scene, "res://world/dump.tscn")


func test_dump_gate_to_the_river_opens_after_the_records() -> void:
	await _enter(DUMP)
	var gate: AreaExit = _find("AreaExit")
	assert_false(gate.is_open())
	GameState.set_flag("dump_records_read")
	assert_true(gate.is_open())
	assert_eq(gate.target_scene, "res://world/river.tscn")


func test_river_loop_from_the_samples_to_clean_water() -> void:
	await _enter(RIVER)
	var piles: Array = _area.find_children("*", "ScrapPile", true, false)
	var samples: Array = _area.find_children("*", "SamplePoint", true, false)
	var plant: RepairStation = _find("RepairStation")
	var console: ArchiveTerminal = _find("ArchiveTerminal")
	var water: WaterSource = _find("WaterSource")
	var recording: Recording = _find("Recording")
	assert_eq(piles.size(), 2)
	assert_eq(samples.size(), 3)

	water.interact(null)
	assert_true(GameState.has_flag("river_water_tested"))
	water.interact(null)
	assert_false(GameState.has_flag("river_water_secure"), "river water is not drinkable yet")

	for sample: SamplePoint in samples:
		sample.interact(null)
	assert_true(GameState.has_flag("samples_done"))
	assert_eq(GameState.get_counter("samples"), 3)
	samples[0].interact(null)
	assert_eq(GameState.get_counter("samples"), 3, "re-reading a strip is not a new sample")

	console.interact(null)
	assert_false(GameState.has_flag("river_clean"), "the console needs the filter first")
	plant.interact(null)
	assert_false(GameState.has_flag("filter_installed"), "no materials yet")

	for pile: ScrapPile in piles:
		await _sort_pile_correctly(pile)
	assert_eq(GameState.get_counter("sort_mistakes"), 0)
	assert_false(Inventory.has("paint_tin"), "hazards are never recovered")
	plant.interact(null)
	assert_true(GameState.has_flag("filter_installed"))
	assert_eq(Inventory.snapshot(), {"plastic_bottle": 1, "tin_can": 1, "kettle": 1, "cardboard": 1, "glass_jar": 1})

	console.interact(null)
	_solve_puzzle("treatment_chain")
	assert_true(GameState.has_flag("river_clean"))

	Survival.tick(200.0)
	var before := Survival.water()
	water.interact(null)
	assert_gt(Survival.water(), before, "treated river water restores the water meter")
	assert_true(GameState.has_flag("river_water_secure"))

	recording.interact(null)
	assert_true(GameState.has_flag("recording_3_found"))
	assert_eq(ObjectivesTracker.current("river"), {})
	assert_true(QuestRules.is_done("water_detective"))
	assert_true(QuestRules.is_done("river_cleanup"))
	assert_true(QuestRules.is_done("filter_builder"))
