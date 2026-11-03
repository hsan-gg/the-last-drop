extends GutTest
## Dusk lighting must exist in every built area without costing the player their view.

const AREAS: Array[String] = ["res://world/outpost.tscn", "res://world/factory.tscn", "res://world/dump.tscn", "res://world/river.tscn"]
const ARRIVALS: Array[String] = ["outpost", "factory", "dump", "river"]


## Arrival dialogue pauses the tree, which would freeze every later test, so mark it seen.
func before_each() -> void:
	GameState.reset()
	for area_id in ARRIVALS:
		GameState.set_flag("arrival_%s_seen" % area_id)


func after_each() -> void:
	get_tree().paused = false
	GameState.reset()


func test_every_area_has_a_player_lantern() -> void:
	for path in AREAS:
		var area: Node = add_child_autofree(load(path).instantiate())
		await wait_physics_frames(2)
		var lantern := area.find_child("Lantern", true, false) as PointLight2D
		assert_not_null(lantern, path)
		assert_gt(lantern.energy, 0.0)
		area.queue_free()
		await wait_physics_frames(2)


func test_interesting_objects_carry_a_light() -> void:
	var area: Node = add_child_autofree(load("res://world/factory.tscn").instantiate())
	await wait_physics_frames(2)
	var terminal := area.find_children("*", "ArchiveTerminal", true, false)[0] as Node
	assert_not_null(terminal.get_node_or_null("DuskLight"))


func test_light_texture_is_shared_and_radial() -> void:
	var texture := AreaLighting.light_texture()
	assert_eq(texture, AreaLighting.light_texture(), "built once")
	assert_eq(texture.fill, GradientTexture2D.FILL_RADIAL)


func test_light_radius_matches_the_spec() -> void:
	var light := AreaLighting.make_light({"color": "#ffffff", "energy": 1.0, "radius": 64.0})
	assert_almost_eq(light.texture_scale * AreaLighting.TEXTURE_SIZE / 2.0, 64.0, 0.01)
	light.free()
