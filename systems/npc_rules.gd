class_name NpcRules
extends RefCounted
## The rules of a conversation, apart from the person: when a talk can happen
## and what it changes.
##
## A talk (in data/npcs.json) may have:
##   "flags": [...]        story flags that must all be set
##   "not_flags": [...]    flags that must not be set
##   "items": {id: n}      items you must carry (taken if "take" is true)
##   "counters": {k: n}    counters that must reach at least n
##   "gives": {"items": {id: n}, "gear": id, "rune": id, "xp": n}
##   "sets": flag          set when the talk is done (besides its own done flag)
##   "repeat": true        chatter, said again and again, never "done"


static func done_flag(npc_id: String, talk: Dictionary) -> String:
	return "talked_%s_%s" % [npc_id, talk.get("id", "talk")]


static func conditions_met(talk: Dictionary) -> bool:
	for flag: String in talk.get("flags", []):
		if not GameState.has_flag(flag):
			return false
	for flag: String in talk.get("not_flags", []):
		if GameState.has_flag(flag):
			return false
	var items: Dictionary = talk.get("items", {})
	for item_id: String in items:
		if Inventory.count(item_id) < int(items[item_id]):
			return false
	var counters: Dictionary = talk.get("counters", {})
	for key: String in counters:
		if GameState.get_counter(key) < int(counters[key]):
			return false
	return true


## Marks the talk done, takes what it asks for and pays what it gives.
static func apply(npc_id: String, talk: Dictionary) -> void:
	GameState.set_flag(done_flag(npc_id, talk))
	if talk.has("sets"):
		GameState.set_flag(talk["sets"])
	if talk.get("take", false):
		var items: Dictionary = talk.get("items", {})
		for item_id: String in items:
			Inventory.remove(item_id, int(items[item_id]))
	var gives: Dictionary = talk.get("gives", {})
	var gifts: Dictionary = gives.get("items", {})
	for item_id: String in gifts:
		for _count in int(gifts[item_id]):
			Inventory.add(item_id)
		EventBus.loot_found.emit("%s x%d" % [ItemDB.display_name(item_id), int(gifts[item_id])])
	var gear_id: String = gives.get("gear", "")
	if not gear_id.is_empty() and Gear.grant(gear_id):
		EventBus.loot_found.emit("Found: %s" % Gear.definition(gear_id)["name"])
	var rune_id: String = gives.get("rune", "")
	if not rune_id.is_empty():
		Runes.grant(rune_id)
	if int(gives.get("xp", 0)) > 0:
		Progress.add_xp(int(gives["xp"]))
