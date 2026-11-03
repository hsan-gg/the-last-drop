class_name Hud
extends CanvasLayer
## In-game overlay: survival meters, inventory, current objective, interaction
## prompt, and the dialogue and sorting screens.

const DIALOGUE_SCENE := preload("res://ui/dialogue/dialogue_box.tscn")
const SORTING_SCENE := preload("res://ui/sorting/sorting_challenge.tscn")
const DROP_ICON := preload("res://assets/sprites/ui_drop.png")
const HEART_ICON := preload("res://assets/sprites/ui_heart.png")
const LOW_THRESHOLD := 0.2
const DAMAGE_FLASH_ALPHA := 0.35
const DAMAGE_FLASH_SECONDS := 0.3

## Which area's objectives to show; set by the area scene.
@export var area_id: String = "outpost"

var _water_meter: Meter
var _health_meter: Meter
var _prompt_panel: PanelContainer
var _prompt_label: Label
var _damage_flash: ColorRect
var _last_objective_id := ""
var _last_objective_text := ""
var _objective_seen := false
var _tracker: ObjectiveTracker
var _lives_row: HBoxContainer
var _lives_icons: Array[TextureRect] = []
var _banners: BannerQueue
var _level_label: Label
var _xp_meter: Meter
var _stats_label: Label
var _toast_label: Label
var _toast_tween: Tween


func _ready() -> void:
	layer = 10
	_build()
	add_child(DIALOGUE_SCENE.instantiate())
	add_child(SORTING_SCENE.instantiate())
	add_child(ObjectiveBeacon.new())
	_banners = BannerQueue.new()
	add_child(_banners)
	_tracker = ObjectiveTracker.new()
	add_child(_tracker)
	add_child(QuizPanel.new())
	add_child(PuzzlePanel.new())
	add_child(GameMenu.new())

	EventBus.prompt_changed.connect(_on_prompt_changed)
	EventBus.flag_changed.connect(_refresh_objective.unbind(2))
	EventBus.survival_changed.connect(_on_survival_changed)
	EventBus.damage_taken.connect(_flash_damage)
	EventBus.xp_changed.connect(_on_xp_changed)
	EventBus.level_up.connect(_on_level_up)
	EventBus.gear_changed.connect(_refresh_stats)
	EventBus.loot_found.connect(_show_toast.bind(UiTheme.COLOR_GREEN))
	EventBus.lives_changed.connect(_on_lives_changed)
	EventBus.life_lost.connect(_on_life_lost)
	EventBus.game_over.connect(_on_game_over)
	EventBus.quest_completed.connect(_on_quest_completed)
	Settings.changed.connect(_on_settings_changed.unbind(1))

	_on_prompt_changed("")
	_refresh_objective()
	_on_survival_changed(Survival.water(), Survival.health())
	_on_xp_changed(Progress.level, Progress.xp, Progress.xp_needed())
	_refresh_stats()
	_on_lives_changed(Lives.lives)


func set_area(new_area_id: String) -> void:
	area_id = new_area_id
	_refresh_objective()


func _flash_damage(amount: float) -> void:
	# A scratch barely tints the screen; a heavy hit washes it red.
	_damage_flash.modulate.a = clampf(amount / 45.0, 0.06, DAMAGE_FLASH_ALPHA)
	var tween := create_tween()
	tween.tween_property(_damage_flash, "modulate:a", 0.0, DAMAGE_FLASH_SECONDS)


func _on_prompt_changed(text: String) -> void:
	_prompt_panel.visible = not text.is_empty()
	_prompt_label.text = "[E] %s" % text


func _on_survival_changed(water: float, health: float) -> void:
	_water_meter.ratio = water / Survival.MAX_VALUE
	_health_meter.ratio = health / Survival.max_health()
	_water_meter.fill_color = UiTheme.COLOR_RED if _water_meter.ratio < LOW_THRESHOLD else UiTheme.COLOR_WATER
	_health_meter.fill_color = UiTheme.COLOR_RED if _health_meter.ratio < LOW_THRESHOLD else UiTheme.COLOR_GREEN


func _on_xp_changed(level: int, xp: int, needed: int) -> void:
	_level_label.text = "LV %d" % level
	_xp_meter.ratio = float(xp) / float(maxi(needed, 1))
	_refresh_stats()


func _refresh_stats() -> void:
	var damage := CombatRules.player_damage(Gear.weapon_damage(), Progress.level)
	_stats_label.text = "ATK %d  DEF %d" % [damage, Gear.armor()]


func _on_level_up(level: int) -> void:
	_show_toast("LEVEL UP!  You are level %d" % level, UiTheme.COLOR_YELLOW)
	var flash := create_tween()
	_damage_flash.color = UiTheme.COLOR_YELLOW
	_damage_flash.modulate.a = 0.45
	flash.tween_property(_damage_flash, "modulate:a", 0.0, 0.6)
	flash.tween_callback(func() -> void: _damage_flash.color = UiTheme.COLOR_RED)


## A line of text that appears under the banner and fades: loot, level ups.
func _show_toast(text: String, color: Color) -> void:
	_toast_label.text = text
	_toast_label.add_theme_color_override("font_color", color)
	_toast_label.visible = true
	_toast_label.modulate.a = 1.0
	if _toast_tween != null:
		_toast_tween.kill()
	_toast_tween = create_tween()
	_toast_tween.tween_interval(2.0)
	_toast_tween.tween_property(_toast_label, "modulate:a", 0.0, 0.5)
	_toast_tween.tween_callback(func() -> void: _toast_label.visible = false)


