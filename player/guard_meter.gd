class_name GuardMeter
extends Node2D
## A small bar over the player's head about the guard: while blocking it drains
## to show how long the arm can hold; after the guard drops it refills as the
## cooldown runs out, and blinks once when the guard is ready again. Hidden
## the rest of the time so it never clutters the screen.

const WIDTH := 14.0
const HEIGHT := 2.0
const HOLD_COLOR := Color("#5fe0ff")
const COOLDOWN_COLOR := Color("#e0a04a")
const BROKEN_COLOR := Color("#ff6a4a")
const READY_FLASH_SECONDS := 0.35

var _combat: PlayerCombat
var _was_cooling := false
var _ready_flash := 0.0


func _ready() -> void:
	position = Vector2(0, -24)
	z_index = 20
	_combat = (get_parent() as Player).combat


func _process(delta: float) -> void:
	var cooling := _combat != null and _combat.block_cooldown_left() > 0.0
	if _was_cooling and not cooling:
		_ready_flash = READY_FLASH_SECONDS
	_was_cooling = cooling
	_ready_flash = maxf(_ready_flash - delta, 0.0)
	queue_redraw()


func is_showing() -> bool:
	return _combat != null and (_combat.is_blocking() or _combat.block_cooldown_left() > 0.0 or _ready_flash > 0.0)


func _draw() -> void:
	if not is_showing():
		return
	var back := Rect2(-WIDTH / 2.0 - 1.0, -1.0, WIDTH + 2.0, HEIGHT + 2.0)
	draw_rect(back, Color(0.06, 0.05, 0.09, 0.85))
	var ratio := 1.0
	var color := HOLD_COLOR
	if _combat.is_blocking():
		ratio = _combat.guard_hold_ratio()
	elif _combat.block_cooldown_left() > 0.0:
		ratio = _combat.block_cooldown_ratio()
		color = BROKEN_COLOR if _combat.block_cooldown_left() > PlayerCombat.BLOCK_COOLDOWN_SECONDS else COOLDOWN_COLOR
	else:
		color = Color(1, 1, 1, _ready_flash / READY_FLASH_SECONDS)
	draw_rect(Rect2(-WIDTH / 2.0, 0.0, WIDTH * ratio, HEIGHT), color)
