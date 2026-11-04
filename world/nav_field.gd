class_name NavField
extends RefCounted
## How zombies find their way round rivers and walls: a flow field over the
## map grid. One breadth-first search from the player's cell gives every walkable
## cell its step distance to the player; a zombie walks to whichever neighbour
## is closer. The search reruns only when the player moves to another cell, and
## every zombie shares it, so a crowd costs no more than one.
##
## When a zombie can see the player across open ground it walks straight at
## them instead, so the grid never makes chasing look robotic.
##
## The map's walls and water come from the layout; the solid things standing on
## it (crates, cars, machines, furniture, gates, cracked walls) come from a scan
## of the physics world, repeated now and then so a wall broken through or a
## gate opened becomes a way through.

const UNREACHABLE := -1
## The square probed at each cell's centre when scanning for solid things.
const PROBE_SIZE := 10.0
## How wide a zombie is, either side of the line it walks.
const BODY_HALF_WIDTH := 5.0
## Eight directions; a diagonal step is allowed only if both sides are open, so
## nobody squeezes through the corner where two walls touch.
const STEPS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

var _width := 0
var _height := 0
var _open := PackedByteArray()
var _map_open := PackedByteArray()
var _distance := PackedInt32Array()
var _target := Vector2i(-9999, -9999)


func _init(layout: PackedStringArray) -> void:
	_height = layout.size()
	for row in layout:
		_width = maxi(_width, row.length())
	_open.resize(_width * _height)
	_distance.resize(_width * _height)
	_distance.fill(UNREACHABLE)
	for y in _height:
		for x in _width:
			var ch := layout[y][x] if x < layout[y].length() else "#"
			_open[y * _width + x] = 0 if MapBuilder.is_solid_char(ch) else 1
	_map_open = _open.duplicate()


## Closes every open cell that a solid body (collision layer 1) stands on, and
## reopens cells whose body is gone. Call after the level's bodies exist.
func scan_bodies(space: PhysicsDirectSpaceState2D) -> void:
	var probe := PhysicsShapeQueryParameters2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(PROBE_SIZE, PROBE_SIZE)
	probe.shape = box
	probe.collision_mask = 1
	probe.collide_with_areas = false
	probe.collide_with_bodies = true
	var scanned := _map_open.duplicate()
	for y in _height:
		for x in _width:
			var index := y * _width + x
			if scanned[index] == 0:
				continue
			probe.transform = Transform2D(0.0, centre_of(Vector2i(x, y)))
			if not space.intersect_shape(probe, 1).is_empty():
				scanned[index] = 0
	if scanned != _open:
		_open = scanned
		_target = Vector2i(-9999, -9999)  # the next set_target searches again

static func cell_of(point: Vector2) -> Vector2i:
	return Vector2i((point / MapBuilder.TILE_SIZE).floor())


static func centre_of(cell: Vector2i) -> Vector2:
	return (Vector2(cell) + Vector2(0.5, 0.5)) * MapBuilder.TILE_SIZE


func is_open(cell: Vector2i) -> bool:
	return cell.x >= 0 and cell.y >= 0 and cell.x < _width and cell.y < _height and _open[cell.y * _width + cell.x] == 1


func distance_at(cell: Vector2i) -> int:
	if cell.x < 0 or cell.y < 0 or cell.x >= _width or cell.y >= _height:
		return UNREACHABLE
	return _distance[cell.y * _width + cell.x]


## Points the field at `point` (the player). Cheap to call every frame.
func set_target(point: Vector2) -> void:
	var cell := cell_of(point)
	if cell == _target:
		return
	_target = cell
	_distance.fill(UNREACHABLE)
	if not is_open(cell):
		# Standing against a crate: search from the open cell beside the player.
		cell = _open_neighbour(cell)
		if not is_open(cell):
			return
	var queue: Array[Vector2i] = [cell]
	_distance[cell.y * _width + cell.x] = 0
	var head := 0
	while head < queue.size():
		var current := queue[head]
		head += 1
		var next_distance := _distance[current.y * _width + current.x] + 1
		for step in STEPS:
			var next := current + step
			if not _can_step(current, step) or _distance[next.y * _width + next.x] != UNREACHABLE:
				continue
			_distance[next.y * _width + next.x] = next_distance
			queue.append(next)


## Which way to walk from `from` to reach the target: straight at `goal` when
## the way is clear, otherwise towards the neighbouring cell nearest the target.
## Zero when there is no way at all.
func direction(from: Vector2, goal: Vector2, allow_straight: bool = true) -> Vector2:
	if allow_straight and has_clear_line(from, goal):
		return (goal - from).normalized()
	var cell := cell_of(from)
	var best := distance_at(cell)
	var best_cell := cell
	if best == UNREACHABLE:  # pushed into a wall's edge: step back to open ground
		best = 1 << 30
	for step in STEPS:
		var next := cell + step
		var value := distance_at(next)
		if value != UNREACHABLE and value < best and _can_step(cell, step):
			best = value
			best_cell = next
	if best_cell == cell:
		return Vector2.ZERO
	return (centre_of(best_cell) - from).normalized()


## Which way the path goes from `from`, never cutting straight across: for a
## zombie that got stuck trying the direct line.
func path_direction(from: Vector2) -> Vector2:
	return direction(from, from, false)


## Whether a straight walk from `from` to `to` crosses only open cells. Samples
## along the line, with a little width either side for the zombie's body.
func has_clear_line(from: Vector2, to: Vector2) -> bool:
	var length := from.distance_to(to)
	if length < 1.0:
		return true
	var along := (to - from) / length
	var side := along.orthogonal() * BODY_HALF_WIDTH
	var steps := int(ceil(length / 6.0))
	for index in steps + 1:
		var point := from + along * minf(index * 6.0, length)
		if not is_open(cell_of(point + side)) or not is_open(cell_of(point - side)):
			return false
	return true


func _can_step(from: Vector2i, step: Vector2i) -> bool:
	if not is_open(from + step):
		return false
	if step.x != 0 and step.y != 0:
		return is_open(from + Vector2i(step.x, 0)) and is_open(from + Vector2i(0, step.y))
	return true


func _open_neighbour(cell: Vector2i) -> Vector2i:
	for step in STEPS:
		if is_open(cell + step):
			return cell + step
	return cell
