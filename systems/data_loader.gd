class_name DataLoader
extends RefCounted
## Loads JSON content files. Malformed entries are reported and skipped, never
## silently dropped.


static func load_json(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("DataLoader: cannot open %s (error %d)" % [path, FileAccess.get_open_error()])
		return null

	var json := JSON.new()
	var error := json.parse(file.get_as_text())
	if error != OK:
		push_error("DataLoader: %s line %d: %s" % [path, json.get_error_line(), json.get_error_message()])
		return null
	return json.data


## Loads a JSON array of objects that each carry an "id", keyed by that id.
static func index_by_id(path: String) -> Dictionary:
	var parsed: Variant = load_json(path)
	if typeof(parsed) != TYPE_ARRAY:
		push_error("DataLoader: %s must contain a JSON array" % path)
		return {}

	var indexed := {}
	for entry: Variant in parsed:
		if typeof(entry) != TYPE_DICTIONARY or not entry.has("id"):
			push_error("DataLoader: skipping malformed entry in %s" % path)
			continue
		indexed[entry["id"]] = entry
	return indexed
