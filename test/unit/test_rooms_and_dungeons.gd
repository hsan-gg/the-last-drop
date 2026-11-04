extends GutTest
## Rooms you walk into and dungeons under the world: their maps, doors, and
## everything inside them must hold together.

const ROOMS: Array[String] = ["tobi_house", "tool_shed", "metro", "halden_office", "recycling_hall", "nana_shack",
	"boathouse", "farmhouse", "barn", "bunker", "slag_mine", "ines_lab"]
const REGIONS: Array[String] = ["outpost", "factory", "dump", "river", "fields", "industry", "sanctuary"]
## Markers you can get past once you have done something (a key, a pickaxe swing).
const OPENABLE_SCENES: Array[String] = ["door", "breakable"]


func _layout(area_id: String) -> PackedStringArray:
	return MapBuilder.load_layout(Content.area(area_id)["layout"])


func test_every_room_has_a_scene_a_rectangular_map_and_one_way_out() -> void:
	for room in ROOMS:
		var config := Content.area(room)
		assert_false(config.is_empty(), "%s has a config" % room)
		assert_true(ResourceLoader.exists("res://world/%s.tscn" % room), "%s has a scene" % room)
		var layout := _layout(room)
		for row in layout:
			assert_eq(row.length(), layout[0].length(), "%s is rectangular" % room)
		assert_eq(MapBuilder.markers(layout, "^").size(), 1, "%s has one way out" % room)
		assert_true(ResourceLoader.exists(MapBuilder.ATLAS_FORMAT % config["tileset"]), "%s tileset" % room)


func test_every_room_uses_known_characters_and_real_scenes() -> void:
	for room in ROOMS:
		var config := Content.area(room)
		var entities: Dictionary = config["entities"]
		for definition: Dictionary in entities.values():
			assert_true(GameArea.ENTITY_SCENES.has(definition["scene"]), "%s: %s" % [room, definition["scene"]])
		for row in _layout(room):
			for ch in row:
				assert_true(ch == "." or MapBuilder.TILE_FOR_CHAR.has(ch) or entities.has(ch), "%s: unknown '%s'" % [room, ch])


func test_everything_in_a_room_can_be_reached_from_the_door() -> void:
	for room in ROOMS:
		var layout := _layout(room)
		var entities: Dictionary = Content.area(room)["entities"]
		var exit: Vector2i = MapBuilder.markers(layout, "^")[0]["cell"]
		var seen := {exit: true}
		var queue: Array[Vector2i] = [exit]
		while not queue.is_empty():
			var cell: Vector2i = queue.pop_front()
			for step in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
				var next: Vector2i = cell + step
				if next.y < 0 or next.y >= layout.size() or next.x < 0 or next.x >= layout[0].length() or seen.has(next):
					continue
				var ch := layout[next.y][next.x]
				var openable: bool = entities.has(ch) and entities[ch]["scene"] in OPENABLE_SCENES
				if (entities.has(ch) and not openable) or MapBuilder.is_solid_char(ch):
					continue
				seen[next] = true
				queue.append(next)
		for marker in MapBuilder.markers(layout, "".join(PackedStringArray(entities.keys()))):
			var cell: Vector2i = marker["cell"]
			var touched := seen.has(cell)
			for step in [Vector2i.RIGHT, Vector2i.LEFT, Vector2i.DOWN, Vector2i.UP]:
				touched = touched or seen.has(cell + step)
			assert_true(touched, "%s: '%s' at %s cannot be reached" % [room, marker["char"], cell])


func test_every_way_out_leads_back_to_its_building() -> void:
	for room in ROOMS:
		var config := Content.area(room)
		var exit: Dictionary = config["entities"]["^"]["props"]
		var region := Content.area(config["region"])
		var building: Dictionary = region["entities"].get(exit["arrive_marker"], {})
		assert_eq(building.get("scene", ""), "building", "%s returns to a building in %s" % [room, config["region"]])
		assert_eq(building.get("props", {}).get("interior", ""), "res://world/%s.tscn" % room, "%s: the building leads back in" % room)


func test_each_building_footprint_matches_its_sprite() -> void:
	for region in REGIONS:
		var layout := _layout(region)
		var entities: Dictionary = Content.area(region)["entities"]
		for marker: String in entities:
			if entities[marker]["scene"] != "building":
				continue
			var size := Building.footprint(entities[marker]["props"]["look"])
			assert_gt(size.x, 0, "%s %s has a sprite" % [region, marker])
			var door: Vector2i = MapBuilder.markers(layout, marker)[0]["cell"]
			var left := door.x - size.x / 2 + (1 if size.x % 2 == 0 else 0)
			for y in range(door.y - size.y + 1, door.y + 1):
				for x in range(left, left + size.x):
					var ch := layout[y][x]
					assert_true(ch == "%" or ch == marker, "%s: %s footprint at (%d,%d) is '%s'" % [region, marker, x, y, ch])
			assert_false(MapBuilder.is_solid_char(layout[door.y + 1][door.x]), "%s: the step in front of %s is clear" % [region, marker])


func test_puzzle_stations_name_real_puzzles() -> void:
	for room in ROOMS:
		for definition: Dictionary in Content.area(room)["entities"].values():
			if definition["scene"] == "puzzle_station":
				var puzzle := Content.puzzle(definition["props"]["puzzle_id"])
				assert_false(puzzle.is_empty(), "%s: puzzle %s" % [room, definition["props"]["puzzle_id"]])
