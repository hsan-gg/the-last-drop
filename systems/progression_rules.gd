class_name ProgressionRules
extends RefCounted
## XP, levels and the stats a level gives. Tuned so the whole game (kills,
## objectives and quests) takes a player to about level 10.

const MAX_LEVEL := 10
const BASE_HEALTH := 100.0
const HEALTH_PER_LEVEL := 8.0
const DAMAGE_PER_LEVEL := 1
const XP_BASE := 60
const XP_STEP := 30


## XP needed to go from `level` to the next one.
static func xp_needed(level: int) -> int:
	return XP_BASE + XP_STEP * (level - 1)


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
