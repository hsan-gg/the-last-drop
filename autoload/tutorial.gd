extends Node
## Short tips that teach the basics the first time they matter: moving,
## interacting, the inventory, attacking, blocking, stamina and the rest. Each
## shows once (remembered between runs) and can be switched off in Options.

const TIPS := {
	"move": "Move with {move_up} {move_left} {move_down} {move_right}.",
	"interact": "Press {interact} to interact with what you walk up to.",
	"inventory": "Press {equipment} to open your inventory and equip gear.",
	"attack": "Press {attack} to swing your sword.",
	"block": "Hold {block} to guard. Raise it just as a zombie strikes to parry it!",
	"stamina": "Swinging and guarding use stamina (the yellow bar). Let it recover.",
	"tracker": "Press {tracker} to see your tasks.",
	"menu": "Press Esc for the menu: inventory, quests, map and options.",
	"map": "Press {map} for the map. Explore to reveal it.",
	"supplies": "Press {quick_heal} for a bandage and {quick_drink} for water.",
}
const LATE_TIPS := {"menu": 25.0, "map": 80.0}

var _queue: Array[String] = []
var _waiting := false
var _clock := 0.0
var _pending_late: Dictionary = {}


func _ready() -> void:
	EventBus.prompt_changed.connect(_on_prompt)
	EventBus.gear_changed.connect(_on_gear)
	EventBus.inventory_changed.connect(_on_inventory)
	EventBus.enemy_alerted.connect(func() -> void: show_tip("attack"))
	EventBus.enemy_windup.connect(func() -> void: show_tip("block"))
	EventBus.stamina_denied.connect(func() -> void: show_tip("stamina"))
	EventBus.dialogue_finished.connect(_on_dialogue_finished.unbind(1))
	EventBus.life_lost.connect(_reset_clock.unbind(1))
	_reset_clock()


## Starts the run's tip clock; the late tips (menu, map) arrive on a timer.
func _reset_clock() -> void:
	_clock = 0.0
	_pending_late = LATE_TIPS.duplicate()


func text_for(tip_id: String) -> String:
	var text: String = TIPS.get(tip_id, "")
	for action in Settings.REBINDABLE:
		text = text.replace("{%s}" % action, "[%s]" % Settings.key_label(action))
	return text


func has_seen(tip_id: String) -> bool:
	return Settings.value("tips_seen").split(",").has(tip_id)


## Shows a tip if tips are on, a run is under way, and it has not been shown before.
func show_tip(tip_id: String) -> void:
	if not Settings.value("tips") or not Lives.active or not TIPS.has(tip_id) or has_seen(tip_id) or _queue.has(tip_id):
		return
	_queue.append(tip_id)
	_flush()


func forget_all() -> void:
	Settings.set_value("tips_seen", "")


func _flush() -> void:
	if _waiting or _queue.is_empty():
		return
	var tip_id: String = _queue.pop_front()
	var seen: PackedStringArray = Settings.value("tips_seen").split(",")
	seen.append(tip_id)
	Settings.set_value("tips_seen", ",".join(PackedStringArray(Array(seen).filter(func(entry: String) -> bool: return not entry.is_empty()))))
	_waiting = true
	Notices.run(_present.bind(tip_id))


func _present(tip_id: String) -> void:
	EventBus.tip_requested.emit(text_for(tip_id))
	get_tree().create_timer(7.0).timeout.connect(func() -> void:
		_waiting = false
		_flush())


func _process(delta: float) -> void:
	if not Lives.active:
		return
	_clock += delta
	for tip_id: String in _pending_late.keys():
		if _clock >= _pending_late[tip_id]:
			_pending_late.erase(tip_id)
			show_tip(tip_id)


func _on_prompt(text: String) -> void:
	if not text.is_empty():
		show_tip("interact")


func _on_gear(_unused: Variant = null) -> void:
	for slot in ["head", "body"]:
		if not Gear.equipped(slot).is_empty():
			show_tip("inventory")
	if Gear.equipped("weapon") != Gear.FISTS:
		show_tip("inventory")


func _on_inventory() -> void:
	if Inventory.count("bandage") + Inventory.count("purified_water") + Inventory.count("energy_bar") > 0:
		show_tip("supplies")
	elif not Inventory.snapshot().is_empty():
		show_tip("inventory")


func _on_dialogue_finished() -> void:
	show_tip("move")
