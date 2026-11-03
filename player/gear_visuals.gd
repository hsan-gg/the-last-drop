class_name GearVisuals
extends Node2D
## Shows what the player is wearing and carrying: a helmet on the head, armour
## on the torso, and the sword at the hip when it is not in use. Everything is
## drawn from the equipped gear, so equipping something changes the sprite.

const SWORD_TEXTURE := preload("res://assets/sprites/sword.png")
const HEAD_OFFSET := Vector2(0, -15)
const BODY_OFFSET := Vector2(0, -7)
const HIP_SWORD_SCALE := 0.8

var _head: Sprite2D
var _body: Sprite2D
var _sword: Sprite2D
var _player: Player


func _ready() -> void:
	_player = get_parent() as Player
	z_index = 2
	_body = _make_sprite(BODY_OFFSET)
	_head = _make_sprite(HEAD_OFFSET)
	_sword = Sprite2D.new()
	_sword.texture = SWORD_TEXTURE
	_sword.scale = Vector2(HIP_SWORD_SCALE, HIP_SWORD_SCALE)
	add_child(_sword)
	EventBus.gear_changed.connect(refresh)
	refresh()


## Rebuilds the worn pieces from the equipped gear.
func refresh() -> void:
	_head.texture = head_texture(Gear.equipped("head"))
	_body.texture = body_texture(Gear.equipped("body"))
	_sword.modulate = Gear.weapon_color()
	_sword.visible = Gear.equipped("weapon") != Gear.FISTS


func head_visible() -> bool:
	return _head.texture != null


func body_visible() -> bool:
	return _body.texture != null


func sword_at_hip() -> bool:
	return _sword.visible


func _process(_delta: float) -> void:
	var facing := _player.facing
	var drawn := _player.combat != null and _player.combat.state != PlayerCombat.State.IDLE
	_sword.visible = Gear.equipped("weapon") != Gear.FISTS and not drawn
	if absf(facing.x) > absf(facing.y):
		var side := 1.0 if facing.x > 0.0 else -1.0
		_sword.position = Vector2(-5.0 * side, -6)  # on the far hip
		_sword.rotation = 0.9 * side
		_sword.z_index = -1
	elif facing.y < 0.0:  # facing away: the sword shows on the back
		_sword.position = Vector2(4, -9)
		_sword.rotation = -0.8
		_sword.z_index = 1
	else:
		_sword.position = Vector2(6, -5)
		_sword.rotation = 1.1
		_sword.z_index = 0


func _make_sprite(at: Vector2) -> Sprite2D:
	var sprite := Sprite2D.new()
	sprite.position = at
	add_child(sprite)
	return sprite


# ------------------------------------------------------------------ drawing

static func head_texture(gear_id: String) -> Texture2D:
	if gear_id.is_empty():
		return null
	var image := Image.create(12, 6, false, Image.FORMAT_RGBA8)
	match gear_id:
		"hard_hat":
			_rows(image, Color("#e8c040"), [[3, 5], [2, 8], [1, 10]], 0)
			_fill(image, Rect2i(0, 3, 12, 2), Color("#b89420"))
			_fill(image, Rect2i(5, 0, 2, 2), Color("#b89420"))
		"welding_mask":
			_fill(image, Rect2i(1, 0, 10, 6), Color("#8a8a9e"))
			_fill(image, Rect2i(2, 2, 8, 2), Color("#24342c"))
			_fill(image, Rect2i(3, 2, 3, 1), Color("#5aa060"))
		"crash_helmet":
			_rows(image, Color("#c04040"), [[3, 6], [2, 8], [1, 10], [1, 10]], 0)
			_fill(image, Rect2i(2, 4, 9, 2), Color("#2a2030"))
			_fill(image, Rect2i(3, 4, 3, 1), Color("#9fe0e8"))
		_:
			_fill(image, Rect2i(1, 1, 10, 4), Color("#c8c8d4"))
	return ImageTexture.create_from_image(image)


static func body_texture(gear_id: String) -> Texture2D:
	if gear_id.is_empty():
		return null
	var image := Image.create(10, 6, false, Image.FORMAT_RGBA8)
	match gear_id:
		"cloth_wrap":
			_fill(image, Rect2i(1, 0, 8, 6), Color("#c8a870"))
			_fill(image, Rect2i(1, 2, 8, 1), Color("#8a6a3c"))
			_fill(image, Rect2i(1, 4, 8, 1), Color("#8a6a3c"))
		"tire_vest":
			_fill(image, Rect2i(0, 0, 10, 6), Color("#3a3a44"))
			for x in [2, 4, 6, 8]:
				_fill(image, Rect2i(x, 1, 1, 5), Color("#1e1e26"))
		"scrap_plate":
			_fill(image, Rect2i(0, 0, 10, 6), Color("#8a8a9e"))
			_fill(image, Rect2i(1, 1, 8, 4), Color("#b4b4c4"))
			for point in [Vector2i(1, 1), Vector2i(8, 1), Vector2i(1, 4), Vector2i(8, 4)]:
				image.set_pixelv(point, Color.WHITE)
		"riot_jacket":
			_fill(image, Rect2i(0, 0, 10, 6), Color("#4a78a8"))
			_fill(image, Rect2i(4, 0, 2, 6), Color("#14243c"))
			_fill(image, Rect2i(0, 3, 10, 1), Color("#d8782c"))
		_:
			_fill(image, Rect2i(1, 0, 8, 6), Color("#a0a0b0"))
	return ImageTexture.create_from_image(image)


static func _fill(image: Image, rect: Rect2i, color: Color) -> void:
	image.fill_rect(rect, color)


## Centred rows [start_x, width] from `top`, for domes.
static func _rows(image: Image, color: Color, rows: Array, top: int) -> void:
	for index in rows.size():
		image.fill_rect(Rect2i(rows[index][0], top + index, rows[index][1], 1), color)
