class_name Interactor
extends Area2D
## Sits on the player. Tracks nearby Interactables, highlights the nearest one,
## publishes its prompt, and triggers it on request.

var _nearby: Array[Interactable] = []
var _focused: Interactable


func _ready() -> void:
	collision_layer = 0
	collision_mask = Interactable.COLLISION_LAYER
	area_entered.connect(_on_area_entered)
	area_exited.connect(_on_area_exited)


func interact() -> void:
	if Modal.any_open(get_tree()):  # E belongs to the open panel
		return
	var target := _closest()
	if target != null:
		target.interact(self)


func _on_area_entered(area: Area2D) -> void:
	var interactable := area as Interactable
	if interactable == null:
		return
	_nearby.append(interactable)
	interactable.prompt_updated.connect(_publish_prompt)
	_publish_prompt()


func _on_area_exited(area: Area2D) -> void:
	var interactable := area as Interactable
	if interactable == null:
		return
	_nearby.erase(interactable)
	if interactable.prompt_updated.is_connected(_publish_prompt):
		interactable.prompt_updated.disconnect(_publish_prompt)
	_publish_prompt()


func _physics_process(_delta: float) -> void:
	# The nearest object can change as the player walks, without any area event.
	var target := _closest()
	if target != _focused:
		_update_focus(target)
		_publish_prompt()


func _closest() -> Interactable:
	var best: Interactable = null
	var best_distance := INF
	for candidate in _nearby:
		var distance := global_position.distance_squared_to(candidate.global_position)
		if distance < best_distance:
			best = candidate
			best_distance = distance
	return best


func _update_focus(target: Interactable) -> void:
	if is_instance_valid(_focused):
		_focused.set_focused(false)
	_focused = target
	if _focused != null:
		_focused.set_focused(true)


func _publish_prompt() -> void:
	var target := _closest()
	_update_focus(target)
	EventBus.prompt_changed.emit(target.prompt_text if target != null else "")
