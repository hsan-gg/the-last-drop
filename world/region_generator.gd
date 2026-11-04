class_name RegionGenerator
extends Interactable
## The generator at the end of each region. Once every zombie in the region is
## defeated, starting it lights the whole place up: lamps come on, the gloom
## lifts, and the player is rewarded.

const IDLE := preload("res://assets/sprites/generator_broken.png")
const RUNNING := preload("res://assets/sprites/generator_fixed.png")
const REWARD_XP := 120

@export var region_id: String = ""

@onready var _sprite: Sprite2D = $Sprite


func _ready() -> void:
	super()
	interacted.connect(_on_interacted)
	EventBus.region_lit.connect(_refresh.unbind(1))
	_refresh()


func is_lit() -> bool:
	return GameState.has_flag(lit_flag(region_id))


static func lit_flag(area: String) -> String:
	return "region_lit_%s" % area


## Zombies still standing in the region right now.
func zombies_left() -> int:
	var alive := 0
	for node in get_tree().get_nodes_in_group("enemies"):
		var enemy := node as Enemy
		if enemy != null and not enemy.is_dead():
			alive += 1
	return alive


func _on_interacted(_by: Node) -> void:
	if is_lit():
		EventBus.text_requested.emit(["The lights are on. This place is safe now."] as Array[String])
		return
	var left := zombies_left()
	if left > 0:
		var area := get_tree().current_scene as GameArea
		if area != null:
			area.summon_remaining()
		EventBus.sfx_requested.emit("sort_bad")
		FloatingText.spawn(get_parent(), "%d zombie%s left!" % [left, "" if left == 1 else "s"], global_position + Vector2(0, -20), Color("#ff9a5a"))
		EventBus.banner_requested.emit("THE GENERATOR SPUTTERS", "Its noise draws the last %d zombie%s to you. Defeat them, then try again." % [left, "" if left == 1 else "s"], Color("#ff9a5a"))
		return
	_start()


func _start() -> void:
	GameState.set_flag(lit_flag(region_id))
	EventBus.sfx_requested.emit("generator_start")
	EventBus.celebrate.emit(global_position)
	Progress.add_xp(REWARD_XP)
	Survival.heal(Survival.max_health())
	Survival.drink(Survival.MAX_VALUE * 0.5)
	EventBus.reward_requested.emit("region", "REGION RESTORED", "The lights are back on. You are fully healed and rested.")
	EventBus.region_lit.emit(region_id)
	_refresh()


func _refresh() -> void:
	_sprite.texture = RUNNING if is_lit() else IDLE
	set_prompt("Generator: running" if is_lit() else "Start the generator")
