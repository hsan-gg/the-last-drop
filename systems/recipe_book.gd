class_name RecipeBook
extends RefCounted
## What the workbench can make (data/recipes.json): each recipe needs
## materials and makes an item (or several) or a piece of gear.

const PATH := "res://data/recipes.json"

static var _recipes: Array = []


static func all() -> Array:
	if _recipes.is_empty():
		var loaded: Variant = DataLoader.load_json(PATH)
		_recipes = loaded if typeof(loaded) == TYPE_ARRAY else []
	return _recipes


static func can_make(recipe: Dictionary) -> bool:
	var makes: Dictionary = recipe["makes"]
	if makes.has("gear") and Gear.is_owned(makes["gear"]):
		return false
	var needs: Dictionary = recipe["needs"]
	for item_id: String in needs:
		if not Inventory.has(item_id, int(needs[item_id])):
			return false
	return true


## Uses up the materials and hands over what it makes. False if it cannot.
static func make(recipe: Dictionary) -> bool:
	if not can_make(recipe):
		return false
	var needs: Dictionary = recipe["needs"]
	for item_id: String in needs:
		Inventory.remove(item_id, int(needs[item_id]))
	var makes: Dictionary = recipe["makes"]
	if makes.has("gear"):
		Gear.grant(makes["gear"])
	else:
		for _i in int(makes.get("count", 1)):
			Inventory.add(makes["item"])
	GameState.add_to_counter("items_crafted")
	return true


static func product_name(recipe: Dictionary) -> String:
	var makes: Dictionary = recipe["makes"]
	if makes.has("gear"):
		return Gear.definition(makes["gear"]).get("name", makes["gear"])
	var count := int(makes.get("count", 1))
	return ItemDB.display_name(makes["item"]) + (" x%d" % count if count > 1 else "")
