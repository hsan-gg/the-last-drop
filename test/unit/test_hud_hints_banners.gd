extends GutTest
## Objective hints, banners, consumables and the objective announcements.

const HUD_SCENE := preload("res://world/outpost.tscn")


func before_each() -> void:
	GameState.reset()
	Survival.set_process(false)
	Survival.reset()
	Inventory.clear()
	Settings.reset_all()


func after_each() -> void:
	Settings.reset_all()
	Survival.reset()
	Survival.set_process(true)
	Inventory.clear()
	get_tree().paused = false


func test_hints_are_subtle_by_default_and_off_when_chosen() -> void:
	var beacon := ObjectiveBeacon.new()
	add_child_autofree(beacon)
	assert_eq(beacon.strength(), ObjectiveBeacon.SUBTLE_ALPHA)
	Settings.set_value("objective_hints", Settings.HINTS_OFF)
	assert_eq(beacon.strength(), 0.0)
	Settings.set_value("objective_hints", Settings.HINTS_STRONG)
	assert_eq(beacon.strength(), ObjectiveBeacon.STRONG_ALPHA)


func test_a_subtle_hint_grows_after_being_stuck_for_a_while() -> void:
	var beacon := ObjectiveBeacon.new()
	add_child_autofree(beacon)
	beacon._idle = ObjectiveBeacon.IDLE_BOOST_SECONDS + 1.0
	assert_eq(beacon.strength(), ObjectiveBeacon.STRONG_ALPHA)


func test_banners_queue_and_show_one_at_a_time() -> void:
	var banners := BannerQueue.new()
	add_child_autofree(banners)
	banners.push("ONE", "first")
	banners.push("TWO", "second")
	assert_eq(banners.pending(), 2)


func test_the_banner_signal_reaches_the_queue() -> void:
	var banners := BannerQueue.new()
	add_child_autofree(banners)
	EventBus.banner_requested.emit("LIFE LOST", "2 lives left", Color.RED)
	assert_eq(banners.pending(), 1)


func test_the_tracker_lists_the_goal_and_open_tasks() -> void:
	GameState.set_flag("area_outpost_reached")
	var tracker := ObjectiveTracker.new()
	add_child_autofree(tracker)
	var text := tracker.text_for("outpost")
	assert_string_contains(text, "OBJECTIVE")
	assert_string_contains(text, "TASKS")
	assert_string_contains(text, "Sharp Eye")


func test_the_tracker_is_hidden_until_asked_for() -> void:
	var tracker := ObjectiveTracker.new()
	add_child_autofree(tracker)
	assert_false(tracker.is_shown())
	tracker.toggle()
	assert_true(tracker.is_shown())
	tracker.toggle()
	assert_false(tracker.is_shown())


func test_finishing_an_objective_announces_it_complete_then_the_next() -> void:
	var area: Node = add_child_autofree(HUD_SCENE.instantiate())
	await wait_physics_frames(2)
	var hud: Hud = area.find_children("*", "Hud", true, false)[0]
	var banners: BannerQueue = hud._banners
	var before := banners.pending()
	GameState.set_flag("water_tested")
	assert_eq(banners.pending(), before + 2, "COMPLETE and NEW both queue")


func test_a_bandage_heals_from_the_quick_key_helper() -> void:
	Survival.damage(50.0)
	Inventory.add("bandage")
	assert_true(Consumables.use_first(Consumables.HEAL_ORDER))
	assert_eq(Survival.health(), 80.0)


func test_purified_water_restores_water() -> void:
	Survival.tick(200.0)
	Inventory.add("purified_water")
	var before := Survival.water()
	assert_true(Consumables.use_first(Consumables.DRINK_ORDER))
	assert_gt(Survival.water(), before)


func test_nothing_happens_with_no_supplies() -> void:
	assert_false(Consumables.use_first(Consumables.HEAL_ORDER))
