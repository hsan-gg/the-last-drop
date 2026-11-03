extends GutTest
## The polish layer must exist in every scene and survive a damage event.


func test_vignette_overlay_is_built_and_ignores_the_mouse() -> void:
	var overlay: ColorRect = Polish.get_child(0)
	assert_not_null(overlay.material, "vignette material")
	assert_eq(overlay.mouse_filter, Control.MOUSE_FILTER_IGNORE)


func test_damage_event_does_not_error() -> void:
	EventBus.damage_taken.emit(5.0)
	await wait_frames(2)
	assert_true(is_instance_valid(Polish))
