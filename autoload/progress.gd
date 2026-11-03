extends Node
## The player's level and XP. Levelling raises max health, heals fully and
## announces itself; the rules live in ProgressionRules.

var level := 1
var xp := 0


func xp_needed() -> int:
	return ProgressionRules.xp_needed(level)


func max_health() -> float:
	return ProgressionRules.max_health(level)


func add_xp(amount: int) -> void:
	if amount <= 0:
		return
	var result := ProgressionRules.apply_xp(level, xp, maxi(roundi(amount * Difficulty.value("xp")), 1))
	level = result["level"]
	xp = result["xp"]
	if result["levels_gained"] > 0:
		Survival.set_max_health(max_health())
		Survival.heal(Survival.max_health())
		EventBus.sfx_requested.emit("reveal")
		EventBus.level_up.emit(level)
	EventBus.xp_changed.emit(level, xp, xp_needed())


func reset() -> void:
	level = 1
	xp = 0
	Survival.set_max_health(max_health())
	EventBus.xp_changed.emit(level, xp, xp_needed())
