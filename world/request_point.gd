class_name RequestPoint
extends Interactable
## Something in one area that needs a part found in another (data/requests.json):
## a dead radio mast, a bare garden bed, a dry fountain. Bring the part and it
## comes back to life and pays you; without it, it tells you where to look.

const SPRITE_FORMAT := "res://assets/sprites/%s.png"

@export var request_id: String = ""

@onready var _sprite: Sprite2D = $Sprite
var _request: Dictionary = {}


func _ready() -> void:
	super()
	_request = Content.request(request_id)
	interacted.connect(_on_interacted)
	_refresh()


func is_done() -> bool:
	return GameState.has_flag(done_flag(request_id))


static func done_flag(id: String) -> String:
	return "request_done_%s" % id


func _on_interacted(_by: Node) -> void:
	if _request.is_empty():
		return
	if is_done():
		EventBus.text_requested.emit([_request["after"][0]] as Array[String])
		return
	var needed: String = _request["needs"]
	if Inventory.count(needed) <= 0:
		var lines: Array[String] = []
		lines.assign(_request["before"])
		EventBus.text_requested.emit(lines)
		return
	Inventory.remove(needed, 1)
	GameState.set_flag(done_flag(request_id))
	_pay(_request.get("reward", {}))
	EventBus.sfx_requested.emit("repair")
	EventBus.celebrate.emit(global_position)
	var after: Array[String] = []
	after.assign(_request["after"])
	EventBus.text_requested.emit(after)
	_refresh()


func _pay(reward: Dictionary) -> void:
	Progress.add_xp(int(reward.get("xp", 0)))
	var items: Dictionary = reward.get("items", {})
	for item_id: String in items:
		for _count in int(items[item_id]):
			Inventory.add(item_id)
		EventBus.loot_found.emit("%s x%d" % [ItemDB.display_name(item_id), int(items[item_id])])
	var gear_id: String = reward.get("gear", "")
	if not gear_id.is_empty() and Gear.grant(gear_id):
		EventBus.loot_found.emit("Found: %s" % Gear.definition(gear_id)["name"])


func _refresh() -> void:
	if _request.is_empty():
		return
	var state := "_done" if is_done() else ""
	var path := SPRITE_FORMAT % (String(_request["sprite"]) + state)
	if not ResourceLoader.exists(path):
		path = SPRITE_FORMAT % _request["sprite"]
	if ResourceLoader.exists(path):
		_sprite.texture = load(path)
	set_prompt(("Look at the " if is_done() else "") + (_request["prompt"] if not is_done() else String(_request["sprite"]).trim_prefix("request_")))
