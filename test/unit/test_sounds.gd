extends GutTest
## Every sound the game asks for exists, sounds heard often come in several
## takes, sounds in the world fade with distance, and the actions that should
## make a noise do.

const SOURCE_DIRS: Array[String] = ["res://autoload", "res://player", "res://world", "res://ui", "res://systems", "res://interaction"]
const CALL := "(?:sfx_requested\\.emit|AudioManager\\.play(?:_at)?)\\(\"([a-z0-9_]+)\""


func _scripts(dir_path: String) -> Array[String]:
	var found: Array[String] = []
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return found
	for file in dir.get_files():
		if file.ends_with(".gd"):
			found.append(dir_path.path_join(file))
	for sub in dir.get_directories():
		found.append_array(_scripts(dir_path.path_join(sub)))
	return found


func test_every_sound_the_game_asks_for_exists() -> void:
	var pattern := RegEx.create_from_string(CALL)
	var names := {}
	for dir_path in SOURCE_DIRS:
		for script in _scripts(dir_path):
			for found in pattern.search_all(FileAccess.get_file_as_string(script)):
				names[found.get_string(1)] = script
	assert_gt(names.size(), 30, "the scan found the game's sounds")
	for sound: String in names:
		var exists := ResourceLoader.exists(AudioManager.SFX_PATH_FORMAT % sound) or AudioManager.variant_count(sound) > 0
		assert_true(exists, "%s (asked for in %s)" % [sound, names[sound]])


func test_sounds_heard_often_come_in_several_takes() -> void:
	for sound in ["swing", "enemy_hurt", "zombie_groan", "zombie_alert", "zombie_attack"]:
		assert_gt(AudioManager.variant_count(sound), 1, sound)


func test_world_sounds_fade_with_distance_and_vanish_far_away() -> void:
	var player := Node2D.new()
	player.add_to_group("player")
	add_child_autofree(player)
	player.global_position = Vector2.ZERO
	assert_eq(AudioManager.volume_at(Vector2(20, 0)), 0.0, "right beside you: full volume")
	var middle := AudioManager.volume_at(Vector2(180, 0))
	assert_lt(middle, 0.0)
	assert_gt(middle, AudioManager.FAR_DB)
	assert_lt(AudioManager.volume_at(Vector2(AudioManager.FAR + 10, 0)), AudioManager.SILENT_DB, "too far to hear")


func test_raising_the_guard_and_opening_the_menu_make_a_sound() -> void:
	var player: Player = preload("res://player/player.tscn").instantiate()
	add_child_autofree(player)
	AudioManager.played.clear()
	player.combat.raise_guard()
	assert_has(AudioManager.played, "guard_up")
	var menu := GameMenu.new()
	add_child_autofree(menu)
	menu.open()
	assert_has(AudioManager.played, "menu_open")
	menu.close()
	assert_has(AudioManager.played, "menu_close")
	get_tree().paused = false


func test_buttons_click_with_a_sound_that_is_actually_there() -> void:
	# Regression: the click had been cut to its first 10 ms by the importer.
	var click: AudioStream = load(AudioManager.SFX_PATH_FORMAT % AudioManager.BUTTON_PRESS_SOUND)
	assert_gt(click.get_length(), 0.08)
	var button := Button.new()
	add_child_autofree(button)
	AudioManager.played.clear()
	button.pressed.emit()
	assert_has(AudioManager.played, AudioManager.BUTTON_PRESS_SOUND)
