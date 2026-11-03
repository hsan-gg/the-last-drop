extends Node
## Watches flags and counters and announces side quests as they are completed.


func _ready() -> void:
	EventBus.flag_changed.connect(_check.unbind(2))
	EventBus.counter_changed.connect(_check.unbind(2))


func _check() -> void:
	for quest_id in QuestRules.complete_ready():
		EventBus.sfx_requested.emit("reveal")
		EventBus.quest_completed.emit(quest_id)
