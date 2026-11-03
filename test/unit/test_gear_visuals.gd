extends GutTest
## Equipped gear shows on the player.

const PLAYER_SCENE := preload("res://player/player.tscn")

var _player: Player


func before_each() -> void:
	Gear.reset()
	_player = PLAYER_SCENE.instantiate()
	add_child_autofree(_player)


func after_each() -> void:
	Gear.reset()


func _visuals() -> GearVisuals:
	return _player.get_node("GearVisuals") as GearVisuals


func test_a_bare_player_wears_and_carries_nothing() -> void:
	assert_false(_visuals().head_visible())
	assert_false(_visuals().body_visible())
	assert_false(_visuals().sword_at_hip(), "fists need no holster")


func test_equipping_a_helmet_and_armour_shows_them() -> void:
	Gear.grant("hard_hat")
	Gear.grant("tire_vest")
	assert_true(_visuals().head_visible())
	assert_true(_visuals().body_visible())


func test_a_sword_hangs_at_the_hip() -> void:
	Gear.grant("rusty_sword")
	_visuals()._process(0.0)
	assert_true(_visuals().sword_at_hip())


func test_taking_gear_off_removes_it() -> void:
	Gear.grant("hard_hat")
	Gear.unequip("head")
	assert_false(_visuals().head_visible())


func test_every_helmet_and_armour_has_its_own_picture() -> void:
	var seen := {}
	for gear_id in ["hard_hat", "welding_mask", "crash_helmet", "cloth_wrap", "tire_vest", "scrap_plate", "riot_jacket"]:
		var texture := GearVisuals.worn_texture(gear_id)
		assert_not_null(texture, gear_id)
		assert_eq(texture.get_size(), Vector2(64, 18), "%s has four 16x18 facings" % gear_id)
		seen[texture.get_image().get_data().hex_encode()] = true
	assert_eq(seen.size(), 7, "no two pieces look the same")


func test_worn_pieces_ride_on_the_player_sprite() -> void:
	Gear.grant("hard_hat")
	await wait_frames(2)
	var sprite := _player.get_node("Sprite")
	var overlays := sprite.find_children("*", "Sprite2D", false, false)
	assert_eq(overlays.size(), 2, "head and body overlays are children of the sprite")
