extends Node
## What the game does about living in a browser tab, mostly on phones, where
## the app is put away all the time: a call comes in, the screen locks, the
## player swipes to another app.
##
## When the page is hidden the run is saved at once (a phone may throw the tab
## away without warning), the pause menu opens so nothing attacks while you
## are gone, and the sound goes quiet. When the installed app (PWA) has a new
## version waiting, it says so, and the title screen offers to load it.

signal update_ready

var _hidden := false
var _update_waiting := false
## Kept alive for as long as the page listens to it (JavaScriptBridge needs that).
var _visibility_callback: JavaScriptObject


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if not OS.has_feature("web"):
		return
	var document := JavaScriptBridge.get_interface("document")
	if document != null:
		_visibility_callback = JavaScriptBridge.create_callback(_on_visibility_change)
		document.addEventListener("visibilitychange", _visibility_callback)
	JavaScriptBridge.pwa_update_available.connect(_on_pwa_update_available)


func is_hidden() -> bool:
	return _hidden


func has_update() -> bool:
	return _update_waiting


## Loads the waiting version (the page reloads).
func apply_update() -> void:
	if _update_waiting and OS.has_feature("web"):
		JavaScriptBridge.pwa_update()


## The tab or app was put away.
func on_page_hidden() -> void:
	if _hidden:
		return
	_hidden = true
	TouchControls.release_all()
	SaveGame.save_now()
	_open_pause_menu()
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), true)


## It came back.
func on_page_shown() -> void:
	if not _hidden:
		return
	_hidden = false
	Settings.apply_audio()  # back to the volume and mute the player chose


func _on_visibility_change(_args: Array) -> void:
	var document := JavaScriptBridge.get_interface("document")
	if document == null:
		return
	if str(document.visibilityState) == "hidden":
		on_page_hidden()
	else:
		on_page_shown()


func _notification(what: int) -> void:
	# Phones also report the app losing focus (a call, the notification shade).
	if what == NOTIFICATION_APPLICATION_PAUSED:
		on_page_hidden()
	elif what == NOTIFICATION_APPLICATION_RESUMED:
		on_page_shown()


func _open_pause_menu() -> void:
	var tree := get_tree()
	if tree.paused or Modal.any_open(tree) or not tree.current_scene is GameArea:
		return
	for menu in tree.get_nodes_in_group("modal"):
		if menu is GameMenu and not (menu as GameMenu).title_mode:
			(menu as GameMenu).open()
			return


func _on_pwa_update_available() -> void:
	_update_waiting = true
	update_ready.emit()
	EventBus.tip_requested.emit("A new version of the game is ready. It loads from the title screen.")
