extends GutTest
## Validates the ASCII maps and data/areas.json together, so a layout or config
## typo fails here instead of as a broken level.

const AREA_IDS: Array[String] = ["outpost", "factory"]
const NON_BLOCKING_MARKER := "@"


func _layout(area_id: String) -> PackedStringArray:
	return MapBuilder.load_layout(Content.area(area_id)["layout"])


func _marker_chars(area_id: String) -> String:
	var entities: Dictionary = Content.area(area_id).get("entities", {})
	return MapBuilder.SPAWN_MARKER + "".join(PackedStringArray(entities.keys()))


func _is_blocked(layout: PackedStringArray, marker_chars: String, cell: Vector2i) -> bool:
	var ch := layout[cell.y][cell.x]
	if marker_chars.contains(ch):
		return ch != NON_BLOCKING_MARKER
	return MapBuilder.is_solid_char(ch)


func _reachable(layout: PackedStringArray, marker_chars: String, start: Vector2i) -> Dictionary:
	var size := MapBuilder.layout_size(layout)
	var seen := {start: true}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_front()
		for step in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
			var next: Vector2i = cell + step
			if next.x < 0 or next.y < 0 or next.x >= size.x or next.y >= size.y or seen.has(next):
				continue
			if _is_blocked(layout, marker_chars, next):
				continue
			seen[next] = true
			queue.append(next)
	return seen


func test_every_area_has_a_config_and_layout() -> void:
	for area_id in AREA_IDS:
		assert_false(Content.area(area_id).is_empty(), area_id)
		assert_false(_layout(area_id).is_empty(), area_id)


func test_layouts_are_rectangular() -> void:
	for area_id in AREA_IDS:
		var layout := _layout(area_id)
		var width := layout[0].length()
		for row in layout.size():
			assert_eq(layout[row].length(), width, "%s row %d" % [area_id, row])


func test_layouts_use_only_known_characters() -> void:
	for area_id in AREA_IDS:
		var layout := _layout(area_id)
		var markers := _marker_chars(area_id)
		for row in layout.size():
			for column in layout[row].length():
				var ch := layout[row][column]
				var known := ch == MapBuilder.GROUND_CHAR or MapBuilder.TILE_FOR_CHAR.has(ch) or markers.contains(ch)
				assert_true(known, "%s: '%s' at (%d,%d)" % [area_id, ch, column, row])


func test_each_area_has_exactly_one_spawn() -> void:
	for area_id in AREA_IDS:
		var spawns := MapBuilder.markers(_layout(area_id), MapBuilder.SPAWN_MARKER)
		assert_eq(spawns.size(), 1, area_id)


func test_every_configured_entity_is_placed_exactly_once() -> void:
	for area_id in AREA_IDS:
		var layout := _layout(area_id)
		for marker: String in Content.area(area_id)["entities"]:
			assert_eq(MapBuilder.markers(layout, marker).size(), 1, "%s marker %s" % [area_id, marker])


func test_the_map_is_sealed_by_solid_edges() -> void:
	for area_id in AREA_IDS:
		var layout := _layout(area_id)
		var markers := _marker_chars(area_id)
		var size := MapBuilder.layout_size(layout)
		for x in size.x:
			assert_true(_is_blocked(layout, markers, Vector2i(x, 0)) or layout[0][x] == "^", "%s top %d" % [area_id, x])
			assert_true(_is_blocked(layout, markers, Vector2i(x, size.y - 1)), "%s bottom %d" % [area_id, x])
		for y in size.y:
			assert_true(_is_blocked(layout, markers, Vector2i(0, y)), "%s left %d" % [area_id, y])
			assert_true(_is_blocked(layout, markers, Vector2i(size.x - 1, y)), "%s right %d" % [area_id, y])


func test_every_interactable_is_reachable_from_the_spawn() -> void:
	for area_id in AREA_IDS:
		var layout := _layout(area_id)
		var markers := _marker_chars(area_id)
		var spawn: Vector2i = MapBuilder.markers(layout, MapBuilder.SPAWN_MARKER)[0]["cell"]
		var reachable := _reachable(layout, markers, spawn)
		for marker in MapBuilder.markers(layout, markers):
			if marker["char"] == MapBuilder.SPAWN_MARKER:
				continue
			var cell: Vector2i = marker["cell"]
			var touched := false
			for step in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
				touched = touched or reachable.has(cell + step)
			assert_true(touched, "%s: '%s' at %s cannot be reached" % [area_id, marker["char"], cell])


func test_entity_configs_reference_real_scenes_items_and_repairs() -> void:
	for area_id in AREA_IDS:
		var config := Content.area(area_id)
		for marker: String in config["entities"]:
			var definition: Dictionary = config["entities"][marker]
			assert_true(GameArea.ENTITY_SCENES.has(definition["scene"]), "%s: scene %s" % [area_id, definition["scene"]])
			var props: Dictionary = definition.get("props", {})
			for item_id: String in props.get("item_ids", []):
				assert_true(ItemDB.has_item(item_id), "%s pile item %s" % [area_id, item_id])
			if props.has("repair_id"):
				assert_true(RepairRules.exists(props["repair_id"]), "%s repair %s" % [area_id, props["repair_id"]])
			if props.has("target_scene"):
				assert_true(ResourceLoader.exists(props["target_scene"]), props["target_scene"])


func test_every_pile_can_supply_its_areas_repair() -> void:
	# A repair must be completable from what the player can legitimately recover.
	for area_id in AREA_IDS:
		var recoverable := {}
		var needed := {}
		for definition: Dictionary in Content.area(area_id)["entities"].values():
			var props: Dictionary = definition.get("props", {})
			for item_id: String in props.get("item_ids", []):
				if SortingRules.correct_bin(item_id) == SortingRules.BIN_RECOVERY:
					recoverable[item_id] = int(recoverable.get(item_id, 0)) + 1
			if props.has("repair_id"):
				var requires: Dictionary = Content.repair(props["repair_id"])["requires"]
				for item_id: String in requires:
					needed[item_id] = int(needed.get(item_id, 0)) + int(requires[item_id])
		for item_id: String in needed:
			assert_gte(int(recoverable.get(item_id, 0)), int(needed[item_id]), "%s: not enough %s to repair" % [area_id, item_id])


func test_tile_set_makes_only_solid_tiles_collide() -> void:
	var tile_set := MapBuilder.make_tile_set()
	assert_eq(tile_set.get_physics_layers_count(), 1)
	var source: TileSetAtlasSource = tile_set.get_source(0)
	for column in source.get_tiles_count():
		var data := source.get_tile_data(Vector2i(column, 0), 0)
		var expected := 1 if column in MapBuilder.SOLID_TILES else 0
		assert_eq(data.get_collision_polygons_count(0), expected, "tile %d" % column)


func test_build_layer_fills_every_cell() -> void:
	var layout := _layout("outpost")
	var size := MapBuilder.layout_size(layout)
	var layer := MapBuilder.build_layer(layout, _marker_chars("outpost"), ".")
	add_child_autofree(layer)
	assert_eq(layer.get_used_cells().size(), size.x * size.y)


func test_ground_variants_are_deterministic() -> void:
	assert_eq(MapBuilder.tile_for_char(".", Vector2i(5, 9)), MapBuilder.tile_for_char(".", Vector2i(5, 9)))
	assert_eq(MapBuilder.tile_for_char("#", Vector2i(0, 0)), 4)
	assert_eq(MapBuilder.tile_for_char("?", Vector2i(0, 0)), -1)
