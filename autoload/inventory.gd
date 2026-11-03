extends Node
## Player inventory: item id -> count. Only items known to ItemDB can be added.

var _counts: Dictionary = {}


func add(item_id: String, amount: int = 1) -> bool:
	if amount <= 0 or not ItemDB.has_item(item_id):
		push_warning("Inventory.add rejected '%s' x%d" % [item_id, amount])
		return false
	_counts = _counts.merged({item_id: count(item_id) + amount}, true)
	EventBus.inventory_changed.emit()
	return true


func remove(item_id: String, amount: int = 1) -> bool:
	if amount <= 0 or count(item_id) < amount:
		return false
	var remaining := count(item_id) - amount
	var next := _counts.duplicate()
	if remaining == 0:
		next.erase(item_id)
	else:
		next[item_id] = remaining
	_counts = next
	EventBus.inventory_changed.emit()
	return true


func count(item_id: String) -> int:
	return _counts.get(item_id, 0)


func has(item_id: String, amount: int = 1) -> bool:
	return count(item_id) >= amount


func snapshot() -> Dictionary:
	return _counts.duplicate()


func clear() -> void:
	_counts = {}
	EventBus.inventory_changed.emit()
