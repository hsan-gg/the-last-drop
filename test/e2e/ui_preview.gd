extends Node
## Preview-only scene: opens each game menu tab (and the quiz and puzzle panels)
## so they can be screenshotted in a real build. Each state lasts three seconds.

const STEP_SECONDS := 3.0

var _menu := GameMenu.new()
var _step := 0
var _tracker: ObjectiveTracker
var _banners: BannerQueue
var _feed: NotificationFeed


func _ready() -> void:
	_menu.pauses_game = false
	add_child(_menu)
	var layer := CanvasLayer.new()
	add_child(layer)
	_tracker = ObjectiveTracker.new()
	layer.add_child(_tracker)
	_banners = BannerQueue.new()
	layer.add_child(_banners)
	_feed = NotificationFeed.new()
	layer.add_child(_feed)
	var card := RewardCard.new()
	layer.add_child(card)
	_feed.reward_card = card
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
		4:
			GameState.set_flag("lesson_seen_battery_leak")
			GameState.set_flag("lesson_seen_runoff")
			_menu.open(GameMenu.CODEX)
		5:
			_menu.close()
			_tracker.mark_new()
			_feed.notify("objective_done", "Done!", "Find a water source")
			_feed.notify("objective_new", "New objective", "Sort the scrap pile")
			_feed.notify("quest", "Quest complete", "Sharp Eye")
			_feed.add_xp(12)
			_feed.add_xp(30)
			EventBus.reward_requested.emit("level", "LEVEL 3", "Max health +8, sword damage +1, stamina +4. You feel restored.")
		6:
			_tracker.toggle()
	_step += 1
