class_name Note
extends Interactable
## Something written down: a letter, a log, a code scratched on a wall. Reading
## it remembers that you did (note_<id>_read), which is how a lock in another
## place knows you have its code.

const SPRITE_FORMAT := "res://assets/sprites/items/%s.png"

@export var note_id: String = ""
@export var title: String = "A note"
@export var lines: Array = []
@export var look: String = "note"


func _ready() -> void:
	super()
	var sprite := Sprite2D.new()
	sprite.name = "Sprite"
	sprite.texture = load(SPRITE_FORMAT % look)
	sprite.scale = Vector2(0.75, 0.75)
	add_child(sprite)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(14, 14)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	set_prompt("Read: %s" % title)
	interacted.connect(_on_interacted)


func read_flag() -> String:
	return "note_%s_read" % note_id


func _on_interacted(_by: Node) -> void:
	if not GameState.has_flag(read_flag()):
		GameState.set_flag(read_flag())
		GameState.add_to_counter("notes_read")
		EventBus.sfx_requested.emit("reveal")
	var typed: Array[String] = []
	typed.assign(lines)
	EventBus.text_requested.emit(typed)
