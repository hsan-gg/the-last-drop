extends GutTest
## Objective hints, banners, consumables and the objective announcements.

const HUD_SCENE := preload("res://world/outpost.tscn")


func before_each() -> void:
	Notices.clear()
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
	var feed: NotificationFeed = hud._feed
	(area.find_children("*", "DialogueBox", true, false)[0] as DialogueBox).interrupt()  # the arrival talk
	await wait_seconds(0.6)
	var before := feed.count()
	GameState.set_flag("water_tested")
	assert_eq(feed.count(), before, "nothing appears in the same instant")
	await wait_frames(4)
	assert_eq(feed.pending_kinds().slice(0, 1), ["objective_done"] as Array[String], "what you finished comes first")
	assert_eq(feed.pending_kinds().back(), "objective_new", "what to do next comes last")
	assert_true(hud._tracker.has_news(), "the tasks chip shows a quiet !")
	assert_false(hud._tracker.is_shown(), "the list itself does not pop open")


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


func test_notices_wait_for_a_conversation_to_end() -> void:
	var banners := BannerQueue.new()
	add_child_autofree(banners)
	EventBus.dialogue_opened.emit()
	banners.push("QUEST COMPLETE", "Sharp Eye")
	assert_true(Notices.is_holding())
	assert_eq(Notices.waiting(), 1, "held back while talking")
	EventBus.dialogue_finished.emit("x")
	assert_false(Notices.is_holding())
	await wait_seconds(0.7)
	assert_eq(Notices.waiting(), 0)
	assert_eq(banners.pending(), 1, "shown once the talk is over")


func test_a_cut_short_conversation_also_releases_notices() -> void:
	var banners := BannerQueue.new()
	add_child_autofree(banners)
	EventBus.dialogue_opened.emit()
	banners.push("NEW OBJECTIVE", "Sort the pile")
	EventBus.dialogue_interrupted.emit()
	await wait_seconds(0.7)
	assert_eq(Notices.waiting(), 0)
	assert_eq(banners.pending(), 1)


func test_a_notice_raised_in_the_same_instant_a_talk_opens_waits_for_it() -> void:
	var feed := NotificationFeed.new()
	add_child_autofree(feed)
	feed.notify("objective_new", "New objective", "Fix the pump")
	EventBus.dialogue_opened.emit()  # same frame, as when talking to something sets a flag
	await wait_frames(5)
	assert_eq(feed.count(), 0, "held back behind the conversation")
	EventBus.dialogue_finished.emit("x")
	await wait_seconds(0.7)
	assert_eq(feed.count(), 1)


func test_xp_gains_merge_into_one_line() -> void:
	var feed := NotificationFeed.new()
	add_child_autofree(feed)
	feed.notify("info", "Busy", "something on screen first")
	await wait_frames(4)
	feed.add_xp(5)
	feed.add_xp(7)
	await wait_frames(4)
	var xp_entries := feed._queue.filter(func(entry: Dictionary) -> bool: return entry["kind"] == "xp")
	assert_eq(xp_entries.size(), 1)
	assert_eq(int(xp_entries[0]["amount"]), 12)


func test_things_that_happen_together_are_told_in_order() -> void:
	var feed := NotificationFeed.new()
	add_child_autofree(feed)
	feed.notify("objective_new", "New objective", "Next thing")
	feed.add_xp(30)
	feed.notify("objective_done", "Done!", "Old thing")
	await wait_frames(4)
	assert_eq(feed.pending_kinds(), ["objective_done", "xp", "objective_new"] as Array[String])


func test_at_most_two_cards_stack_and_they_leave_one_by_one() -> void:
	var feed := NotificationFeed.new()
	add_child_autofree(feed)
	for index in 4:
		feed.notify("quest", "Quest complete", "Quest %d" % index)
	await wait_seconds(1.0)
	assert_eq(feed.showing(), 2, "two stacked")
	assert_eq(feed.count(), 4, "the rest wait for a slot")


func test_a_level_up_shows_at_once() -> void:
	var feed := NotificationFeed.new()
	add_child_autofree(feed)
	var card := RewardCard.new()
	add_child_autofree(card)
	feed.reward_card = card
	for index in 3:
		feed.notify("quest", "Quest complete", "Quest %d" % index)
	EventBus.reward_requested.emit("level", "LEVEL 2", "Stronger.")
	await wait_frames(5)
	assert_true(card.is_showing(), "no waiting behind the other messages")


func test_cards_that_have_left_are_forgotten_cleanly() -> void:
	# Regression: counting cards after one was freed raised an engine error.
	var feed := NotificationFeed.new()
	add_child_autofree(feed)
	feed.notify("quest", "Quest complete", "One")
	await wait_seconds(3.6)
	assert_eq(feed.showing(), 0)


func test_arriving_in_an_area_does_not_announce_an_old_objective_as_done() -> void:
	var area: Node = add_child_autofree(preload("res://world/industry.tscn").instantiate())
	await wait_physics_frames(2)
	var hud: Hud = area.find_children("*", "Hud", true, false)[0]
	(area.find_children("*", "DialogueBox", true, false)[0] as DialogueBox).interrupt()
	await wait_seconds(0.7)
	var shown := ""
	for label: Label in hud._feed.find_children("*", "Label", true, false):
		shown += label.text + "|"
	assert_false("Done!" in shown, "nothing was finished by walking in")
