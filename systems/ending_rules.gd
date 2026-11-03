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
	return lines
