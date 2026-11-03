class_name SortingSession
extends RefCounted
## One sitting at a scrap pile. A wrong bin teaches and costs health, then the
## same item comes up again. A right bin moves on.

var _queue: Array[String]
var _mistakes := 0
var _recovered: Array[String] = []


func _init(item_ids: Array[String]) -> void:
	_queue = item_ids.duplicate()


func current_item() -> String:
	return "" if _queue.is_empty() else _queue[0]


func remaining() -> int:
	return _queue.size()


func is_complete() -> bool:
	return _queue.is_empty()


func mistakes() -> int:
	return _mistakes


## Items placed in the recovery bin, ready to hand to the inventory.
func recovered_items() -> Array[String]:
	return _recovered.duplicate()


func place(bin_id: String) -> Dictionary:
	if is_complete():
		return {}

	var verdict := SortingRules.evaluate(current_item(), bin_id)
	if verdict["correct"]:
		if bin_id == SortingRules.BIN_RECOVERY:
			_recovered.append(current_item())
		_queue.remove_at(0)
	else:
		_mistakes += 1
	return verdict.merged({"complete": is_complete()})
