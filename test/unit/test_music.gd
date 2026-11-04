extends GutTest
## The music manager: tracks exist, crossfades pick the right one, and combat
## music comes and goes sensibly.


func after_each() -> void:
	Music.stop_area()


func test_every_mood_has_a_track() -> void:
	for track in ["title", "outpost", "factory", "dump", "river", "story", "finale", "combat", "gameover"]:
		assert_true(ResourceLoader.exists(Music.PATH_FORMAT % track), track)


func test_every_area_has_its_own_track() -> void:
	for area_id in ["outpost", "factory", "dump", "river", "fields", "industry", "sanctuary"]:
		assert_true(ResourceLoader.exists(Music.PATH_FORMAT % area_id), area_id)


func test_playing_a_track_makes_it_current() -> void:
	Music.play("title")
	assert_eq(Music.current(), "title")
	Music.play("story")
	assert_eq(Music.current(), "story")


func test_an_unknown_track_is_ignored() -> void:
	Music.play("title")
	Music.play("no_such_track")
	assert_eq(Music.current(), "title")


func test_an_area_sets_its_calm_track() -> void:
	Music.play_area("river")
	assert_eq(Music.current(), "river")
	assert_eq(Music.area_track(), "river")


func test_hunters_start_combat_music_and_calm_ends_it() -> void:
	assert_true(Music.wants_combat(2, 0.0, false))
	assert_true(Music.wants_combat(0, 1.0, true), "lingers a moment after the last zombie")
	assert_false(Music.wants_combat(0, Music.CALM_SECONDS + 0.1, true))
	assert_false(Music.wants_combat(0, 0.0, false))


func test_the_music_plays_on_its_own_bus() -> void:
	Music.play("title")
	assert_eq(Music._players[0].bus, Settings.MUSIC_BUS)


func test_music_streams_through_the_mixer_so_fades_and_volume_work_on_the_web() -> void:
	# Regression: with the web default ("sample" playback) the crossfade from
	# silence never reached the browser and music stayed inaudible.
	for player: AudioStreamPlayer in Music.find_children("*", "AudioStreamPlayer", false, false):
		assert_eq(player.playback_type, AudioServer.PLAYBACK_TYPE_STREAM)
		assert_eq(player.bus, Settings.MUSIC_BUS)


func test_a_fight_shorter_than_the_crossfade_does_not_silence_the_area_music() -> void:
	# Regression: the first crossfade's "stop the old player" fired after the
	# area track had come back on that same player, and the music went quiet.
	Music.play_area("outpost")
	await wait_seconds(0.2)
	Music.play(Music.COMBAT_TRACK)
	await wait_seconds(0.5)
	Music.play("outpost", true, Music.COMBAT_EXIT_FADE)
	await wait_seconds(Music.FADE_SECONDS + 0.5)
	assert_eq(Music.current(), "outpost")
	assert_true(Music.is_audible(), "the area music plays on after the fight")
