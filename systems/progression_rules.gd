class_name ProgressionRules
extends RefCounted
## XP, levels and the stats a level gives. Tuned so the whole game (kills,
## objectives and quests) takes a player to about level 10.

const MAX_LEVEL := 10
const BASE_HEALTH := 100.0
const HEALTH_PER_LEVEL := 8.0
const DAMAGE_PER_LEVEL := 1
const XP_BASE := 120
const XP_STEP := 60
const XP_CURVE := 15


## XP needed to go from `level` to the next one. It grows faster than linearly,
## so the first levels come at a steady pace and the last ones are earned:
## 120, 195, 300, 435, 600, 795, 1020, 1275, 1560 (6300 to reach level 10).
static func xp_needed(level: int) -> int:
	var steps := level - 1
	return XP_BASE + XP_STEP * steps + XP_CURVE * steps * steps


## Adds XP and levels up as far as it reaches: {"level", "xp", "levels_gained"}.
static func apply_xp(level: int, xp: int, amount: int) -> Dictionary:
	var gained := 0
	var total := xp + maxi(amount, 0)
	var current := level
	while current < MAX_LEVEL and total >= xp_needed(current):
		total -= xp_needed(current)
		current += 1
		gained += 1
	if current >= MAX_LEVEL:
		total = 0
	return {"level": current, "xp": total, "levels_gained": gained}


static func max_health(level: int) -> float:
	return BASE_HEALTH + HEALTH_PER_LEVEL * (level - 1)


static func damage_bonus(level: int) -> int:
	return DAMAGE_PER_LEVEL * (level - 1)
