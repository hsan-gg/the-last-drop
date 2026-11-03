extends Node
## Weapons and armor the player owns and wears. Definitions live in
## data/gear.json; this tracks ownership and what is equipped.

const SLOTS: Array[String] = ["weapon", "head", "body"]
const FISTS := "fists"

var _owned: Dictionary = {FISTS: true}
var _equipped: Dictionary = {"weapon": FISTS, "head": "", "body": ""}


func definition(gear_id: String) -> Dictionary:
	return Content.gear_item(gear_id)


func is_owned(gear_id: String) -> bool:
	return _owned.has(gear_id)


func owned_in_slot(slot: String) -> Array[String]:
	var found: Array[String] = []
	for gear_id: String in _owned:
		if definition(gear_id).get("slot", "") == slot:
			found.append(gear_id)
	return found


func equipped(slot: String) -> String:
	return _equipped.get(slot, "")


## Adds a piece of gear. Wears it at once if the slot is empty or it is stronger.
func grant(gear_id: String) -> bool:
	var item := definition(gear_id)
	if item.is_empty() or is_owned(gear_id):
		return false
	_owned[gear_id] = true
	var slot: String = item["slot"]
	if equipped(slot).is_empty() or _power(item) > _power(definition(equipped(slot))):
		_equipped[slot] = gear_id
	GameState.add_to_counter("gear_found")
	EventBus.gear_changed.emit()
	return true


func equip(gear_id: String) -> bool:
	var item := definition(gear_id)
	if item.is_empty() or not is_owned(gear_id):
		return false
	_equipped[item["slot"]] = gear_id
	EventBus.gear_changed.emit()
	return true


func weapon_damage() -> int:
	return int(definition(equipped("weapon")).get("damage", 0))


func armor() -> int:
	var total := 0
	for slot in ["head", "body"]:
		total += int(definition(equipped(slot)).get("armor", 0))
	return total


func weapon_color() -> Color:
	return Color(definition(equipped("weapon")).get("color", "#c8c8d4"))


func reset() -> void:
	_owned = {FISTS: true}
	_equipped = {"weapon": FISTS, "head": "", "body": ""}
	EventBus.gear_changed.emit()


func _power(item: Dictionary) -> int:
	return int(item.get("damage", 0)) + int(item.get("armor", 0))
