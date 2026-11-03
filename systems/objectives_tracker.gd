class_name ObjectivesTracker
extends RefCounted
## The player's next goal, derived from story flags.


## First unfinished objective for an area, or {} when the area is complete.
static func current(area: String) -> Dictionary:
	for objective: Dictionary in Content.objectives():
		if objective.get("area", "") == area and not GameState.has_flag(objective.get("done_flag", "")):
			return objective
	return {}
