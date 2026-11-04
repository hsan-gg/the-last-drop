class_name TouchStick
extends RefCounted
## The maths of the on-screen joystick: how far a thumb has dragged from where
## it landed becomes the strength of the four move actions.
##
## The move actions carry a 0.5 dead zone (it suits keys and gamepads), and
## Input.get_vector() rescales whatever lies past it. So a stick pushed a
## fraction `m` of the way out presses with 0.5 + 0.5 * m, and the player walks
## at exactly `m` of full speed instead of standing still for the first half.

const DEAD_ZONE := 0.18
const ACTION_DEAD_ZONE := 0.5
const MOVES := ["move_left", "move_right", "move_up", "move_down"]


## How far out the stick is, 0 (resting) to 1 (at the rim), after the dead zone.
static func reach(offset: Vector2, radius: float) -> float:
	if radius <= 0.0:
		return 0.0
	var amount := clampf(offset.length() / radius, 0.0, 1.0)
	if amount <= DEAD_ZONE:
		return 0.0
	return (amount - DEAD_ZONE) / (1.0 - DEAD_ZONE)


## The strength to press each move action with, keyed by action name.
static func strengths(offset: Vector2, radius: float) -> Dictionary:
	var result := {"move_left": 0.0, "move_right": 0.0, "move_up": 0.0, "move_down": 0.0}
	var m := reach(offset, radius)
	if m <= 0.0:
		return result
	var press := offset.normalized() * (ACTION_DEAD_ZONE + (1.0 - ACTION_DEAD_ZONE) * m)
	result["move_left"] = maxf(-press.x, 0.0)
	result["move_right"] = maxf(press.x, 0.0)
	result["move_up"] = maxf(-press.y, 0.0)
	result["move_down"] = maxf(press.y, 0.0)
	return result


## Where the knob is drawn: the thumb, held inside the rim.
static func knob(offset: Vector2, radius: float) -> Vector2:
	return offset.limit_length(radius)
