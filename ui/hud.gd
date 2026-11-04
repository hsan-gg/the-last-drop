class_name Hud
extends CanvasLayer
## In-game overlay: survival meters, inventory, current objective, interaction
## prompt, and the dialogue and sorting screens.

const DIALOGUE_SCENE := preload("res://ui/dialogue/dialogue_box.tscn")
const SORTING_SCENE := preload("res://ui/sorting/sorting_challenge.tscn")
const DROP_ICON := preload("res://assets/sprites/ui_drop.png")
const HEART_ICON := preload("res://assets/sprites/ui_heart.png")
const BOLT_ICON := preload("res://assets/sprites/ui_bolt.png")
const LOW_THRESHOLD := 0.2
const DAMAGE_FLASH_ALPHA := 0.35
const DAMAGE_FLASH_SECONDS := 0.3

## Which area's objectives to show; set by the area scene.
@export var area_id: String = "outpost"

var _water_meter: Meter
var _health_meter: Meter
var _stamina_meter: Meter
var _guard_meter: Meter
var _stamina_flash := 0.0
var _player_combat: PlayerCombat
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
var _feed: NotificationFeed
var _reward: RewardCard
var _area_title: AreaTitle
var _quick_label: Label
var _tip_panel: PanelContainer
var _tip_label: Label
var _tip_tween: Tween


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
	_feed = NotificationFeed.new()
	add_child(_feed)
	_reward = RewardCard.new()
	add_child(_reward)
	_feed.reward_card = _reward
	add_child(QuizPanel.new())
	add_child(PuzzlePanel.new())
	add_child(GameMenu.new())
	var travel := TravelPanel.new()
	travel.add_to_group("travel_panel")
	add_child(travel)

	EventBus.prompt_changed.connect(_on_prompt_changed)
	EventBus.flag_changed.connect(_refresh_objective.unbind(2))
	EventBus.survival_changed.connect(_on_survival_changed)
	EventBus.damage_taken.connect(_flash_damage)
	EventBus.xp_changed.connect(_on_xp_changed)
	EventBus.tip_requested.connect(_show_tip)
	EventBus.stamina_changed.connect(_on_stamina_changed)
	EventBus.stamina_denied.connect(func() -> void: _stamina_flash = 0.4)
	EventBus.level_up.connect(_on_level_up)
	EventBus.gear_changed.connect(_refresh_stats)
	EventBus.loot_found.connect(func(text: String) -> void: _feed.notify("loot", "", text))
	EventBus.xp_gained.connect(_feed.add_xp)
	EventBus.lives_changed.connect(_on_lives_changed)
	EventBus.life_lost.connect(_on_life_lost)
	EventBus.game_over.connect(_on_game_over)
	EventBus.quest_completed.connect(_on_quest_completed)
	Settings.changed.connect(_on_settings_changed.unbind(1))
	EventBus.inventory_changed.connect(_refresh_quick)

	_on_prompt_changed("")
	_refresh_objective()
	_on_survival_changed(Survival.water(), Survival.health())
	_on_xp_changed(Progress.level, Progress.xp, Progress.xp_needed())
	_refresh_stats()
	_on_lives_changed(Lives.lives)
	_refresh_quick()


func set_area(new_area_id: String) -> void:
	area_id = new_area_id
	# A new area is not an objective change: take its current goal silently.
	_objective_seen = false
	_last_objective_id = ""
	_last_objective_text = ""
	_refresh_objective()
	if _area_title != null:
		_area_title.show_area(new_area_id)


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


func _show_tip(text: String) -> void:
	_tip_label.text = text
	_tip_panel.visible = true
	_tip_panel.modulate.a = 1.0
	if _tip_tween != null:
		_tip_tween.kill()
	_tip_tween = create_tween()
	_tip_tween.tween_interval(6.0)
	_tip_tween.tween_property(_tip_panel, "modulate:a", 0.0, 0.6)
	_tip_tween.tween_callback(func() -> void: _tip_panel.visible = false)


func _on_stamina_changed(value: float, maximum: float) -> void:
	_stamina_meter.ratio = value / maxf(maximum, 1.0)


func _process(delta: float) -> void:
	_stamina_flash = maxf(_stamina_flash - delta, 0.0)
	if _player_combat == null:
		var player := get_tree().get_first_node_in_group("player") as Player
		_player_combat = player.combat if player != null else null
	if _player_combat != null:
		if _player_combat.is_blocking():
			_guard_meter.ratio = _player_combat.guard_hold_ratio()
			_guard_meter.fill_color = Color("#5fe0ff")
		else:
			_guard_meter.ratio = _player_combat.block_cooldown_ratio()
			_guard_meter.fill_color = Color("#5fe0ff") if _player_combat.block_ready() else Color("#e0a04a")
	if _stamina_flash > 0.0:
		_stamina_meter.fill_color = UiTheme.COLOR_RED
	else:
		_stamina_meter.fill_color = Color("#d8e04a") if _stamina_meter.ratio > 0.25 else Color("#e09a3a")


