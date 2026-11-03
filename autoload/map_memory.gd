extends Node
## What the player has seen of each area, for the map's fog of war. Cells near
## the player are revealed as they walk; nothing is forgotten within a run.

const REVEAL_RADIUS := 7

var _seen: Dictionary = {}


## Marks every cell within the reveal radius of `cell` as seen.
func reveal(area_id: String, cell: Vector2i, radius: int = REVEAL_RADIUS) -> void:
	var cells: Dictionary = _seen.get(area_id, {})
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy <= radius * radius:
				cells[Vector2i(cell.x + dx, cell.y + dy)] = true
	_seen[area_id] = cells


func is_seen(area_id: String, cell: Vector2i) -> bool:
	return _seen.get(area_id, {}).has(cell)


func has_visited(area_id: String) -> bool:
	return _seen.has(area_id)


## The share of an area's cells seen so far, 0 to 1.
func fraction_seen(area_id: String, total_cells: int) -> float:
	if total_cells <= 0:
		return 0.0
	var count := 0
	for cell: Vector2i in _seen.get(area_id, {}):
		count += 1
	return minf(float(count) / float(total_cells), 1.0)


func reset() -> void:
	_seen = {}
