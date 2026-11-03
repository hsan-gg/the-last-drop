class_name Interactable
extends Area2D
## Anything the player can act on with the "interact" key.
## Extend this (see ItemPickup) or connect to `interacted` from a scene script.

signal interacted(by: Node)
signal prompt_updated

## Physics layer 2, reserved for interactables. The Interactor masks only this.
const COLLISION_LAYER := 1 << 1
const FOCUS_TINT := Color(1.35, 1.35, 1.35)

@export var prompt_text: String = "Interact"
## When non-zero the object is also solid, so the player walks around it.
@export var blocker_size: Vector2 = Vector2.ZERO
@export var blocker_offset: Vector2 = Vector2.ZERO


func _ready() -> void:
	collision_layer = COLLISION_LAYER
	collision_mask = 0
	if blocker_size != Vector2.ZERO:
		_add_blocker()


func interact(by: Node) -> void:
	interacted.emit(by)
	EventBus.interacted.emit(self)


## Brightens the sprite while the player is close enough to interact.
func set_focused(focused: bool) -> void:
	var sprite := get_node_or_null("Sprite") as CanvasItem
	if sprite != null:
		sprite.modulate = FOCUS_TINT if focused else Color.WHITE


func set_prompt(text: String) -> void:
	if text == prompt_text:
		return
	prompt_text = text
	prompt_updated.emit()


func _add_blocker() -> void:
	var shape := RectangleShape2D.new()
	shape.size = blocker_size
	var collision := CollisionShape2D.new()
	collision.shape = shape
	collision.position = blocker_offset
	var body := StaticBody2D.new()
	body.add_child(collision)
	add_child(body)