func _on_xp_changed(level: int, xp: int, needed: int) -> void:
	_level_label.text = "LV %d" % level
	_xp_meter.ratio = float(xp) / float(maxi(needed, 1))
	_refresh_stats()


func _refresh_stats() -> void:
	var damage := CombatRules.player_damage(Gear.weapon_damage(), Progress.level)
	_stats_label.text = "ATK %d  DEF %d" % [damage, Gear.armor()]


func _on_level_up(level: int) -> void:
	EventBus.reward_requested.emit("level", "LEVEL %d" % level, "Max health +%d, sword damage +1, stamina +%d. You feel restored." % [roundi(ProgressionRules.max_health(level) - ProgressionRules.max_health(level - 1)), int(PlayerCombat.STAMINA_PER_LEVEL)])


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
		_feed.notify("objective_done", "Done!", _last_objective_text)
	if not new_text.is_empty():
		_feed.notify("objective_new", "New objective", new_text)
		_tracker.mark_new()


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
			_feed.notify("quest", "Quest complete", quest["title"])
	_tracker.refresh()


func _on_settings_changed() -> void:
	_tracker.refresh()
	_refresh_quick()


func _refresh_quick() -> void:
	var heal := Inventory.count("bandage") + Inventory.count("energy_bar")
	var water := Inventory.count("purified_water")
	_quick_label.text = "%s heal x%d   %s water x%d" % [Settings.key_label("quick_heal"), heal, Settings.key_label("quick_drink"), water]
	_quick_label.modulate.a = 1.0 if heal + water > 0 else 0.35


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("quick_heal"):
		Consumables.use_first(Consumables.HEAL_ORDER)
	elif event.is_action_pressed("quick_drink"):
		Consumables.use_first(Consumables.DRINK_ORDER)


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
	_stamina_meter = _add_meter_row(left, BOLT_ICON)
	_stamina_meter.fill_color = Color("#d8e04a")
	_guard_meter = Meter.new()
	_guard_meter.custom_minimum_size = Vector2(22, 5)
	_guard_meter.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_guard_meter.fill_color = Color("#5fe0ff")
	_guard_meter.tooltip_text = "Guard"
	_stamina_meter.get_parent().add_child(_guard_meter)
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
	_quick_label = Label.new()
	_quick_label.add_theme_font_size_override("font_size", 8)
	_quick_label.add_theme_color_override("font_color", UiTheme.COLOR_MUTED)
	left.add_child(_quick_label)
	_lives_row = HBoxContainer.new()
	_lives_row.add_theme_constant_override("separation", 2)
	_lives_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for _i in Lives.max_lives:
		var heart := TextureRect.new()
		heart.texture = HEART_ICON
		heart.stretch_mode = TextureRect.STRETCH_KEEP
		_lives_icons.append(heart)
		_lives_row.add_child(heart)
	left.add_child(_lives_row)
	left.add_child(RuneBar.new())
	root.add_child(BossBar.new())
	root.add_child(ChallengeTimer.new())
	_area_title = AreaTitle.new()
	root.add_child(_area_title)

	_tip_panel = PanelContainer.new()
	_tip_panel.add_theme_stylebox_override("panel", UiTheme.banner_style())
	_tip_panel.anchor_left = 1.0
	_tip_panel.anchor_right = 1.0
	_tip_panel.anchor_top = 1.0
	_tip_panel.anchor_bottom = 1.0
	_tip_panel.offset_left = -200.0
	_tip_panel.offset_right = -8.0
	_tip_panel.offset_top = -78.0
	_tip_panel.offset_bottom = -44.0
	_tip_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tip_panel.visible = false
	root.add_child(_tip_panel)
	var tip_row := HBoxContainer.new()
	tip_row.add_theme_constant_override("separation", 6)
	_tip_panel.add_child(tip_row)
	var tip_tag := Label.new()
	tip_tag.text = "TIP"
	tip_tag.add_theme_color_override("font_color", UiTheme.COLOR_YELLOW)
	tip_row.add_child(tip_tag)
	_tip_label = Label.new()
	_tip_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tip_label.custom_minimum_size = Vector2(150, 0)
	tip_row.add_child(_tip_label)

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
