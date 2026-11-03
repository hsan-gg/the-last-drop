extends GutTest
## The pack sheet has full idle and run cycles; each direction must use all of them.

var _sprite: PlayerSprite


func before_each() -> void:
	_sprite = PlayerSprite.new()
	add_child_autofree(_sprite)


func test_every_direction_has_idle_and_walk_animations() -> void:
	for direction in PlayerSprite.DIRECTIONS:
		assert_true(_sprite.sprite_frames.has_animation("idle_%s" % direction), direction)
		assert_true(_sprite.sprite_frames.has_animation("walk_%s" % direction), direction)


func test_the_full_run_cycle_is_used() -> void:
	if not _sprite._has_full_layout():
		pending("generated fallback sheet has no full cycle")
		return
	for direction in PlayerSprite.DIRECTIONS:
		assert_eq(_sprite.sprite_frames.get_frame_count("walk_%s" % direction), PlayerSprite.IDLE_FRAMES)
		assert_eq(_sprite.sprite_frames.get_frame_count("idle_%s" % direction), PlayerSprite.IDLE_FRAMES)


func test_run_frames_differ_from_each_other() -> void:
	if not _sprite._has_full_layout():
		pending("generated fallback sheet has no full cycle")
		return
	var first := _sprite.sprite_frames.get_frame_texture("walk_down", 0) as AtlasTexture
	var mid := _sprite.sprite_frames.get_frame_texture("walk_down", 3) as AtlasTexture
	var image := PlayerSprite.SHEET.get_image()
	assert_ne(image.get_region(first.region).get_data(), image.get_region(mid.region).get_data())


func test_facing_follows_the_movement_vector() -> void:
	_sprite.face(Vector2.RIGHT, true)
	assert_eq(_sprite.animation, &"walk_right")
	_sprite.face(Vector2.ZERO, false)
	assert_eq(_sprite.animation, &"idle_right", "stops facing the way it was moving")


func test_feet_stay_on_the_origin() -> void:
	assert_almost_eq(_sprite.position.y, -_sprite._frame_height() / 2.0, 0.01)
