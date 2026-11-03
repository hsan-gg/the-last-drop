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
	"scatter": {"name": "Scatter Rune", "ability": "Shotgun", "color": "#e0d070", "cost": 24.0, "hint": "A spread of pellets that blows the Spoiled back."},
	"tide": {"name": "Tide Rune", "ability": "Tide Wave", "color": "#6ad0e8", "cost": 40.0, "hint": "A wave of clean water: heals you and pushes everything away."},
}
const ORDER: Array[String] = ["ember", "scatter", "tide"]

var owned: Array[String] = []
var energy := MAX_ENERGY


func _ready() -> void:
	EventBus.enemy_killed.connect(func(_id: String) -> void: add_energy(ENERGY_PER_KILL))


func reset() -> void:
	owned.clear()
	energy = MAX_ENERGY
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
