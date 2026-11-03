extends GutTest
## Guards data/chapters.json: every reference must resolve, so planned chapters
## cannot ship with a typo in a dialogue or lesson id.

const CHAPTERS_PATH := "res://data/chapters.json"

var _chapters: Array = []


func before_each() -> void:
	var loaded: Variant = DataLoader.load_json(CHAPTERS_PATH)
	_chapters = loaded if typeof(loaded) == TYPE_ARRAY else []


func test_chapters_load_in_order() -> void:
	assert_gt(_chapters.size(), 0)
	for index in _chapters.size():
		assert_eq(int(_chapters[index]["number"]), index, "chapter %s out of order" % _chapters[index]["id"])


func test_every_chapter_dialogue_resolves() -> void:
	for chapter: Dictionary in _chapters:
		var ids: Array = [chapter["arrival"], chapter["recording"]]
		ids.append_array(chapter.get("reveals", []))
		ids.append_array(chapter.get("choices", []))
		for dialogue_id: String in ids:
			assert_false(Content.dialogue(dialogue_id).is_empty(), "%s: missing dialogue %s" % [chapter["id"], dialogue_id])


func test_every_chapter_lesson_is_complete() -> void:
	for chapter: Dictionary in _chapters:
		for lesson_id: String in chapter["lessons"]:
			var lesson := Content.lesson(lesson_id)
			for key in ["title", "wrong", "right", "principle", "real_life"]:
				assert_true(lesson.has(key), "%s lesson %s missing %s" % [chapter["id"], lesson_id, key])


func test_built_chapters_have_real_areas() -> void:
	for chapter: Dictionary in _chapters:
		if chapter["status"] != "built":
			continue
		for area_id: String in chapter["areas"]:
			assert_false(Content.area(area_id).is_empty(), "no area %s" % area_id)


func test_dialogue_lines_stay_short() -> void:
	for chapter: Dictionary in _chapters:
		for dialogue_id: String in [chapter["arrival"], chapter["recording"]]:
			for line in Content.dialogue(dialogue_id):
				assert_lt(line.length(), 200, "%s line too long" % dialogue_id)


func test_the_ending_triggers_at_the_last_built_chapter() -> void:
	assert_true(Chapters.is_built("river"))
	assert_true(Chapters.is_final_built("river"))
	assert_false(Chapters.is_final_built("dump"), "the dump leads on to the river")
	assert_false(Chapters.is_final_built("factory"), "factory leads on to the dump")
	assert_false(Chapters.is_final_built("fields"), "unbuilt chapters never end the game")
	assert_false(Chapters.is_final_built("nope"))


func test_the_river_ending_needs_clean_water_a_drink_and_the_recording() -> void:
	GameState.reset()
	assert_false(Chapters.ending_ready("river"))
	GameState.set_flag("river_clean")
	GameState.set_flag("river_water_secure")
	assert_false(Chapters.ending_ready("river"), "the recording is still missing")
	GameState.set_flag("recording_3_found")
	assert_true(Chapters.ending_ready("river"))
	assert_false(Chapters.ending_ready("dump"), "only the last built chapter can end the game")
	GameState.reset()


func test_areas_map_back_to_their_chapter() -> void:
	assert_eq(Chapters.chapter_for_area("river")["id"], "river")
	assert_eq(Chapters.chapter_for_area("nowhere"), {})
