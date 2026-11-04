class_name Consumables
extends RefCounted
## Using up a bandage, a flask of water or an energy bar. The effects come from
## the item's `use` entry in data/items.json.

## The consumable to reach for first when healing, and when drinking.
const HEAL_ORDER: Array[String] = ["bandage", "energy_bar"]
const DRINK_ORDER: Array[String] = ["purified_water", "energy_bar"]


static func use(item_id: String) -> bool:
	var item := ItemDB.get_item(item_id)
	if item.get("category", "") != "consumable" or not Inventory.has(item_id):
		return false
	var effect: Dictionary = item.get("use", {})
	if effect.get("heal", 0) > 0 and Survival.health() >= Survival.max_health() and effect.get("water", 0) <= 0:
		return false
	if effect.get("water", 0) > 0 and Survival.water() >= Survival.MAX_VALUE and effect.get("heal", 0) <= 0:
		return false
	Inventory.remove(item_id, 1)
	Survival.heal(float(effect.get("heal", 0)))
	Survival.drink(float(effect.get("water", 0)))
	if effect.get("energy", 0) > 0:
		Runes.add_energy(float(effect["energy"]))
	EventBus.sfx_requested.emit("drink")
	EventBus.loot_found.emit("Used: %s" % item["name"])
	return true


## Uses the first consumable from `order` the player has and can benefit from.
static func use_first(order: Array[String]) -> bool:
	for item_id in order:
		if use(item_id):
			return true
	return false
