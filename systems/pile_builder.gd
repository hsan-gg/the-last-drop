class_name PileBuilder
extends RefCounted
## Builds the contents of a scrap pile: the items a repair needs are always in
## it, the rest is drawn at random from a pool so no two runs sort the same
## rubbish. The draw is seeded, so a pile keeps its contents within a run.


static func build(guaranteed: Array[String], pool: Array[String], count: int, min_hazardous: int, seed_value: int) -> Array[String]:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var items: Array[String] = guaranteed.duplicate()
	var candidates: Array[String] = pool.duplicate()
	_shuffle(candidates, rng)
	var hazards := _count_hazardous(items)
	# First make sure enough hazardous items are in, so there is always something to handle with care.
	for candidate in candidates.duplicate():
		if hazards >= min_hazardous or items.size() >= count:
			break
		if ItemDB.is_hazardous(candidate):
			items.append(candidate)
			candidates.erase(candidate)
			hazards += 1
	for candidate in candidates:
		if items.size() >= count:
			break
		items.append(candidate)
	_shuffle(items, rng)
	return items


static func seed_for(pile_id: String, run_seed: int) -> int:
	return hash(pile_id) ^ run_seed


static func _count_hazardous(items: Array[String]) -> int:
	var total := 0
	for item_id in items:
		if ItemDB.is_hazardous(item_id):
			total += 1
	return total


static func _shuffle(list: Array[String], rng: RandomNumberGenerator) -> void:
	for index in range(list.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var swap := list[index]
		list[index] = list[other]
		list[other] = swap
