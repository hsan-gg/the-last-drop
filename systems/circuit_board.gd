class_name CircuitBoard
extends RefCounted
## The "reconnect the line" puzzle: a grid of wire (or pipe) pieces, each
## turned the wrong way. Turn them until every piece is joined to the source.
## Built from a random spanning tree, so there is always exactly one way to
## join everything, then each piece is spun at random.
##
## A piece is a mask of its open sides: N=1, E=2, S=4, W=8.

const NORTH := 1
const EAST := 2
const SOUTH := 4
const WEST := 8
const SIDES: Array[int] = [NORTH, EAST, SOUTH, WEST]
const STEP := {NORTH: Vector2i(0, -1), EAST: Vector2i(1, 0), SOUTH: Vector2i(0, 1), WEST: Vector2i(-1, 0)}
const OPPOSITE := {NORTH: SOUTH, EAST: WEST, SOUTH: NORTH, WEST: EAST}

var width := 0
var height := 0
var source := Vector2i.ZERO
var _pieces := PackedInt32Array()
var _solution := PackedInt32Array()


func _init(board_width: int, board_height: int, seed_value: int) -> void:
	width = board_width
	height = board_height
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	source = Vector2i(rng.randi_range(0, width - 1), rng.randi_range(0, height - 1))
	_pieces.resize(width * height)
	_pieces.fill(0)
	_grow_tree(rng)
	_solution = _pieces.duplicate()
	for index in _pieces.size():  # scramble, but never leave it already solved
		_pieces[index] = rotated(_pieces[index], rng.randi_range(1, 3))
	if is_solved():
		_pieces[0] = rotated(_pieces[0], 1)


static func rotated(mask: int, turns: int) -> int:
	var result := mask
	for _turn in turns % 4:
		result = ((result << 1) | (result >> 3)) & 15
	return result


func piece(cell: Vector2i) -> int:
	return _pieces[cell.y * width + cell.x]


## Ends (a single opening) are the lamps or taps the line must reach.
func is_end(cell: Vector2i) -> bool:
	var mask := piece(cell)
	return cell != source and (mask == NORTH or mask == EAST or mask == SOUTH or mask == WEST)


func rotate(cell: Vector2i) -> void:
	if cell.x < 0 or cell.y < 0 or cell.x >= width or cell.y >= height:
		return
	_pieces[cell.y * width + cell.x] = rotated(piece(cell), 1)


## Every cell joined to the source through matching openings.
func powered() -> Dictionary:
	var reached := {source: true}
	var queue: Array[Vector2i] = [source]
	while not queue.is_empty():
		var cell: Vector2i = queue.pop_back()
		for side in SIDES:
			if piece(cell) & side == 0:
				continue
			var next: Vector2i = cell + STEP[side]
			if next.x < 0 or next.y < 0 or next.x >= width or next.y >= height or reached.has(next):
				continue
			if piece(next) & int(OPPOSITE[side]) != 0:
				reached[next] = true
				queue.append(next)
	return reached


func is_solved() -> bool:
	return powered().size() == width * height


## Randomised depth-first walk: every cell joins the tree exactly once.
func _grow_tree(rng: RandomNumberGenerator) -> void:
	var visited := {source: true}
	var stack: Array[Vector2i] = [source]
	while not stack.is_empty():
		var cell: Vector2i = stack.back()
		var options: Array[int] = []
		for side in SIDES:
			var next: Vector2i = cell + STEP[side]
			if next.x >= 0 and next.y >= 0 and next.x < width and next.y < height and not visited.has(next):
				options.append(side)
		if options.is_empty():
			stack.pop_back()
			continue
		var side: int = options[rng.randi_range(0, options.size() - 1)]
		var next: Vector2i = cell + STEP[side]
		_pieces[cell.y * width + cell.x] |= side
		_pieces[next.y * width + next.x] |= int(OPPOSITE[side])
		visited[next] = true
		stack.append(next)
