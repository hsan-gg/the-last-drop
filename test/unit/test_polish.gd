extends GutTest
## The polish layer must exist in every scene and survive a damage event.


func test_vignette_overlay_is_built_and_ignores_the_mouse() -> void:
	var overlay := Polish.find_children("*", "ColorRect", false, false)[0] as ColorRect
	assert_not_null(overlay.material, "vignette material")
	assert_eq(overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_damage_event_does_not_error() -> void:
	EventBus.damage_taken.emit(5.0)
	await wait_frames(2)
	assert_true(is_instance_valid(Polish))


func test_ash_drifts_over_every_screen() -> void:
	var ash := Polish.get_node_or_null("Ash") as CPUParticles2D
	assert_not_null(ash)
	assert_true(ash.emitting)


func test_the_title_has_a_backdrop_with_embers() -> void:
	var backdrop := TitleBackdrop.new()
	add_child_autofree(backdrop)
	assert_not_null(backdrop.get_node_or_null("Embers"))
