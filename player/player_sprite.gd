class_name PlayerSprite
extends AnimatedSprite2D
## Builds walk and idle animations from the 3x4 sprite sheet
## (columns: idle, step A, step B; rows: down, up, left, right).

const SHEET := preload("res://assets/sprites/player.png")
const FRAME_SIZE := 16
const DIRECTIONS: Array[String] = ["down", "up", "left", "right"]
const WALK_FRAMES: Array[int] = [1, 0, 2, 0]
const WALK_FPS := 8.0


func _ready() -> void:
	sprite_frames = _build_frames()
	play("idle_down")


## Picks the animation for a movement vector; no movement keeps the last facing.
func face(direction: Vector2, moving: bool) -> void:
	var facing := _facing_name(direction) if moving else _current_facing()
	var wanted := "%s_%s" % ["walk" if moving else "idle", facing]
	if animation != wanted:
		play(wanted)


func _current_facing() -> String:
	return String(animation).get_slice("_", 1)


func _facing_name(direction: Vector2) -> String:
	if absf(direction.x) > absf(direction.y):
		return "right" if direction.x > 0.0 else "left"
	return "down" if direction.y > 0.0 else "up"


func _build_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for row in DIRECTIONS.size():
		var idle := "idle_%s" % DIRECTIONS[row]
		frames.add_animation(idle)
		frames.set_animation_speed(idle, 1.0)
		frames.add_frame(idle, _frame(0, row))

		var walk := "walk_%s" % DIRECTIONS[row]
		frames.add_animation(walk)
		frames.set_animation_speed(walk, WALK_FPS)
		for column in WALK_FRAMES:
			frames.add_frame(walk, _frame(column, row))
	return frames


func _frame(column: int, row: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = SHEET
	atlas.region = Rect2(column * FRAME_SIZE, row * FRAME_SIZE, FRAME_SIZE, FRAME_SIZE)
	return atlas
