class_name SortingRules
extends RefCounted
## Which bin each kind of waste belongs in. Categories come from ItemDB.

const BIN_GENERAL := "general"
const BIN_HAZARDOUS := "hazardous"
const BIN_RECOVERY := "recovery"
const BIN_COMPOST := "compost"
## Bins every pile offers. The compost bin only appears when a pile holds organic waste.
const BINS: Array[String] = [BIN_GENERAL, BIN_HAZARDOUS, BIN_RECOVERY]

const _BIN_BY_CATEGORY := {
	"general": BIN_GENERAL,
	"hazardous": BIN_HAZARDOUS,
	"recyclable": BIN_RECOVERY,
	"reusable": BIN_RECOVERY,
	"organic": BIN_COMPOST,
}


## The bins to show for a pile: the standard three, plus compost when needed.
static func bins_for(item_ids: Array[String]) -> Array[String]:
	var bins: Array[String] = BINS.duplicate()
	for item_id in item_ids:
		if correct_bin(item_id) == BIN_COMPOST:
			bins.append(BIN_COMPOST)
			break
	return bins


static func correct_bin(item_id: String) -> String:
	var category: String = ItemDB.get_item(item_id).get("category", "")
	return _BIN_BY_CATEGORY.get(category, "")


static func evaluate(item_id: String, bin_id: String) -> Dictionary:
	var expected := correct_bin(item_id)
	return {
		"item_id": item_id,
		"bin_id": bin_id,
		"correct": expected != "" and expected == bin_id,
		"correct_bin": expected,
		"lesson_id": ItemDB.get_item(item_id).get("lesson_id", ""),
	}
