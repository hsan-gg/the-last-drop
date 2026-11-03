extends GutTest
## The menu tabs: inventory board, quest board, options and controls, and the
## menu shell that hosts them.

const TEST_SETTINGS_PATH := "user://test_settings.cfg"

var _original_path := ""


func before_each() -> void:
	_original_path = Settings.path
	Settings.path = TEST_SETTINGS_PATH
	Settings.reset_all()
	Survival.set_process(false)
	Survival.reset()
	Gear.reset()
	Progress.reset()
	GameState.reset()
	Inventory.clear()
	MapMemory.reset()
	Lives.reset()


func after_each() -> void:
	Settings.reset_all()
	Settings.path = _original_path
	DirAccess.remove_absolute(ProjectSettings.globalize_path(TEST_SETTINGS_PATH))
	Survival.reset()
	Survival.set_process(true)
	Gear.reset()
	Progress.reset()
	Inventory.clear()
	get_tree().paused = false


func _key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code as Key
	event.pressed = true
	return event


# ------------------------------------------------------------- inventory

func _inventory() -> InventoryTab:
	var tab := InventoryTab.new()
	add_child_autofree(tab)
	tab.refresh()
	return tab


func test_the_backpack_lists_gear_then_consumables_then_materials() -> void:
	Gear.grant("rusty_sword")
	Gear.grant("hard_hat")
	Inventory.add("scrap_metal")
	Inventory.add("bandage")
	var kinds: Array[String] = []
	for entry in _inventory().entries():
		kinds.append(entry["id"])
	assert_eq(kinds, ["rusty_sword", "hard_hat", "bandage", "scrap_metal"] as Array[String])


func test_fists_are_not_a_backpack_item() -> void:
	Gear.grant("rusty_sword")
	var ids: Array[String] = []
	for entry in _inventory().entries():
		ids.append(entry["id"])
	assert_false(ids.has("fists"))
	assert_true(ids.has("rusty_sword"))


func test_activating_gear_wears_it() -> void:
	Gear.grant("scrap_blade")
	Gear.grant("rusty_sword")
	var tab := _inventory()
	var index := -1
	for position in tab.entries().size():
		if tab.entries()[position]["id"] == "rusty_sword":
			index = position
	assert_eq(tab.activate(index), "equipped")
	assert_eq(Gear.equipped("weapon"), "rusty_sword")


func test_activating_worn_armor_takes_it_off() -> void:
	Gear.grant("hard_hat")
	var tab := _inventory()
	assert_eq(tab.activate(0), "unequipped")
	assert_eq(Gear.equipped("head"), "")


func test_the_weapon_cannot_be_taken_off() -> void:
	Gear.grant("rusty_sword")
	assert_eq(_inventory().activate(0), "kept")
	assert_eq(Gear.equipped("weapon"), "rusty_sword")


func test_using_a_bandage_heals_and_uses_it_up() -> void:
	Survival.damage(40.0)
	Inventory.add("bandage")
	var tab := _inventory()
	assert_eq(tab.activate(0), "used")
	assert_eq(Survival.health(), 60.0 + 30.0)
	assert_false(Inventory.has("bandage"))


func test_a_bandage_is_kept_when_health_is_full() -> void:
	Inventory.add("bandage")
	assert_eq(_inventory().activate(0), "unused")
	assert_true(Inventory.has("bandage"))


func test_materials_are_not_usable() -> void:
	Inventory.add("scrap_metal")
	assert_eq(_inventory().activate(0), "material")


func test_the_cursor_stays_inside_the_grid() -> void:
	for item_id in ["scrap_metal", "pipe_section", "cardboard", "glass_jar", "tin_can", "textile_scrap", "charcoal", "kettle", "sand_sack", "plastic_bottle", "copper_wire"]:
		Inventory.add(item_id)
	var tab := _inventory()
	tab.move_cursor(-1, 0)
	tab.move_cursor(0, -1)
	assert_eq(tab.cursor(), 0)
	tab.move_cursor(1, 0)
	tab.move_cursor(0, 1)
	assert_eq(tab.cursor(), InventoryTab.COLUMNS + 1)


# ------------------------------------------------------------- quests

func _quests() -> QuestsTab:
	var tab := QuestsTab.new()
	add_child_autofree(tab)
	GameState.set_flag("area_outpost_reached")
	GameState.set_flag("area_factory_reached")
	tab.refresh()
	return tab


