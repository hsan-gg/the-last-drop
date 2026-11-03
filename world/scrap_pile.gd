class_name ScrapPile
extends Interactable
## A heap of mixed waste. Interacting opens the sorting challenge; once the
## pile is sorted it is gone.

@export var pile_id: String = ""
@export var item_ids: Array[String] = []
## Variety: these items are always present, the rest are drawn from `pool` up to `count`.
@export var guaranteed: Array[String] = []
@export var pool: Array[String] = []
@export var count: int = 7
@export var min_hazardous: int = 1


func _ready() -> void:
	super()
	if GameState.has_flag(flag_name()):
		queue_free()
		return
	if not pool.is_empty():
		item_ids = PileBuilder.build(guaranteed, pool, count, min_hazardous, PileBuilder.seed_for(pile_id, GameState.run_seed))
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
