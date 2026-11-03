extends Node
## Preview-only scene: opens each game menu tab (and the quiz and puzzle panels)
## so they can be screenshotted in a real build. Each state lasts three seconds.

const STEP_SECONDS := 3.0

var _menu := GameMenu.new()
var _step := 0


func _ready() -> void:
	_menu.pauses_game = false
	add_child(_menu)
	for area_id in ["outpost", "factory", "dump"]:
		GameState.set_flag("area_%s_reached" % area_id)
	GameState.add_to_counter("sort_correct", 4)
	GameState.add_to_counter("hazard_correct", 2)
	GameState.add_to_counter("kills", 3)
	GameState.set_flag("quest_quick_learner_done")
	Gear.grant("rusty_sword")
	Gear.grant("scrap_blade")
	Gear.grant("hard_hat")
	Gear.grant("tire_vest")
	for item_id in ["bandage", "bandage", "purified_water", "scrap_metal", "textile_scrap", "cardboard", "glass_jar", "glass_jar"]:
		Inventory.add(item_id)
	Progress.add_xp(150)
	for cell in 200:
		MapMemory.reveal("outpost", Vector2i(cell % 40, cell / 40 * 4), 3)
	var timer := Timer.new()
	timer.wait_time = STEP_SECONDS
	timer.timeout.connect(_advance)
	add_child(timer)
	timer.start()
	_advance()


func _advance() -> void:
	match _step:
		0:
			_menu.open(GameMenu.INVENTORY)
		1:
			_menu.open(GameMenu.QUESTS)
		2:
			_menu.open(GameMenu.OPTIONS)
		3:
			_menu.open(GameMenu.CONTROLS)
	_step += 1