func test_here_shows_only_this_areas_open_quests_easiest_first() -> void:
	var tab := _quests()
	var shown := tab.quests_to_show("outpost")
	assert_gt(shown.size(), 0)
	var rank := -1
	for quest in shown:
		assert_eq(quest["area"], "outpost")
		var this_rank: int = QuestRules.DIFFICULTY_ORDER[quest["difficulty"]]
		assert_gte(this_rank, rank)
		rank = this_rank


func test_all_includes_other_areas_and_done_shows_finished_ones() -> void:
	var tab := _quests()
	tab.set_filter(QuestsTab.Filter.ALL)
	var areas := {}
	for quest in tab.quests_to_show("outpost"):
		areas[quest["area"]] = true
	assert_gt(areas.size(), 1)
	GameState.add_to_counter("kills")
	tab.set_filter(QuestsTab.Filter.DONE)
	var done_ids: Array[String] = []
	for quest in tab.quests_to_show("outpost"):
		done_ids.append(quest["id"])
	assert_true(done_ids.has("first_blood"))


func test_the_filter_cycles() -> void:
	var tab := _quests()
	tab.cycle_filter()
	assert_eq(tab.filter(), QuestsTab.Filter.ALL)
	tab.cycle_filter()
	tab.cycle_filter()
	assert_eq(tab.filter(), QuestsTab.Filter.HERE)


# ------------------------------------------------------------- map

func test_the_map_scales_to_fit_its_space() -> void:
	var tab := MapTab.new()
	add_child_autofree(tab)
	assert_eq(tab.cell_size(Vector2i(46, 30), Vector2(330, 170)), 5)
	assert_eq(tab.cell_size(Vector2i(0, 0), Vector2(330, 170)), 1)


func test_walking_reveals_the_map() -> void:
	assert_false(MapMemory.is_seen("outpost", Vector2i(10, 10)))
	MapMemory.reveal("outpost", Vector2i(10, 10), 3)
	assert_true(MapMemory.is_seen("outpost", Vector2i(10, 10)))
	assert_true(MapMemory.is_seen("outpost", Vector2i(12, 10)))
	assert_false(MapMemory.is_seen("outpost", Vector2i(20, 10)))
	assert_false(MapMemory.is_seen("factory", Vector2i(10, 10)), "each area keeps its own memory")
	assert_true(MapMemory.has_visited("outpost"))
	assert_gt(MapMemory.fraction_seen("outpost", 1000), 0.0)


# ------------------------------------------------------------- options

func test_volume_steps_and_clamps_and_is_saved() -> void:
	var tab := OptionsTab.new()
	add_child_autofree(tab)
	tab.step_volume("music", -1)
	assert_almost_eq(float(Settings.value("music")), 0.5, 0.001)
	for _i in 20:
		tab.step_volume("music", 1)
	assert_eq(float(Settings.value("music")), 1.0)
	for _i in 20:
		tab.step_volume("music", -1)
	assert_eq(float(Settings.value("music")), 0.0)
	assert_true(FileAccess.file_exists(TEST_SETTINGS_PATH), "options are saved as they change")


func test_toggles_and_cycles_change_the_setting() -> void:
	var tab := OptionsTab.new()
	add_child_autofree(tab)
	tab.toggle("screen_shake")
	assert_false(Settings.value("screen_shake"))
	tab.cycle("objective_hints", 3)
	assert_eq(Settings.value("objective_hints"), Settings.HINTS_STRONG)
	tab.cycle("objective_hints", 3)
	assert_eq(Settings.value("objective_hints"), Settings.HINTS_OFF)


func test_settings_survive_a_save_and_reload() -> void:
	Settings.set_value("sfx", 0.3)
	Settings.set_value("text_speed", 2)
	Settings.rebind("attack", KEY_F)
	Settings.reset_all()
	Settings.set_value("sfx", 0.3)
	Settings.set_value("text_speed", 2)
	Settings.rebind("attack", KEY_F)
	Settings._values = Settings.DEFAULTS.duplicate()
	Settings._keys.clear()
	Settings.load_settings()
	assert_almost_eq(float(Settings.value("sfx")), 0.3, 0.001)
	assert_eq(Settings.text_speed_multiplier(), Settings.TEXT_SPEEDS[2])
	assert_eq(Settings.key_for("attack"), KEY_F)


func test_reducing_screen_shake_reaches_juicee() -> void:
	Settings.set_value("screen_shake", false)
	assert_true(Juicee.accessibility.no_screenshake)
	Settings.set_value("screen_shake", true)
	assert_false(Juicee.accessibility.no_screenshake)


# ------------------------------------------------------------- controls

