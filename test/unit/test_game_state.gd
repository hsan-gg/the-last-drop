extends GutTest


func before_each() -> void:
	GameState.reset()


func test_unset_flag_is_false() -> void:
	assert_false(GameState.has_flag("water_tested"))


func test_set_flag_defaults_to_true() -> void:
	GameState.set_flag("water_tested")
	assert_true(GameState.has_flag("water_tested"))


func test_get_flag_returns_default_when_missing() -> void:
	assert_eq(GameState.get_flag("count", 7), 7)


func test_set_flag_emits_signal() -> void:
	watch_signals(EventBus)
	GameState.set_flag("recording_found")
	assert_signal_emitted_with_parameters(EventBus, "flag_changed", ["recording_found", true])


func test_reset_clears_flags() -> void:
	GameState.set_flag("recording_found")
	GameState.reset()
	assert_false(GameState.has_flag("recording_found"))
