extends GutTest
## Warnings for being thirsty, exhausted or out of breath.


func before_each() -> void:
	Survival.set_process(false)
	Survival.reset()


func after_each() -> void:
	Survival.reset()
	Survival.set_process(true)


func test_no_warning_until_the_game_actually_slows_you() -> void:
	var rules := VitalWarnings.new()
	for water in [100.0, 60.0, 25.0, 10.0, 1.0]:
		assert_eq(rules.update(water), VitalWarnings.Kind.NONE, "%d water: low, but not slowed yet" % water)
	assert_eq(rules.update(0.0), VitalWarnings.Kind.EXHAUSTED)
	assert_true(Survival.is_exhausted() == (Survival.water() <= 0.0), "the same condition that slows you")


func test_the_warning_goes_the_moment_you_drink() -> void:
	var rules := VitalWarnings.new()
	rules.update(0.0)
	assert_eq(rules.update(10.0), VitalWarnings.Kind.NONE)


func test_the_words_say_what_to_do() -> void:
	var text := VitalWarnings.text_for(VitalWarnings.Kind.EXHAUSTED, "G")
	assert_true(text.contains("THIRSTY") and text.contains("slowed") and text.contains("Drink water (G)"))
	assert_eq(VitalWarnings.text_for(VitalWarnings.Kind.NONE, "G"), "")


func test_the_banner_shows_only_once_you_are_slowed_and_goes_when_you_drink() -> void:
	var banner := VitalWarning.new()
	add_child_autofree(banner)
	assert_false(banner.is_warning())
	EventBus.survival_changed.emit(20.0, 100.0)
	assert_false(banner.is_warning(), "low water is not a warning yet")
	EventBus.survival_changed.emit(0.0, 100.0)
	assert_true(banner.message().begins_with("THIRSTY"), "now you are slowed")
	EventBus.survival_changed.emit(80.0, 100.0)
	assert_false(banner.is_warning(), "drinking clears it")


func test_the_banner_makes_a_cue_once_when_a_warning_first_appears() -> void:
	var banner := VitalWarning.new()
	add_child_autofree(banner)
	AudioManager.played.clear()
	EventBus.survival_changed.emit(20.0, 100.0)
	assert_eq(AudioManager.played.count("warn"), 0, "silent while you are not slowed")
	EventBus.survival_changed.emit(0.0, 100.0)
	EventBus.survival_changed.emit(0.0, 99.0)
	assert_eq(AudioManager.played.count("warn"), 1, "one cue when it appears, not one per tick")


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
	Survival.tick(500.0)  # long enough to drain every drop
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
