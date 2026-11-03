extends GutTest
## Tips teach the basics once, only during a run, and can be turned off.


func before_each() -> void:
	Settings.reset_all()
	Tutorial._queue.clear()
	Tutorial._waiting = false
	Notices.clear()
	Lives.start_run()


func after_each() -> void:
	Lives.reset()
	Settings.reset_all()
	Tutorial._queue.clear()
	Tutorial._waiting = false


func test_a_tip_shows_once_and_is_remembered() -> void:
	watch_signals(EventBus)
	Tutorial.show_tip("attack")
	await wait_seconds(0.15)
	assert_signal_emit_count(EventBus, "tip_requested", 1)
	assert_true(Tutorial.has_seen("attack"))
	Tutorial._waiting = false
	Tutorial.show_tip("attack")
	await wait_seconds(0.15)
	assert_signal_emit_count(EventBus, "tip_requested", 1, "never repeated")


func test_tips_name_the_current_keys() -> void:
	assert_string_contains(Tutorial.text_for("attack"), "[J]")
	Settings.rebind("attack", KEY_F)
	assert_string_contains(Tutorial.text_for("attack"), "[F]")
	Settings.reset_controls()


func test_tips_can_be_switched_off() -> void:
	watch_signals(EventBus)
	Settings.set_value("tips", false)
	Tutorial.show_tip("block")
	assert_signal_not_emitted(EventBus, "tip_requested")


func test_no_tips_outside_a_run() -> void:
	Lives.reset()
	watch_signals(EventBus)
	Tutorial.show_tip("move")
	assert_signal_not_emitted(EventBus, "tip_requested")


func test_tips_wait_while_a_conversation_is_open() -> void:
	watch_signals(EventBus)
	EventBus.dialogue_opened.emit()
	Tutorial.show_tip("inventory")
	assert_signal_not_emitted(EventBus, "tip_requested", "not over the dialogue")
	EventBus.dialogue_finished.emit("x")
	await wait_seconds(0.7)
	assert_signal_emitted(EventBus, "tip_requested")


func test_the_important_basics_all_have_tips() -> void:
	for tip_id in ["move", "interact", "inventory", "attack", "block", "stamina", "tracker", "menu", "map", "supplies"]:
		assert_false(Tutorial.text_for(tip_id).is_empty(), tip_id)
		assert_false("{" in Tutorial.text_for(tip_id), "%s has an unfilled key" % tip_id)


func test_a_zombie_noticing_you_teaches_attacking() -> void:
	watch_signals(EventBus)
	EventBus.enemy_alerted.emit()
	await wait_seconds(0.15)
	assert_signal_emitted(EventBus, "tip_requested")
	assert_string_contains(Tutorial.text_for("attack"), "swing")
