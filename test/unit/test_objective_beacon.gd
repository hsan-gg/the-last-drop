extends GutTest
## The beacon picks the right target from data: scene type, props and "not yet tested" rules.


func before_each() -> void:
	GameState.reset()


func _node(position: Vector2, props: Dictionary) -> Node2D:
	var node := Node2D.new()
	node.position = position
	node.set_meta("props", props)
	add_child_autofree(node)
	return node


func test_every_objective_has_a_target_that_names_a_real_entity_scene() -> void:
	for objective: Dictionary in Content.objectives():
		assert_true(objective.has("target"), "%s has no target" % objective["id"])
		var scene: String = objective["target"]["scene"]
		var found := false
		for area_id in ["outpost", "factory", "dump", "river", "fields", "industry", "sanctuary"]:
			for definition: Dictionary in Content.area(area_id)["entities"].values():
				found = found or definition["scene"] == scene
		assert_true(found, "%s targets unknown scene %s" % [objective["id"], scene])


func test_the_nearest_matching_node_is_chosen() -> void:
	var near := _node(Vector2(10, 0), {})
	var far := _node(Vector2(200, 0), {})
	assert_eq(ObjectiveBeacon.pick_target({}, [far, near], Vector2.ZERO), near)


func test_props_must_match() -> void:
	var west := _node(Vector2(10, 0), {"pile_id": "dump_west"})
	var east := _node(Vector2(500, 0), {"pile_id": "dump_east"})
	var spec := {"props": {"pile_id": "dump_east"}}
	assert_eq(ObjectiveBeacon.pick_target(spec, [west, east], Vector2.ZERO), east)


func test_untested_sample_points_are_preferred() -> void:
	var tested := _node(Vector2(10, 0), {"sample_id": "a"})
	var fresh := _node(Vector2(300, 0), {"sample_id": "b"})
	GameState.set_flag("sample_a")
	var spec := {"scene": "sample_point", "untested_flag": "sample_%s", "flag_prop": "sample_id"}
	assert_eq(ObjectiveBeacon.pick_target(spec, [tested, fresh], Vector2.ZERO), fresh)


func test_no_match_gives_no_target() -> void:
	assert_null(ObjectiveBeacon.pick_target({"props": {"pile_id": "x"}}, [_node(Vector2.ZERO, {})], Vector2.ZERO))
	assert_null(ObjectiveBeacon.pick_target({}, [], Vector2.ZERO))
