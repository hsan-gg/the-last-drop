class_name QuestRules
extends RefCounted
## Side quests: progress comes from GameState counters and flags, so a quest is
## data, not code. Completing one sets its flag once and pays out a reward.

const DONE_FLAG_FORMAT := "quest_%s_done"
const DIFFICULTY_ORDER := {"easy": 0, "medium": 1, "hard": 2}
const DIFFICULTY_COLORS := {"easy": "#7bc043", "medium": "#f2c94c", "hard": "#e0584a"}
const DIFFICULTY_TAGS := {"easy": "EASY", "medium": "MED", "hard": "HARD"}


static func is_done(quest_id: String) -> bool:
	return GameState.has_flag(DONE_FLAG_FORMAT % quest_id)


## {"current", "target", "complete"} for a quest definition.
static func progress(quest: Dictionary) -> Dictionary:
	var goal: Dictionary = quest.get("goal", {})
	var current := 0
	var target := 1
	match goal.get("type", ""):
		"counter":
			current = GameState.get_counter(goal["key"])
			target = int(goal["target"])
		"clear":
			current = GameState.count_flags_with_prefix("slain_%s_" % goal["area"])
			target = maxi(Content.enemy_count(goal["area"]), 1)
		"level":
			current = Progress.level
			target = int(goal["target"])
		"flags":
			var keys: Array = goal["keys"]
			target = keys.size()
			for key: String in keys:
				if GameState.has_flag(key):
					current += 1
	return {"current": mini(current, target), "target": target, "complete": current >= target}


## Quests easiest first, then hardest XP last within a difficulty.
static func sorted_by_difficulty(quests: Array) -> Array[Dictionary]:
	var sorted_quests: Array[Dictionary] = []
	sorted_quests.assign(quests)
	sorted_quests.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var rank_a: int = DIFFICULTY_ORDER.get(a.get("difficulty", "easy"), 0)
		var rank_b: int = DIFFICULTY_ORDER.get(b.get("difficulty", "easy"), 0)
		if rank_a != rank_b:
			return rank_a < rank_b
		return int(a.get("reward", {}).get("xp", 0)) < int(b.get("reward", {}).get("xp", 0)))
	return sorted_quests


## Quests visible to the player: those whose area has been reached.
static func visible_quests() -> Array[Dictionary]:
	var found: Array[Dictionary] = []
	for quest: Dictionary in Content.quests():
		if GameState.has_flag("area_%s_reached" % quest["area"]):
			found.append(quest)
	return found


## Marks every newly finished quest done, pays its reward, and returns their ids.
static func complete_ready() -> Array[String]:
	var finished: Array[String] = []
	for quest: Dictionary in Content.quests():
		if is_done(quest["id"]) or not progress(quest)["complete"]:
			continue
		GameState.set_flag(DONE_FLAG_FORMAT % quest["id"])
		_pay(quest.get("reward", {}))
		finished.append(quest["id"])
	return finished


static func _pay(reward: Dictionary) -> void:
	if reward.get("xp", 0) > 0:
		Progress.add_xp(int(reward["xp"]))
	if reward.has("gear") and Gear.grant(reward["gear"]):
		EventBus.loot_found.emit("Reward: %s" % Gear.definition(reward["gear"])["name"])
	if reward.get("water", 0) > 0:
		Survival.drink(float(reward["water"]))
	if reward.get("health", 0) > 0:
		Survival.heal(float(reward["health"]))
