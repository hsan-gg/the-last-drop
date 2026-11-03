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


## Zombies still alive in the region (the base count until the area has been loaded).
static func zombies_left(area: String) -> int:
	var spawned := GameState.get_counter("spawned_%s" % area)
	var total := spawned if spawned > 0 else Content.enemy_count(area)
	return maxi(total - GameState.count_flags_with_prefix("slain_%s_" % area), 0)


func _on_interacted(_by: Node) -> void:
	if is_lit():
		EventBus.text_requested.emit(["The lights are on. This place is safe now."] as Array[String])
		return
	var left := zombies_left(region_id)
	if left > 0:
		EventBus.text_requested.emit([
			"The generator coughs and dies. The area is not safe to light up yet.",
			"Defeat the remaining zombies first: %d left." % left,
		] as Array[String])
		return
	_start()


func _start() -> void:
	GameState.set_flag(lit_flag(region_id))
	EventBus.sfx_requested.emit("repair")
	EventBus.celebrate.emit(global_position)
	Progress.add_xp(REWARD_XP)
	Survival.heal(Survival.max_health())
	Survival.drink(Survival.MAX_VALUE * 0.5)
	EventBus.banner_requested.emit("REGION RESTORED", "The lights are back on. +%d XP, fully healed." % REWARD_XP, Color("#ffd27a"))
	EventBus.region_lit.emit(region_id)
	_refresh()


func _refresh() -> void:
	_sprite.texture = RUNNING if is_lit() else IDLE
	set_prompt("Generator: running" if is_lit() else "Start the generator")
