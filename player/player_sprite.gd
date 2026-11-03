class_name PlayerSprite
extends AnimatedSprite2D
## Builds idle and walk animations from the player sheet. Rows are directions
## (down, up, left, right). The pack sheet has 12 columns: 6 idle frames then 6
## run frames. The generated fallback sheet has 3: idle, step A, step B.

const SHEET := preload("res://assets/sprites/player.png")
const FRAME_WIDTH := 16
const DIRECTIONS: Array[String] = ["down", "up", "left", "right"]
const FULL_LAYOUT_COLUMNS := 12
const IDLE_FRAMES := 6
const IDLE_FPS := 4.0
const WALK_FPS := 11.0
const LEGACY_WALK_FRAMES: Array[int] = [1, 0, 2, 0]


func _ready() -> void:
	sprite_frames = _build_frames()
	position.y = -_frame_height() / 2.0
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


func _frame_height() -> int:
	return SHEET.get_height() / DIRECTIONS.size()


func _has_full_layout() -> bool:
	return SHEET.get_width() / FRAME_WIDTH >= FULL_LAYOUT_COLUMNS


func _build_frames() -> SpriteFrames:
	var full := _has_full_layout()
	var idle_columns: Array[int] = []
	var walk_columns: Array[int] = []
	if full:
		for column in IDLE_FRAMES:
			idle_columns.append(column)
			walk_columns.append(IDLE_FRAMES + column)
	else:
		idle_columns.append(0)
		walk_columns = LEGACY_WALK_FRAMES

	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for row in DIRECTIONS.size():
		_add_animation(frames, "idle_%s" % DIRECTIONS[row], row, idle_columns, IDLE_FPS if full else 1.0)
		_add_animation(frames, "walk_%s" % DIRECTIONS[row], row, walk_columns, WALK_FPS if full else 8.0)
	return frames


func _add_animation(frames: SpriteFrames, animation_name: String, row: int, columns: Array[int], fps: float) -> void:
	frames.add_animation(animation_name)
	frames.set_animation_speed(animation_name, fps)
	for column in columns:
		frames.add_frame(animation_name, _frame(column, row))


func _frame(column: int, row: int) -> AtlasTexture:
	var atlas := AtlasTexture.new()
	atlas.atlas = SHEET
	var height := _frame_height()
	atlas.region = Rect2(column * FRAME_WIDTH, row * height, FRAME_WIDTH, height)
	return atlas
