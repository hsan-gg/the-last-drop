class_name RepairRules
extends RefCounted
## Repairs consume recovered materials and set a story flag.


static func exists(repair_id: String) -> bool:
	return not Content.repair(repair_id).is_empty()


static func is_done(repair_id: String) -> bool:
	return GameState.has_flag(Content.repair(repair_id).get("sets_flag", ""))


## Item id -> how many more are needed. Empty when everything is in hand.
static func missing(repair_id: String) -> Dictionary:
	var shortfall := {}
	var requires: Dictionary = Content.repair(repair_id).get("requires", {})
	for item_id: String in requires:
		var needed := int(requires[item_id]) - Inventory.count(item_id)
		if needed > 0:
			shortfall[item_id] = needed
	return shortfall


static func can_repair(repair_id: String) -> bool:
	return exists(repair_id) and not is_done(repair_id) and missing(repair_id).is_empty()


## Consumes the materials and sets the flag. Returns false if it cannot be done.
static func perform(repair_id: String) -> bool:
	if not can_repair(repair_id):
		return false

	var repair := Content.repair(repair_id)
	var requires: Dictionary = repair.get("requires", {})
	for item_id: String in requires:
		Inventory.remove(item_id, int(requires[item_id]))
	GameState.set_flag(repair["sets_flag"])
	return true