func test_rebinding_an_action_changes_its_key() -> void:
	var tab := ControlsTab.new()
	add_child_autofree(tab)
	tab.begin_capture("attack")
	assert_true(tab.is_capturing())
	tab.tab_input(_key(KEY_F))
	assert_false(tab.is_capturing())
	assert_eq(Settings.key_for("attack"), KEY_F)
	assert_eq(Settings.key_label("attack"), "F")


func test_escape_cancels_a_rebind() -> void:
	var tab := ControlsTab.new()
	add_child_autofree(tab)
	var before := Settings.key_for("attack")
	tab.begin_capture("attack")
	tab.tab_input(_key(KEY_ESCAPE))
	assert_false(tab.is_capturing())
	assert_eq(Settings.key_for("attack"), before)


func test_a_key_in_use_swaps_instead_of_doubling_up() -> void:
	var attack_key := Settings.key_for("attack")
	var block_key := Settings.key_for("block")
	Settings.rebind("attack", block_key)
	assert_eq(Settings.key_for("attack"), block_key)
	assert_eq(Settings.key_for("block"), attack_key, "the other action takes the old key")


func test_resetting_controls_restores_the_defaults() -> void:
	var original := Settings.key_for("map")
	Settings.rebind("map", KEY_F7)
	Settings.reset_controls()
	assert_eq(Settings.key_for("map"), original)


# ------------------------------------------------------------- the menu shell

func _menu(title_mode: bool = false) -> GameMenu:
	var menu := GameMenu.new()
	menu.title_mode = title_mode
	menu.pauses_game = false
	add_child_autofree(menu)
	return menu


func test_the_menu_opens_on_the_requested_tab_and_closes() -> void:
	var menu := _menu()
	menu.open(GameMenu.MAP)
	assert_true(menu.is_open())
	assert_eq(menu.current_tab_id(), GameMenu.MAP)
	menu.close()
	assert_false(menu.is_open())


func test_toggling_the_same_tab_closes_and_another_tab_switches() -> void:
	var menu := _menu()
	menu.toggle(GameMenu.QUESTS)
	assert_eq(menu.current_tab_id(), GameMenu.QUESTS)
	menu.toggle(GameMenu.INVENTORY)
	assert_true(menu.is_open())
	assert_eq(menu.current_tab_id(), GameMenu.INVENTORY)
	menu.toggle(GameMenu.INVENTORY)
	assert_false(menu.is_open())


func test_tab_cycles_through_every_page() -> void:
	var menu := _menu()
	menu.open(GameMenu.INVENTORY)
	var seen: Array[String] = []
	for _i in 6:
		seen.append(menu.current_tab_id())
		menu.next_tab()
	assert_eq(seen, ["inventory", "quests", "codex", "map", "options", "controls"] as Array[String])
	assert_eq(menu.current_tab_id(), GameMenu.INVENTORY, "wraps around")


func test_the_title_menu_has_only_options_and_controls() -> void:
	var menu := _menu(true)
	menu.open()
	assert_eq(menu.current_tab_id(), GameMenu.OPTIONS)
	assert_null(menu.tab(GameMenu.INVENTORY))
	assert_not_null(menu.tab(GameMenu.CONTROLS))


# ------------------------------------------------------------- codex

func test_lessons_unlock_as_they_are_met() -> void:
	var tab := CodexTab.new()
	add_child_autofree(tab)
	assert_eq(CodexTab.discovered_count(), 0)
	GameState.set_flag("lesson_seen_battery_leak")
	assert_true(CodexTab.is_discovered("battery_leak"))
	assert_eq(CodexTab.discovered_count(), 1)
	assert_eq(tab.lesson_ids()[0], "battery_leak", "discovered lessons come first")


func test_the_codex_has_a_card_for_every_lesson() -> void:
	var tab := CodexTab.new()
	add_child_autofree(tab)
	assert_eq(tab.lesson_ids().size(), Content.all_lessons().size())


func test_testing_water_teaches_lessons() -> void:
	var point: SamplePoint = preload("res://world/sample_point.tscn").instantiate()
	point.sample_id = "b"
	point.dialogue_id = "sample_b"
	add_child_autofree(point)
	point.interact(null)
	assert_true(CodexTab.is_discovered("runoff"))


func test_discovering_lessons_completes_the_student_quest() -> void:
	for lesson_id in ["battery_leak", "chemical_leak", "plastic_reuse", "material_reuse", "glass_general"]:
		GameState.set_flag("lesson_seen_%s" % lesson_id)
	assert_true(QuestRules.is_done("student"))
