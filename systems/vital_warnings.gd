class_name VitalWarnings
extends RefCounted
## When to warn that you are thirsty. The warning appears only while it costs
## you something: with no water left the game slows you down (see
## Survival.is_exhausted), and that is when this says so. It goes the moment
## you drink.

enum Kind { NONE, EXHAUSTED }

const BREATH_SECONDS := 1.4

var current := Kind.NONE


## Moves to the warning that fits this much water (0-100).
func update(water: float) -> Kind:
	current = Kind.EXHAUSTED if water <= 0.0 else Kind.NONE
	return current


## The words for a warning. `drink_key` is whatever drinks water (a key or button).
static func text_for(kind: Kind, drink_key: String) -> String:
	if kind == Kind.EXHAUSTED:
		return "THIRSTY: slowed. Drink water (%s)" % drink_key
	return ""
