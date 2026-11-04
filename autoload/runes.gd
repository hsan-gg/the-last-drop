extends Node
## Runes: old maintenance tools the survivors turned into weapons. Each one you
## own sits in a slot (keys 1, 2, 3) and runs on energy, which refills over time
## and with every kill. The abilities themselves live in player/rune_caster.gd;
## this keeps what you own and how much energy you have.

const MAX_ENERGY := 100.0
const REGEN_PER_SECOND := 7.0
const ENERGY_PER_KILL := 12.0
const DEFINITIONS := {
	"ember": {"name": "Ember Rune", "ability": "Flamethrower", "color": "#ff8a3a", "cost": 26.0, "hint": "Hold to breathe fire. The Spoiled burn, and fire spreads between them."},
	"scatter": {"name": "Scatter Rune", "ability": "Shotgun", "color": "#e0d070", "cost": 0.0, "hint": "Two shells, then it reloads from the shells you carry. Shells are rare: look in chests and on the Spoiled."},
	"tide": {"name": "Tide Rune", "ability": "Tide Wave", "color": "#6ad0e8", "cost": 40.0, "hint": "A wave of clean water: heals you and pushes everything away."},
}
const ORDER: Array[String] = ["ember", "scatter", "tide"]
## The shotgun runs on shells, not energy: two in the gun, then a reload from
## the shells you carry. Shells are rare, so every blast counts.
const SCATTER := "scatter"
const SHELL_ITEM := "shotgun_shell"
const MAGAZINE := 2
const RELOAD_SECONDS := 1.1
const STARTING_SPARE_SHELLS := 2

var owned: Array[String] = []
var energy := MAX_ENERGY
var loaded_shells := 0
var _reload_left := 0.0


func _ready() -> void:
	EventBus.enemy_killed.connect(func(_id: String) -> void: add_energy(ENERGY_PER_KILL))
	EventBus.inventory_changed.connect(_on_inventory_changed)


func reset() -> void:
	owned.clear()
	energy = MAX_ENERGY
	loaded_shells = 0
	_reload_left = 0.0
	EventBus.runes_changed.emit()


func has(rune_id: String) -> bool:
	return owned.has(rune_id)


## The rune in slot 1, 2 or 3 (in the order they were found), or "".
func in_slot(slot: int) -> String:
	return owned[slot - 1] if slot >= 1 and slot <= owned.size() else ""


func grant(rune_id: String) -> bool:
	if not DEFINITIONS.has(rune_id) or owned.has(rune_id):
		return false
	owned.append(rune_id)
	energy = MAX_ENERGY
	if rune_id == SCATTER:
		loaded_shells = MAGAZINE
		Inventory.add(SHELL_ITEM, STARTING_SPARE_SHELLS)
	var definition: Dictionary = DEFINITIONS[rune_id]
	EventBus.reward_requested.emit("region", definition["name"].to_upper(), "%s in slot %d. %s" % [definition["ability"], owned.size(), definition["hint"]])
	EventBus.runes_changed.emit()
	return true


func can_afford(cost: float) -> bool:
	return energy >= cost


func spend(cost: float) -> bool:
	if energy < cost:
		EventBus.stamina_denied.emit()
		return false
	energy -= cost
	EventBus.energy_changed.emit(energy, MAX_ENERGY)
	return true


func add_energy(amount: float) -> void:
	energy = minf(energy + amount, MAX_ENERGY)
	EventBus.energy_changed.emit(energy, MAX_ENERGY)


func _process(delta: float) -> void:
	if not owned.is_empty() and energy < MAX_ENERGY and Lives.active:
		add_energy(REGEN_PER_SECOND * delta)
	if _reload_left > 0.0:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_finish_reload()


# ------------------------------------------------------------------ shotgun shells

func spare_shells() -> int:
	return Inventory.count(SHELL_ITEM)


func is_reloading() -> bool:
	return _reload_left > 0.0


## 0 just started reloading, 1 done.
func reload_progress() -> float:
	return 1.0 - clampf(_reload_left / RELOAD_SECONDS, 0.0, 1.0) if is_reloading() else 1.0


## Spends a loaded shell for one blast; an emptied gun starts reloading.
func take_shell() -> bool:
	if is_reloading() or loaded_shells <= 0:
		return false
	loaded_shells -= 1
	EventBus.runes_changed.emit()
	if loaded_shells == 0:
		start_reload()
	return true


## Starts reloading if there is room in the gun and a shell to put in it.
func start_reload() -> bool:
	if is_reloading() or loaded_shells >= MAGAZINE or spare_shells() <= 0 or not has(SCATTER):
		return false
	_reload_left = RELOAD_SECONDS
	EventBus.sfx_requested.emit("reload")
	EventBus.runes_changed.emit()
	return true


func _finish_reload() -> void:
	_reload_left = 0.0
	var taken := mini(MAGAZINE - loaded_shells, spare_shells())
	if taken > 0 and Inventory.remove(SHELL_ITEM, taken):
		loaded_shells += taken
		EventBus.sfx_requested.emit("shell_in")
	EventBus.runes_changed.emit()


## Finding shells with an empty gun loads it straight away.
func _on_inventory_changed() -> void:
	if loaded_shells == 0 and has(SCATTER):
		start_reload()
