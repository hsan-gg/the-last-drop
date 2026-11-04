extends Node
## Saving and continuing a run. Everything that makes up a run (story flags and
## counters, inventory, gear, level, lives, runes, the explored map, the chosen
## difficulty and where you are) is written to user://save.json: when you enter
## a region, when a region's lights come on, and every minute while you play.
## The title screen offers CONTINUE when a save exists. On the web, user:// is
## kept in the browser's storage.

const PATH := "user://save.json"
const VERSION := 1
const AUTOSAVE_SECONDS := 60.0

var path := PATH
var _timer := 0.0


func _ready() -> void:
	EventBus.region_lit.connect(func(_area: String) -> void: save_now())
	EventBus.game_over.connect(delete)


func has_save() -> bool:
	return FileAccess.file_exists(path)


func delete() -> void:
	if has_save():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(path) if path.begins_with("user://") else path)


## The current run as plain data.
func snapshot() -> Dictionary:
	var map := {}
	for area_id: String in MapMemory._seen:
		var cells: Array = []
		for cell: Vector2i in MapMemory._seen[area_id]:
			cells.append([cell.x, cell.y])
		map[area_id] = cells
	return {
		"version": VERSION,
		"area": _current_area(),
		"difficulty": Difficulty.current_id,
		"flags": GameState._flags.duplicate(),
		"counters": GameState._counters.duplicate(),
		"run_seed": GameState.run_seed,
		"inventory": Inventory.snapshot(),
		"water": Survival.water(),
		"health": Survival.health(),
		"gear_owned": Gear._owned.keys(),
		"gear_equipped": Gear._equipped.duplicate(),
		"level": Progress.level,
		"xp": Progress.xp,
		"lives": Lives.lives,
		"max_lives": Lives.max_lives,
		"map": map,
		"runes": Runes.owned.duplicate(),
		"energy": Runes.energy,
		"loaded_shells": Runes.loaded_shells,
	}


## Puts a saved run back in place (does not change scene).
func restore(data: Dictionary) -> void:
	Difficulty.current_id = String(data.get("difficulty", Difficulty.DEFAULT_ID))
	GameState._flags = data.get("flags", {}).duplicate()
	GameState._counters = {}
	var counters: Dictionary = data.get("counters", {})
	for key: String in counters:
		GameState._counters[key] = int(counters[key])
	GameState.run_seed = int(data.get("run_seed", 0))
	Inventory.clear()
	var inventory: Dictionary = data.get("inventory", {})
	for item_id: String in inventory:
		Inventory.add(item_id, int(inventory[item_id]))
	Progress.level = int(data.get("level", 1))
	Progress.xp = int(data.get("xp", 0))
	Survival.set_max_health(Progress.max_health())
	Survival._apply(float(data.get("water", Survival.MAX_VALUE)), float(data.get("health", Survival.max_health())))
	Gear.reset()
	for gear_id: String in data.get("gear_owned", []):
		Gear._owned[gear_id] = true
	var equipped: Dictionary = data.get("gear_equipped", {})
	for slot: String in equipped:
		Gear._equipped[slot] = String(equipped[slot])
	EventBus.gear_changed.emit()
	Lives.max_lives = int(data.get("max_lives", Lives.DEFAULT_LIVES))
	Lives.lives = int(data.get("lives", Lives.max_lives))
	Lives.active = true
	EventBus.lives_changed.emit(Lives.lives)
	MapMemory.reset()
	var map: Dictionary = data.get("map", {})
	for area_id: String in map:
		var cells := {}
		for pair: Array in map[area_id]:
			cells[Vector2i(int(pair[0]), int(pair[1]))] = true
		MapMemory._seen[area_id] = cells
	Runes.owned.clear()
	for rune_id: String in data.get("runes", []):
		Runes.owned.append(rune_id)
	Runes.energy = float(data.get("energy", Runes.MAX_ENERGY))
	Runes.loaded_shells = int(data.get("loaded_shells", Runes.MAGAZINE if Runes.has(Runes.SCATTER) else 0))
	EventBus.runes_changed.emit()
	EventBus.xp_changed.emit(Progress.level, Progress.xp, Progress.xp_needed())


func save_now() -> bool:
	if not Lives.active or _current_area().is_empty():
		return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("SaveGame: cannot write %s (error %d)" % [path, FileAccess.get_open_error()])
		return false
	file.store_string(JSON.stringify(snapshot()))
	file.close()  # closing is what flushes it to the browser's storage on the web
	return true


func read() -> Dictionary:
	if not has_save():
		return {}
	var json := JSON.new()
	if json.parse(FileAccess.get_file_as_string(path)) != OK:
		push_warning("SaveGame: the save is damaged; starting fresh")
		return {}
	var parsed: Variant = json.data
	if typeof(parsed) != TYPE_DICTIONARY or int(parsed.get("version", 0)) != VERSION:
		push_warning("SaveGame: the save could not be read; starting fresh")
		return {}
	return parsed


func _current_area() -> String:
	var scene := get_tree().current_scene
	return (scene as GameArea).area_id if scene is GameArea else ""


func _process(delta: float) -> void:
	if not Lives.active:
		return
	_timer += delta
	if _timer >= AUTOSAVE_SECONDS:
		_timer = 0.0
		save_now()
