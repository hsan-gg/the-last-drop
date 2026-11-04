class_name MemoryBoard
extends RefCounted
## Match the pairs: cards face down, turn two at a time; a pair that belongs
## together (a waste item and where it goes) stays face up.

enum Flip { IGNORED, FIRST, MATCH, MISS }

var cards: Array[Dictionary] = []  ## {"text", "pair", "up", "done"}
var _first := -1


func _init(pairs: Array, seed_value: int) -> void:
	for index in pairs.size():
		var pair: Array = pairs[index]
		cards.append({"text": str(pair[0]), "pair": index, "up": false, "done": false})
		cards.append({"text": str(pair[1]), "pair": index, "up": false, "done": false})
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for index in range(cards.size() - 1, 0, -1):
		var other := rng.randi_range(0, index)
		var held := cards[index]
		cards[index] = cards[other]
		cards[other] = held


## Turns a card. Returns what happened; after a MISS call `hide_misses`.
func flip(index: int) -> Flip:
	if index < 0 or index >= cards.size() or cards[index]["up"] or cards[index]["done"]:
		return Flip.IGNORED
	cards[index]["up"] = true
	if _first < 0:
		_first = index
		return Flip.FIRST
	var first := _first
	_first = -1
	if cards[first]["pair"] == cards[index]["pair"]:
		cards[first]["done"] = true
		cards[index]["done"] = true
		return Flip.MATCH
	return Flip.MISS


func hide_misses() -> void:
	for card in cards:
		if not card["done"]:
			card["up"] = false


func is_solved() -> bool:
	for card in cards:
		if not card["done"]:
			return false
	return true
