class_name VitalWarnings
extends RefCounted
## When to warn that you are thirsty or exhausted. Pure rules, so the HUD only
## has to draw what this says. A warning appears at one level and clears at a
## slightly higher one, so a number hovering at the edge does not flicker.

enum Kind { NONE, THIRSTY, EXHAUSTED }

const THIRSTY_AT := 25.0
const THIRSTY_CLEARS_AT := 32.0
const BREATH_SECONDS := 1.4

var current := Kind.NONE


## Moves to the warning that fits this much water (0-100).
func update(water: float) -> Kind:
	if water <= 0.0:
		current = Kind.EXHAUSTED
	elif current == Kind.EXHAUSTED:
		current = Kind.THIRSTY if water < THIRSTY_CLEARS_AT else Kind.NONE
	elif current == Kind.THIRSTY:
		current = Kind.NONE if water >= THIRSTY_CLEARS_AT else Kind.THIRSTY
	elif water <= THIRSTY_AT:
		current = Kind.THIRSTY
	return current


## The words for a warning. `drink_key` is whatever drinks water (a key or button).
static func text_for(kind: Kind, drink_key: String) -> String:
	match kind:
		Kind.THIRSTY:
			return "THIRSTY: drink water (%s)" % drink_key
		Kind.EXHAUSTED:
			return "EXHAUSTED: slowed. Drink water (%s)" % drink_key
	return ""
