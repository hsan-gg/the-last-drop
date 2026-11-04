extends GutTest
## Warnings for being thirsty, exhausted or out of breath.


func before_each() -> void:
	Survival.set_process(false)
	Survival.reset()


func after_each() -> void:
	Survival.reset()
	Survival.set_process(true)


func test_no_warning_while_you_have_plenty_of_water() -> void:
	var rules := VitalWarnings.new()
	assert_eq(rules.update(100.0), VitalWarnings.Kind.NONE)
	assert_eq(rules.update(40.0), VitalWarnings.Kind.NONE)


func test_thirsty_when_water_runs_low_and_exhausted_when_it_is_gone() -> void:
	var rules := VitalWarnings.new()
	assert_eq(rules.update(VitalWarnings.THIRSTY_AT), VitalWarnings.Kind.THIRSTY)
	assert_eq(rules.update(5.0), VitalWarnings.Kind.THIRSTY)
	assert_eq(rules.update(0.0), VitalWarnings.Kind.EXHAUSTED)


func test_a_warning_does_not_flicker_at_its_edge() -> void:
	var rules := VitalWarnings.new()
	rules.update(20.0)
	assert_eq(rules.update(VitalWarnings.THIRSTY_AT + 2.0), VitalWarnings.Kind.THIRSTY, "still warning just above the line")
	assert_eq(rules.update(VitalWarnings.THIRSTY_CLEARS_AT), VitalWarnings.Kind.NONE, "clears a little higher")


func test_drinking_after_exhaustion_steps_back_through_thirsty() -> void:
	var rules := VitalWarnings.new()
	rules.update(0.0)
	assert_eq(rules.update(10.0), VitalWarnings.Kind.THIRSTY)
	assert_eq(rules.update(60.0), VitalWarnings.Kind.NONE)


func test_the_words_say_what_to_do() -> void:
	assert_true(VitalWarnings.text_for(VitalWarnings.Kind.THIRSTY, "G").contains("drink water (G)"))
	assert_true(VitalWarnings.text_for(VitalWarnings.Kind.EXHAUSTED, "G").contains("slowed"))
	assert_eq(VitalWarnings.text_for(VitalWarnings.Kind.NONE, "G"), "")


func test_the_banner_shows_when_you_get_thirsty_then_exhausted_and_goes_when_you_drink() -> void:
	var banner := VitalWarning.new()
	add_child_autofree(banner)
	assert_false(banner.is_warning())
	EventBus.survival_changed.emit(20.0, 100.0)
	assert_true(banner.is_warning())
	assert_true(banner.message().begins_with("THIRSTY"))
	EventBus.survival_changed.emit(0.0, 100.0)
	assert_true(banner.message().begins_with("EXHAUSTED"))
	EventBus.survival_changed.emit(80.0, 100.0)
	assert_false(banner.is_warning(), "drinking clears it")


func test_the_banner_makes_a_cue_once_when_a_warning_first_appears() -> void:
	var banner := VitalWarning.new()
	add_child_autofree(banner)
	AudioManager.played.clear()
	EventBus.survival_changed.emit(24.0, 100.0)
	EventBus.survival_changed.emit(23.0, 100.0)
	EventBus.survival_changed.emit(22.0, 100.0)
	assert_eq(AudioManager.played.count("warn"), 1, "one cue, not one per tick")
	EventBus.survival_changed.emit(0.0, 100.0)
	assert_eq(AudioManager.played.count("warn"), 2, "and another when it gets worse")


func test_running_out_of_stamina_says_out_of_breath_for_a_moment() -> void:
	var banner := VitalWarning.new()
	add_child_autofree(banner)
	EventBus.stamina_denied.emit()
	assert_true(banner.message().begins_with("OUT OF BREATH"))
	banner._process(VitalWarnings.BREATH_SECONDS + 0.1)
	assert_false(banner.is_warning(), "it passes")


func test_a_real_drop_in_water_triggers_the_warning() -> void:
	var banner := VitalWarning.new()
	add_child_autofree(banner)
	Survival.tick(300.0)  # long enough for the water to drain right down
	assert_true(banner.is_warning(), "Survival's own signal reaches the banner")


func test_the_banner_lands_on_screen_at_the_top_clear_of_the_stats() -> void:
	# Regression: its frame had no size, so the banner sat off-screen.
	var holder := Control.new()
	holder.size = Vector2(480, 270)
	add_child_autofree(holder)
	var banner := VitalWarning.new()
	holder.add_child(banner)
	EventBus.survival_changed.emit(10.0, 100.0)
	await wait_process_frames(3)
	var rect: Rect2 = banner._panel.get_global_rect()
	assert_gt(banner.size.x, 100.0, "the banner's frame fills the screen")
	assert_true(Rect2(Vector2.ZERO, holder.size).encloses(rect), "the whole banner is on screen: %s" % rect)
	assert_lt(rect.end.y, 50.0, "along the top")
	assert_gte(rect.position.x, 118.0, "clear of the stats on the left")
	assert_lt(rect.end.x, holder.size.x - 100.0, "clear of the map and menu buttons")
