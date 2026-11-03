extends GutTest
## Story cutscene data and the player that runs them. Scene changes are off so
## nothing replaces the test runner.


func before_each() -> void:
	GameState.reset()
	Cutscenes.changes_scene = false
	Cutscenes.pending_id = ""


func after_each() -> void:
	Cutscenes.changes_scene = true
	Cutscenes.pending_id = ""
	GameState.reset()


func test_every_beat_has_a_visual_and_some_words() -> void:
	assert_gt(Cutscenes.ids().size(), 0)
	for cutscene_id in Cutscenes.ids():
		var beats := Cutscenes.beats(cutscene_id)
		assert_gt(beats.size(), 0, cutscene_id)
		for beat: Dictionary in beats:
			assert_true(beat["visual"] in ["sky", "map", "black", "ruins", "outpost", "factory", "dump", "river", "spring"], "%s: bad visual" % cutscene_id)
			assert_false(String(beat["text"]).is_empty(), "%s: empty text" % cutscene_id)


func test_map_beats_only_light_known_regions() -> void:
	var known: Array[String] = []
	for region in CutsceneStage.REGIONS:
		known.append(region["id"])
	for beat: Dictionary in Cutscenes.beats("intro"):
		for region_id: String in beat["focus"]:
			assert_true(known.has(region_id), region_id)


func test_the_intro_walks_through_the_playable_regions_in_order() -> void:
	var lit_counts: Array[int] = []
	for beat: Dictionary in Cutscenes.beats("intro"):
		if not beat["focus"].is_empty():
			lit_counts.append(beat["focus"].size())
	assert_eq(lit_counts, [1, 2, 3, 4, 7] as Array[int])


func test_every_gate_and_the_finale_name_a_real_cutscene() -> void:
	for area_id in ["outpost", "factory", "dump"]:
		var props: Dictionary = Content.area(area_id)["entities"]["^"]["props"]
		assert_true(Cutscenes.exists(props["cutscene"]), "%s gate" % area_id)
	assert_true(Cutscenes.exists("intro"))
	assert_true(Cutscenes.exists("finale"))


func test_a_cutscene_plays_once_per_run() -> void:
	Cutscenes.pending_id = "to_dump"
	Cutscenes.finish()
	assert_true(Cutscenes.has_seen("to_dump"))
	Cutscenes.play("to_dump", "res://nowhere.tscn")
	assert_eq(Cutscenes.pending_id, "", "already seen, so it goes straight on")


func _player(beats: Array) -> CutscenePlayer:
	var player: CutscenePlayer = preload("res://ui/cutscene.tscn").instantiate()
	player._beats = beats
	add_child_autofree(player)
	return player


func test_advancing_steps_through_the_beats_and_finishes() -> void:
	Cutscenes.pending_id = "test"
	var player := _player(Cutscenes.beats("to_dump"))
	assert_eq(player.index(), 0)
	player.advance()  # the first press completes the typing
	player.advance()
	assert_eq(player.index(), 1)
	player.advance()
	player.advance()
	assert_true(player.is_done())


func test_skipping_finishes_immediately() -> void:
	Cutscenes.pending_id = "intro"
	var player := _player(Cutscenes.beats("intro"))
	watch_signals(player)
	player.finish()
	assert_true(player.is_done())
	assert_signal_emitted(player, "finished")
	assert_true(Cutscenes.has_seen("intro"))


func test_the_stage_lights_regions_for_the_focus() -> void:
	var stage := CutsceneStage.new()
	add_child_autofree(stage)
	stage.show_beat({"visual": "map", "focus": ["outpost", "factory"]})
	assert_eq(stage.lit_count(), 2)
	stage.show_beat({"visual": "black", "focus": []})
	assert_eq(stage.lit_count(), 0)


func test_dialogue_has_a_named_speaker_for_recordings_and_terminals() -> void:
	assert_eq(DialogueBox.speaker_for("recording_2")["name"], "INES")
	assert_eq(DialogueBox.speaker_for("archive_partial")["name"], "ARCHIVE")
	assert_eq(DialogueBox.speaker_for("sample_a")["name"], "TEST STRIP")
	assert_eq(DialogueBox.speaker_for("intro")["name"], "", "narration has no name plate")


func test_every_speaker_icon_exists() -> void:
	for speaker in DialogueBox.SPEAKERS:
		assert_true(ResourceLoader.exists(DialogueBox.ICON_PATH_FORMAT % speaker["icon"]), speaker["icon"])


func test_longer_beats_are_held_longer() -> void:
	assert_gt(CutscenePlayer.hold_seconds("A much longer line of words that takes time to read."), CutscenePlayer.hold_seconds("Short."))
	assert_gte(CutscenePlayer.hold_seconds(""), CutscenePlayer.MIN_HOLD_SECONDS)


func test_the_cutscene_waits_for_the_player_on_every_beat() -> void:
	var player: CutscenePlayer = preload("res://ui/cutscene.tscn").instantiate()
	Cutscenes.pending_id = "to_dump"
	add_child_autofree(player)
	await wait_physics_frames(2)
	await wait_seconds(6.0)
	assert_eq(player.index(), 0, "no beat moves on by itself")
	player.advance()
	player.advance()
	assert_eq(player.index(), 1, "a key press moves on")


func test_every_scene_draws_without_error() -> void:
	var canvas := Control.new()
	add_child_autofree(canvas)
	for kind in CutsceneScenes.SCENES:
		var stage := CutsceneStage.new()
		canvas.add_child(stage)
		stage.show_beat({"visual": kind, "focus": ["outpost", "factory"]})
		await wait_frames(2)
		assert_eq(stage.mode, kind)


func test_scenes_are_acted_by_the_game_sprites() -> void:
	var actors := CutsceneActors.new()
	add_child_autofree(actors)
	actors.stage("dump")
	assert_eq(actors.actor_count(), 3, "the player and two zombies")
	actors.stage("black")
	assert_eq(actors.actor_count(), 0)
	for kind in CutsceneScenes.SCENES:
		actors.stage(kind)
		assert_gt(actors.actor_count(), 0, "%s has a cast" % kind)
