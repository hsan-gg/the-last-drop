extends Node
## Sound effects (by name, via EventBus.sfx_requested), the ambient loop, and a
## mute toggle on the M key. Missing files are skipped, so audio is optional.
## Every button in the game clicks when pressed and ticks when the selection
## moves onto it, without each screen having to ask.

const SFX_PATH_FORMAT := "res://assets/audio/sfx/%s.wav"
const SFX_VOICES := 10
const BUTTON_PRESS_SOUND := "click"
const BUTTON_FOCUS_SOUND := "ui_move"
## Opening a panel moves focus onto its first button: that is not the player
## moving the selection, so stay quiet for a moment after a button appears.
const FOCUS_QUIET_MSEC := 150

var _voices: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _muted := false
var _next_voice := 0
var _last_button_added_msec := -100000
var played: Array[String] = []  ## the last few sounds, newest last (for tests)


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in SFX_VOICES:
		var voice := AudioStreamPlayer.new()
		voice.bus = Settings.SFX_BUS
		add_child(voice)
		_voices.append(voice)
	EventBus.sfx_requested.connect(play)
	get_tree().node_added.connect(_on_node_added)


func is_muted() -> bool:
	return _muted


func set_muted(muted: bool) -> void:
	_muted = muted
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)


func play(sfx_name: String, pitch: float = 1.0) -> void:
	played.append(sfx_name)
	if played.size() > 16:
		played.remove_at(0)
	var stream := _stream_for(sfx_name)
	if stream == null:
		return
	var voice := _free_voice()
	voice.stream = stream
	voice.pitch_scale = clampf(pitch, 0.25, 4.0)
	voice.play()


## A free voice, or the one that started longest ago: a busy fight should cut
## its oldest sound, not drop the newest.
func _free_voice() -> AudioStreamPlayer:
	for voice in _voices:
		if not voice.playing:
			return voice
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % _voices.size()
	return voice


func _stream_for(sfx_name: String) -> AudioStream:
	if not _streams.has(sfx_name):
		var path := SFX_PATH_FORMAT % sfx_name
		_streams[sfx_name] = load(path) if ResourceLoader.exists(path) else null
	return _streams[sfx_name]


func _on_node_added(node: Node) -> void:
	var button := node as BaseButton
	if button == null or button.has_meta("silent"):
		return
	_last_button_added_msec = Time.get_ticks_msec()
	button.pressed.connect(play.bind(BUTTON_PRESS_SOUND))
	button.focus_entered.connect(_on_button_focused)


func _on_button_focused() -> void:
	if Time.get_ticks_msec() - _last_button_added_msec < FOCUS_QUIET_MSEC:
		return
	play(BUTTON_FOCUS_SOUND)
