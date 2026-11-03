class_name MapBuilder
extends RefCounted
## Turns an ASCII layout (data/maps/*.txt) into a TileMapLayer with collision,
## and finds the marker characters where entities go. See tools/generate_maps.py
## for the character legend.

const TILE_SIZE := 16
const ATLAS := preload("res://assets/tilesets/outpost_tiles.png")
## Each region can have its own atlas (same column layout, so the same map
## characters and collision): assets/tilesets/<name>_tiles.png.
const ATLAS_FORMAT := "res://assets/tilesets/%s_tiles.png"
const GROUND_CHAR := "."
const SPAWN_MARKER := "@"
const GROUND_TILES: Array[int] = [0, 1, 2]
const SOLID_TILES: Array[int] = [4, 5, 9, 10, 11, 15, 16, 17, 19]
const TILE_FOR_CHAR := {
	",": 6, "#": 4, "~": 5, ":": 7, "=": 8, "r": 3, "C": 9, "F": 10,
	"P": 11, "M": 12, "D": 13, "T": 14, "t": 15, "B": 16, "S": 17,
	"b": 18, "H": 19,
}


static func load_layout(path: String) -> PackedStringArray:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("MapBuilder: cannot open %s (error %d)" % [path, FileAccess.get_open_error()])
		return PackedStringArray()
	var rows := PackedStringArray()
	for line in file.get_as_text().split("\n"):
		if not line.is_empty():
			rows.append(line)
	return rows


static func layout_size(layout: PackedStringArray) -> Vector2i:
	return Vector2i(layout[0].length() if not layout.is_empty() else 0, layout.size())


static func cell_center(cell: Vector2i) -> Vector2:
	return Vector2(cell * TILE_SIZE) + Vector2(TILE_SIZE, TILE_SIZE) / 2.0


static func is_solid_char(ch: String) -> bool:
	return TILE_FOR_CHAR.has(ch) and TILE_FOR_CHAR[ch] in SOLID_TILES


## Atlas column for a layout character, or -1 if the character is unknown.
## Plain ground varies by cell so large open areas do not look tiled.
static func tile_for_char(ch: String, cell: Vector2i) -> int:
	if ch == GROUND_CHAR:
		var roll := ((cell.x * 73856093) ^ (cell.y * 19349663)) % 10
		return GROUND_TILES[0] if roll < 6 else (GROUND_TILES[1] if roll < 9 else GROUND_TILES[2])
	return TILE_FOR_CHAR.get(ch, -1)


## Cells holding any of `marker_chars`, as {"char": String, "cell": Vector2i}.
static func markers(layout: PackedStringArray, marker_chars: String) -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for y in layout.size():
		for x in layout[y].length():
			var ch := layout[y][x]
			if marker_chars.contains(ch):
				found.append({"char": ch, "cell": Vector2i(x, y)})
	return found


## `marker_floor` is the floor drawn under marker cells.
static func build_layer(layout: PackedStringArray, marker_chars: String, marker_floor: String, tileset: String = "") -> TileMapLayer:
	var layer := TileMapLayer.new()
	layer.name = "Ground"
	layer.tile_set = make_tile_set(atlas_for(tileset))
	for y in layout.size():
		for x in layout[y].length():
			var cell := Vector2i(x, y)
			var ch := layout[y][x]
			if marker_chars.contains(ch):
				ch = marker_floor
			var tile := tile_for_char(ch, cell)
			if tile < 0:
				push_error("MapBuilder: unknown character '%s' at %s" % [ch, cell])
				tile = GROUND_TILES[0]
			layer.set_cell(cell, 0, Vector2i(tile, 0))
	return layer


static func atlas_for(tileset: String) -> Texture2D:
	var path := ATLAS_FORMAT % tileset
	if tileset.is_empty() or not ResourceLoader.exists(path):
		return ATLAS
	return load(path) as Texture2D


static func make_tile_set(atlas: Texture2D = ATLAS) -> TileSet:
	var tile_set := TileSet.new()
	tile_set.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_physics_layer()
	tile_set.set_physics_layer_collision_layer(0, 1)
	tile_set.set_physics_layer_collision_mask(0, 0)

	var source := TileSetAtlasSource.new()
	source.texture = atlas
	source.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	tile_set.add_source(source, 0)

	var half := TILE_SIZE / 2.0
	var square := PackedVector2Array([Vector2(-half, -half), Vector2(half, -half), Vector2(half, half), Vector2(-half, half)])
	@warning_ignore("integer_division")
	var columns := atlas.get_width() / TILE_SIZE
	for column in columns:
		var coords := Vector2i(column, 0)
		source.create_tile(coords)
		if column in SOLID_TILES:
			var data := source.get_tile_data(coords, 0)
			data.add_collision_polygon(0)
			data.set_collision_polygon_points(0, 0, square)
	return tile_set
