extends Node
## Watches flags and counters. Announces finished side quests, and pays a little
## XP the first time each main objective is completed.

const OBJECTIVE_XP := 15
const OBJECTIVE_XP_FLAG_FORMAT := "xp_objective_%s"


func _ready() -> void:
	EventBus.flag_changed.connect(_on_flag_changed)
	EventBus.counter_changed.connect(_check.unbind(2))
	EventBus.level_up.connect(_check.unbind(1))
	EventBus.gear_changed.connect(_check)


func _on_flag_changed(key: String, value: Variant) -> void:
	if value:
		_pay_objective_xp(key)
	_check()


func _pay_objective_xp(flag: String) -> void:
	for objective: Dictionary in Content.objectives():
		var paid_flag: String = OBJECTIVE_XP_FLAG_FORMAT % objective["id"]
		if objective.get("done_flag", "") == flag and not GameState.has_flag(paid_flag):
			GameState.set_flag(paid_flag)
			Progress.add_xp(OBJECTIVE_XP)
			EventBus.loot_found.emit("Objective done  +%d XP" % OBJECTIVE_XP)


func _check() -> void:
	for quest_id in QuestRules.complete_ready():
		EventBus.sfx_requested.emit("reveal")
		EventBus.quest_completed.emit(quest_id)