func _refresh_objective() -> void:
	var objective := ObjectivesTracker.current(area_id)
	var objective_id: String = objective.get("id", "")
	var text: String = objective.get("text", "")
	if objective_id != _last_objective_id:
		if _objective_seen:
			_announce_change(text)
		_last_objective_id = objective_id
		_last_objective_text = text
		_objective_seen = true
	_tracker.refresh()


## "OBJECTIVE COMPLETE" then "NEW OBJECTIVE", each as a banner, and the tracker
## slides in briefly so the next step is easy to find again.
func _announce_change(new_text: String) -> void:
	if not _last_objective_text.is_empty():
		_banners.push("OBJECTIVE COMPLETE", _last_objective_text, UiTheme.COLOR_GREEN, 2.0)
		EventBus.sfx_requested.emit("sort_ok")
	if not new_text.is_empty():
		_banners.push("NEW OBJECTIVE", new_text, UiTheme.COLOR_ORANGE, 2.6)
	_tracker.flash()


func _on_lives_changed(lives: int) -> void:
	for index in _lives_icons.size():
		_lives_icons[index].modulate = Color.WHITE if index < lives else Color(0.25, 0.2, 0.22, 0.8)


func _on_game_over() -> void:
	SceneManager.go_to_game_over()


func _on_life_lost(lives_left: int) -> void:
	_banners.push("LIFE LOST", "%d %s left. You wake at the start of the area." % [lives_left, "life" if lives_left == 1 else "lives"], UiTheme.COLOR_RED, 3.0)


func _on_quest_completed(quest_id: String) -> void:
	for quest: Dictionary in Content.quests():
		if quest["id"] == quest_id:
			var reward: Dictionary = quest.get("reward", {})
			_banners.push("QUEST COMPLETE", "%s   +%d XP" % [quest["title"], int(reward.get("xp", 0))], UiTheme.COLOR_YELLOW, 3.0)
	_tracker.refresh()


func _on_settings_changed() -> void:
	_tracker.refresh()


func _build() -> void:
	var root := Control.new()
	root.theme = UiTheme.get_theme()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_damage_flash = ColorRect.new()
	_damage_flash.color = UiTheme.COLOR_RED
	_damage_flash.modulate.a = 0.0
	_damage_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damage_flash.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(_damage_flash)

	var left := VBoxContainer.new()
	left.position = Vector2(6, 6)
	left.add_theme_constant_override("separation", 3)
	left.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(left)
	_water_meter = _add_meter_row(left, DROP_ICON)
	_health_meter = _add_meter_row(left, HEART_ICON)
	var level_row := HBoxContainer.new()
	level_row.add_theme_constant_override("separation", 4)
	level_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_level_label = Label.new()
	_level_label.add_theme_color_override("font_color", UiTheme.COLOR_YELLOW)
	level_row.add_child(_level_label)
	_xp_meter = Meter.new()
	_xp_meter.fill_color = UiTheme.COLOR_YELLOW
	_xp_meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_xp_meter.custom_minimum_size = Vector2(54, 5)
	level_row.add_child(_xp_meter)
	left.add_child(level_row)
	_stats_label = Label.new()
	_stats_label.add_theme_font_size_override("font_size", 8)
	_stats_label.add_theme_color_override("font_color", UiTheme.COLOR_MUTED)
	left.add_child(_stats_label)
	_lives_row = HBoxContainer.new()
	_lives_row.add_theme_constant_override("separation", 2)
	_lives_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for _i in Lives.MAX_LIVES:
		var heart := TextureRect.new()
		heart.texture = HEART_ICON
		heart.stretch_mode = TextureRect.STRETCH_KEEP
		_lives_icons.append(heart)
		_lives_row.add_child(heart)
	left.add_child(_lives_row)

	_toast_label = Label.new()
	_toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast_label.add_theme_color_override("font_outline_color", Color("#1a1008"))
	_toast_label.add_theme_constant_override("outline_size", 4)
	_toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast_label.offset_left = -150.0
	_toast_label.offset_right = 150.0
	_toast_label.offset_top = 78.0
	_toast_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_toast_label.visible = false
	root.add_child(_toast_label)

	_prompt_panel = PanelContainer.new()
	_prompt_panel.anchor_left = 0.5
	_prompt_panel.anchor_right = 0.5
	_prompt_panel.anchor_top = 1.0
	_prompt_panel.anchor_bottom = 1.0
	_prompt_panel.offset_left = -130.0
	_prompt_panel.offset_right = 130.0
	_prompt_panel.offset_top = -32.0
	_prompt_panel.offset_bottom = -8.0
	_prompt_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_prompt_panel)
	_prompt_label = Label.new()
	_prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_prompt_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_prompt_panel.add_child(_prompt_label)


func _add_meter_row(parent: Control, icon: Texture2D) -> Meter:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 4)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var icon_rect := TextureRect.new()
	icon_rect.texture = icon
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP
	icon_rect.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon_rect)
	var meter := Meter.new()
	meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	meter.custom_minimum_size = Vector2(72, 7)
	row.add_child(meter)
	parent.add_child(row)
	return meter
