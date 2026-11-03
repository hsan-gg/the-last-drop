extends GutTest
## Plays the three later regions with the real scenes, the way a player would:
## sort, repair, solve, harvest, power and reach the ending's requirements.

const FIELDS := preload("res://world/fields.tscn")
const INDUSTRY := preload("res://world/industry.tscn")
const SANCTUARY := preload("res://world/sanctuary.tscn")
const FIXED_PILES := {
	"fields_plots": ["textile_scrap", "food_scraps", "cardboard", "battery"],
	"fields_barn": ["pipe_section", "scrap_metal", "glass_shard", "chemical_can"],
	"industry_yard": ["copper_wire", "scrap_metal", "chemical_can", "paint_tin"],
	"industry_store": ["copper_wire", "scrap_metal", "pipe_section", "battery"],
	"sanctuary_store": ["copper_wire", "pipe_section", "glass_jar", "fluorescent_tube"],
}

var _area: Node


func before_each() -> void:
	Chapters.ending_enabled = false
	Combat.enemies_enabled = false
	Inventory.clear()
	GameState.reset()
	Survival.set_process(false)
	Survival.reset()


func after_each() -> void:
	Chapters.ending_enabled = true
	Survival.reset()
	Survival.set_process(true)


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
	for type_name in ["DialogueBox", "SortingChallenge", "QuizPanel", "PuzzlePanel"]:
		for overlay in _area.find_children("*", type_name, true, false):
			overlay.pauses_game = false


func _find(type_name: String) -> Node:
	return _area.find_children("*", type_name, true, false)[0]


func _sort_all() -> void:
	for pile: ScrapPile in _area.find_children("*", "ScrapPile", true, false):
		var sorting: SortingChallenge = _find("SortingChallenge")
		pile.interact(null)
		for item_id in pile.item_ids:
			sorting.choose_bin(SortingRules.correct_bin(item_id))
			sorting.continue_flow()
		sorting.continue_flow()
		await wait_physics_frames(2)


func _solve(puzzle_id: String) -> void:
	var panel: PuzzlePanel = _find("PuzzlePanel")
	assert_eq(panel.phase(), PuzzlePanel.Phase.SOLVING, puzzle_id)
	for step: String in Content.puzzle(puzzle_id)["steps"]:
		panel.choose(step)
	panel.continue_flow()


func _onward_gate() -> AreaExit:
	for gate: AreaExit in _area.find_children("*", "AreaExit", true, false):
		if not gate.required_flag.is_empty():
			return gate
	return null


func test_the_fields_from_dead_soil_to_the_first_harvest() -> void:
	await _enter(FIELDS)
	var bin: RepairStation = _find("RepairStation")
	var probe: ArchiveTerminal = _find("ArchiveTerminal")
	var bed: HarvestPlot = _find("HarvestPlot")
	bed.interact(null)
	assert_false(GameState.has_flag("harvest_done"), "nothing grows in dead soil")
	await _sort_all()
	bin.interact(null)
	assert_true(GameState.has_flag("compost_built"))
	probe.interact(null)
	_solve("compost_layers")
	assert_true(GameState.has_flag("soil_restored"))
	Survival.damage(50.0)
	bed.interact(null)
	assert_true(GameState.has_flag("harvest_done"))
	assert_eq(Survival.health(), Survival.max_health(), "the first food heals")
	var gate := _onward_gate()
	assert_true(gate.story_ready())
	assert_false(gate.is_open(), "the rail line waits for the region's power")
	assert_gt(_area.find_children("*", "Npc", true, false).size(), 1, "Lena and Jory live here")


func test_the_industry_from_scrap_to_a_balanced_grid() -> void:
	await _enter(INDUSTRY)
	var array: RepairStation = _find("RepairStation")
	var console: ArchiveTerminal = _find("ArchiveTerminal")
	await _sort_all()
	array.interact(null)
	assert_true(GameState.has_flag("grid_built"))
	console.interact(null)
	_solve("power_grid")
	assert_true(GameState.has_flag("grid_online"))
	assert_true(_onward_gate().story_ready())


func test_the_sanctuary_from_dark_atrium_to_the_ending() -> void:
	await _enter(SANCTUARY)
	var core: RepairStation = _find("RepairStation")
	var archive: ArchiveTerminal = _find("ArchiveTerminal")
	var recording: Recording = _find("Recording")
	await _sort_all()
	core.interact(null)
	assert_true(GameState.has_flag("sanctuary_powered"))
	archive.interact(null)
	_solve("timeline")
	assert_true(GameState.has_flag("archive_complete"))
	recording.interact(null)
	assert_true(Chapters.ending_ready("sanctuary"), "the archive and Ines's last words end the game")


func test_friends_only_come_to_the_sanctuary_when_the_story_brings_them() -> void:
	await _enter(SANCTUARY)
	var names := _area.find_children("*", "Npc", true, false).map(func(npc: Npc) -> String: return npc.npc_id)
	assert_true(names.has("warden"))
	assert_false(names.has("tobi_s"), "Tobi has not remembered yet")
	_area.queue_free()
	await wait_physics_frames(2)
	GameState.set_flag("tobi_remembered")
	await _enter(SANCTUARY)
	names = _area.find_children("*", "Npc", true, false).map(func(npc: Npc) -> String: return npc.npc_id)
	assert_true(names.has("tobi_s"), "he made it")
