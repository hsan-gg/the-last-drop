extends GutTest
## Zombies find their way round rivers and walls.

const ROOM: Array[String] = [
	"##########",
	"#........#",
	"#.~~~~~~.#",
	"#.~~~~~~.#",
	"#........#",
	"##########",
]


func _field() -> NavField:
	return NavField.new(PackedStringArray(ROOM))


func _centre(x: int, y: int) -> Vector2:
	return NavField.centre_of(Vector2i(x, y))


func test_open_ground_and_water() -> void:
	var field := _field()
	assert_true(field.is_open(Vector2i(1, 1)))
	assert_false(field.is_open(Vector2i(3, 2)), "the river blocks")
	assert_false(field.is_open(Vector2i(0, 0)), "walls block")


func test_distances_go_round_the_river() -> void:
	var field := _field()
	field.set_target(_centre(4, 4))
	assert_eq(field.distance_at(Vector2i(4, 4)), 0)
	assert_eq(field.distance_at(Vector2i(4, 1)), 9, "round the end of the river, not through it")
	assert_eq(field.distance_at(Vector2i(4, 2)), NavField.UNREACHABLE)


func test_with_a_clear_view_it_walks_straight() -> void:
	var field := _field()
	field.set_target(_centre(8, 1))
	var way := field.direction(_centre(1, 1), _centre(8, 1))
	assert_almost_eq(way.x, 1.0, 0.01)


func test_with_the_river_between_it_walks_round() -> void:
	var field := _field()
	var player := _centre(4, 4)
	field.set_target(player)
	var from := _centre(4, 1)
	var way := field.direction(from, player)
	assert_lt(absf(way.y), 0.9, "it does not walk straight into the water")
	var walker := from
	for _step in 40:
		walker += field.direction(walker, player) * 4.0
		assert_true(field.is_open(NavField.cell_of(walker)), "never steps into water or wall")
	assert_lt(walker.distance_to(player), 10.0, "and arrives")


func _crate_at(cell: Vector2i) -> StaticBody2D:
	var crate := StaticBody2D.new()
	crate.collision_layer = 1
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(14, 12)
	shape.shape = box
	crate.add_child(shape)
	crate.position = NavField.centre_of(cell)
	add_child_autofree(crate)
	return crate


func test_solid_props_on_the_map_block_the_way_and_are_walked_round() -> void:
	# Regression: only the map's walls counted, so zombies pushed into crates.
	var hall := NavField.new(PackedStringArray([
		"#######",
		"#.....#",
		"#.....#",
		"#.....#",
		"#######",
	]))
	var crate := _crate_at(Vector2i(3, 2))
	await wait_physics_frames(2)
	hall.scan_bodies(get_tree().root.get_world_2d().direct_space_state)
	assert_false(hall.is_open(Vector2i(3, 2)), "the crate's cell is blocked")
	assert_false(hall.has_clear_line(_centre(1, 2), _centre(5, 2)), "no walking straight through it")
	hall.set_target(_centre(5, 2))
	var way := hall.direction(_centre(2, 2), _centre(5, 2))
	assert_ne(way.y, 0.0, "steps up or down to go round")
	crate.free()
	await wait_physics_frames(2)
	hall.scan_bodies(get_tree().root.get_world_2d().direct_space_state)
	assert_true(hall.is_open(Vector2i(3, 2)), "a prop that is gone frees its cell")


func test_a_player_pressed_against_a_crate_is_still_found() -> void:
	var hall := NavField.new(PackedStringArray(["#####", "#...#", "#...#", "#####"]))
	_crate_at(Vector2i(3, 1))
	await wait_physics_frames(2)
	hall.scan_bodies(get_tree().root.get_world_2d().direct_space_state)
	hall.set_target(_centre(3, 1))
	assert_ne(hall.distance_at(Vector2i(1, 2)), NavField.UNREACHABLE)
