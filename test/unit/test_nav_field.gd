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
