class_name PuzzleStation
extends Interactable
## Something hands-on to work at: a fuse box, a wall safe, a radio, a valve
## panel, a notice board, a sorting line. It opens its puzzle (any type in
## data/puzzles.json); solving it pays out once and can unlock a story flag.

const SPRITE_FORMAT := "res://assets/sprites/stations/%s.png"

@export var puzzle_id: String = ""
@export var look: String = "fusebox"
@export var prompt: String = "Take a look"
@export var done_prompt: String = "Done"
@export var done_lines: Array = []
## Paid once when solved: {"items": {id: n}, "gear": [ids], "xp": n, "flag": "...", "rune": "..."}.
@export var reward: Dictionary = {}
@export var required_flag: String = ""
@export var locked_lines: Array = []

var _sprite: Sprite2D


func _ready() -> void:
	super()
	_sprite = Sprite2D.new()
	_sprite.name = "Sprite"
	_sprite.texture = load(SPRITE_FORMAT % look)
	if _sprite.texture != null:
		_sprite.position = Vector2(0, MapBuilder.TILE_SIZE / 2.0 - _sprite.texture.get_height() / 2.0)
	add_child(_sprite)
	var shape := RectangleShape2D.new()
	shape.size = Vector2(16, 16)
	var collider := CollisionShape2D.new()
	collider.shape = shape
	add_child(collider)
	blocker_size = Vector2(12, 8)
	blocker_offset = Vector2(0, 4)
	_add_blocker()
	interacted.connect(_on_interacted)
	EventBus.puzzle_finished.connect(_on_puzzle_finished)
	_refresh()


func is_solved() -> bool:
	return GameState.has_flag(MiniGame.SOLVED_FLAG_FORMAT % puzzle_id)


func _on_interacted(_by: Node) -> void:
	if not required_flag.is_empty() and not GameState.has_flag(required_flag):
		_say(locked_lines if not locked_lines.is_empty() else ["It is dead. Nothing happens."])
		return
	if is_solved():
		_say(done_lines if not done_lines.is_empty() else ["It is working now."])
		return
	EventBus.puzzle_requested.emit(puzzle_id)


func _on_puzzle_finished(finished_id: String, solved: bool) -> void:
	if not solved or finished_id != puzzle_id:
		return
	_pay_out()
	_refresh()


func _pay_out() -> void:
	var paid_flag := "station_paid_%s" % puzzle_id
	if GameState.has_flag(paid_flag):
		return
	GameState.set_flag(paid_flag)
	var found: Array[String] = []
	var items: Dictionary = reward.get("items", {})
	for item_id: String in items:
		for _i in int(items[item_id]):
			Inventory.add(item_id)
		found.append("%s x%d" % [ItemDB.display_name(item_id), int(items[item_id])])
	for gear_id: String in reward.get("gear", []):
		if Gear.grant(gear_id):
			found.append(Gear.definition(gear_id)["name"])
	if reward.has("rune"):
		Runes.grant(reward["rune"])
	if reward.has("flag"):
		GameState.set_flag(reward["flag"])
	if int(reward.get("xp", 0)) > 0:
		Progress.add_xp(int(reward["xp"]))
	if not found.is_empty():
		EventBus.loot_found.emit("Inside: %s" % ", ".join(found))
	if not done_lines.is_empty():
		_say(done_lines)


func _say(lines: Array) -> void:
	var typed: Array[String] = []
	typed.assign(lines)
	EventBus.text_requested.emit(typed)


func _refresh() -> void:
	set_prompt(done_prompt if is_solved() else prompt)
