class_name ScrapPile
extends Interactable
## A heap of mixed waste. Interacting opens the sorting challenge; once the
## pile is sorted it is gone.

@export var pile_id: String = ""
@export var item_ids: Array[String] = []


func _ready() -> void:
	super()
	if GameState.has_flag(flag_name()):
		queue_free()
		return
	set_prompt("Sort the scrap pile")
	interacted.connect(_on_interacted)
	EventBus.sorting_finished.connect(_on_sorting_finished)


func flag_name() -> String:
	return "pile_sorted_%s" % pile_id


func _on_interacted(_by: Node) -> void:
	EventBus.sorting_requested.emit(pile_id, item_ids)


func _on_sorting_finished(finished_pile_id: String) -> void:
	if finished_pile_id == pile_id:
		queue_free()
