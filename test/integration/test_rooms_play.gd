extends GutTest
## Walks into the real rooms and dungeons and uses what is inside: a fuse box
## that hands over the pickaxe, ore and a hidden room in the metro, a locked
## gate, the workbench, and the way back out to the right building.

const ROOMS: Array[String] = ["tobi_house", "tool_shed", "metro", "halden_office", "recycling_hall", "nana_shack",
	"boathouse", "farmhouse", "barn", "bunker", "slag_mine", "ines_lab"]

var _area: GameArea


func before_each() -> void:
	Chapters.ending_enabled = false
	Combat.enemies_enabled = false
	Inventory.clear()
	Gear.reset()
	GameState.reset()
	Survival.set_process(false)
	Survival.reset()


func after_each() -> void:
	Chapters.ending_enabled = true
	Survival.reset()
	Survival.set_process(true)
	Inventory.clear()
	get_tree().paused = false


func _enter(room: String) -> void:
	_area = load("res://world/%s.tscn" % room).instantiate()
	add_child_autofree(_area)
	await wait_physics_frames(2)


func _first(type_name: String) -> Node:
	var found := _area.find_children("*", type_name, true, false)
	return found[0] if not found.is_empty() else null


func _station(puzzle_id: String) -> PuzzleStation:
	for station: PuzzleStation in _area.find_children("*", "PuzzleStation", true, false):
		if station.puzzle_id == puzzle_id:
			return station
	return null


func test_every_room_loads_with_the_player_inside_by_the_door() -> void:
	for room in ROOMS:
		await _enter(room)
		var player := _first("Player") as Player
		assert_true(_area.is_open_ground(player.global_position), "%s: the player stands on the floor" % room)
		var exit: Vector2i = MapBuilder.markers(MapBuilder.load_layout(Content.area(room)["layout"]), "^")[0]["cell"]
		assert_lt(player.global_position.distance_to(MapBuilder.cell_center(exit)), 40.0, "%s: next to the way out" % room)
		_area.queue_free()
		await wait_physics_frames(1)


func test_the_shed_fuse_box_hands_over_the_pickaxe() -> void:
	await _enter("tool_shed")
	var station := _station("shed_fusebox")
	station.interact(null)
	var game: CircuitGame = _first("CircuitGame")
	assert_eq(game.phase(), MiniGame.Phase.PLAYING, "the fuse box opens its puzzle")
	var board := game.board
	for index in board._solution.size():
		var cell := Vector2i(index % board.width, index / board.width)
		while board.piece(cell) != board._solution[index] and game.phase() == MiniGame.Phase.PLAYING:
			game.turn(cell)
	game.leave()
	assert_true(Inventory.has("pickaxe"), "the pickaxe is yours")
	assert_true(GameState.has_flag("shed_power"))


func test_ore_needs_a_pickaxe_and_a_cracked_wall_hides_a_room() -> void:
	await _enter("metro")
	var vein: Breakable = null
	var wall: Breakable = null
	for breakable: Breakable in _area.find_children("*", "Breakable", true, false):
		if breakable.is_ore() and vein == null:
			vein = breakable
		elif breakable.secret:
			wall = breakable
	vein.take_hit(10.0, Vector2.ZERO, 0.0)
	assert_eq(vein.hits_left(), vein.hits, "too hard without a pickaxe")
	Inventory.add("pickaxe")
	for _i in vein.hits:
		vein.take_hit(10.0, Vector2.ZERO, 0.0)
	assert_eq(GameState.get_counter("ore_mined"), 1, "the vein broke")
	for _i in wall.hits:
		wall.take_hit(10.0, Vector2.ZERO, 0.0)
	assert_eq(GameState.get_counter("secrets_found"), 1, "a hidden room")
	assert_true(GameState.has_flag(wall._broken_flag()), "and it stays open")


func test_the_service_gate_opens_with_the_metro_key() -> void:
	await _enter("metro")
	var gate: Door = null
	for door: Door in _area.find_children("*", "Door", true, false):
		if door.is_barrier():
			gate = door
	assert_false(gate.is_open())
	gate.go()
	assert_false(gate.is_open(), "locked without the key")
	Inventory.add("metro_key")
	gate.go()
	assert_true(gate.is_open(), "the key opens it")
	assert_false(Inventory.has("metro_key"), "and stays in the lock")
	assert_eq(gate._barrier.collision_layer, 0, "you can walk through")


func test_the_workbench_turns_ore_into_a_blade() -> void:
	await _enter("tobi_house")
	for _i in 3:
		Inventory.add("iron_ore")
	Inventory.add("coal")
	_first("Workbench").interact(null)
	var bench: CraftPanel = _first("CraftPanel")
	assert_true(bench.is_open())
	bench._selected = RecipeBook.all().map(func(r: Dictionary) -> String: return r["id"]).find("scrap_blade")
	assert_true(bench.make_selected())
	assert_true(Gear.is_owned("scrap_blade"))
	assert_eq(Inventory.count("iron_ore"), 0, "the ore was used")


func test_a_building_door_leads_inside_and_the_way_out_leads_back() -> void:
	var region := Content.area("outpost")
	var house: Dictionary = region["entities"]["0"]["props"]
	assert_eq(house["interior"], "res://world/tobi_house.tscn")
	var exit: Dictionary = Content.area("tobi_house")["entities"]["^"]["props"]
	assert_eq(exit["target_scene"], "res://world/outpost.tscn")
	assert_eq(exit["arrive_marker"], "0")
