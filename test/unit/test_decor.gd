extends GutTest
## Decor markers in data/areas.json must name real sprites and build working props.

const AREA_IDS: Array[String] = ["outpost", "factory", "dump", "river"]
const DECOR_SCENE := preload("res://world/decor.tscn")


func _decor_definitions() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for area_id in AREA_IDS:
		for definition: Dictionary in Content.area(area_id).get("entities", {}).values():
			if definition.get("scene", "") == "decor":
				found.append(definition)
	return found


func test_every_decor_sprite_exists() -> void:
	var definitions := _decor_definitions()
	assert_gt(definitions.size(), 0)
	for definition in definitions:
		var path: String = Decor.SPRITE_PATH_FORMAT % definition["props"]["sprite_name"]
		assert_true(ResourceLoader.exists(path), path)


func test_a_solid_decor_prop_blocks_the_player() -> void:
	var decor: Decor = DECOR_SCENE.instantiate()
	decor.sprite_name = "dumpster"
	decor.blocker_size = Vector2(44, 12)
	add_child_autofree(decor)
	assert_not_null(decor.get_node_or_null("Sprite"))
	assert_eq(decor.find_children("*", "CollisionShape2D", false, false).size(), 1)
	assert_eq(decor.collision_layer, 1)


func test_a_walkable_prop_has_no_collision_and_a_light_when_asked() -> void:
	var decor: Decor = DECOR_SCENE.instantiate()
	decor.sprite_name = "fire"
	decor.light_color = "#ff9a4a"
	add_child_autofree(decor)
	assert_eq(decor.find_children("*", "CollisionShape2D", false, false).size(), 0)
	assert_not_null(decor.get_node_or_null("DuskLight"))


func test_blocker_size_arrives_from_json_as_a_vector() -> void:
	var definition: Dictionary = Content.area("dump")["entities"]["d"]
	var area := GameArea.new()
	var typed: Variant = area._typed(definition["props"]["blocker_size"], Vector2.ZERO)
	assert_eq(typed, Vector2(44, 12))
	area.free()
