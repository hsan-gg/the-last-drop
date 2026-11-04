class_name EndingRules
extends RefCounted
## Builds the epilogue from the player's final choice and how carefully they sorted.

const CHOICE_PRESERVE := "preserve"
const CHOICE_SHARE := "share"
const MISTAKES_FOR_LEARNING := 1
const MISTAKES_FOR_RECKLESS := 4


static func tone(mistakes: int) -> String:
	if mistakes < MISTAKES_FOR_LEARNING:
		return "careful"
	if mistakes < MISTAKES_FOR_RECKLESS:
		return "learning"
	return "reckless"


static func epilogue_lines(choice: String, mistakes: int) -> Array[String]:
	var lines: Array[String] = []
	lines.append_array(Content.dialogue("ending_%s" % choice))
	lines.append_array(Content.dialogue("ending_tone_%s" % tone(mistakes)))
	lines.append_array(story_lines())
	return lines


## What the journey changed, read from the story flags.
static func story_lines() -> Array[String]:
	var lines: Array[String] = []
	if GameState.has_flag("harvest_done") and GameState.has_flag("grid_online") and GameState.has_flag("river_clean"):
		lines.append("Clean water. Living soil. Light. A foundation to build on.")
	if GameState.has_flag("tobi_remembered"):
		lines.append("Old Tobi keeps the Sanctuary's water running. Some evenings he sings to the seeds. Badly.")
	if GameState.has_flag("request_done_radio"):
		lines.append("Mira fixes every radio in the valley. Voices answer from places nobody thought were alive.")
	if GameState.has_flag("boss_golem_defeated"):
		lines.append("Vex shares the plant's power down the line. He calls it 'efficient'. It's kindness.")
	return lines
