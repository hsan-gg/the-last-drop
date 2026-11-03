extends Node
## Read-only item catalogue loaded from data/items.json.
## Hazard and category data lives in JSON so content can change without code.

const ITEMS_PATH := "res://data/items.json"
const ICON_PATH_FORMAT := "res://assets/sprites/items/%s.png"

var _items: Dictionary = {}


func _ready() -> void:
	_items = DataLoader.index_by_id(ITEMS_PATH)


func has_item(item_id: String) -> bool:
	return _items.has(item_id)


func get_item(item_id: String) -> Dictionary:
	return _items.get(item_id, {}).duplicate()


func display_name(item_id: String) -> String:
	return _items.get(item_id, {}).get("name", item_id)


func is_hazardous(item_id: String) -> bool:
	return _items.get(item_id, {}).get("category", "") == "hazardous"


func icon(item_id: String) -> Texture2D:
	var path := ICON_PATH_FORMAT % item_id
	return load(path) if ResourceLoader.exists(path) else null
