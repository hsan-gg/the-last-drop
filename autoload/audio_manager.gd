extends Node
## Sound effects (by name, via EventBus.sfx_requested), the ambient loop, and a
## mute toggle on the M key. Missing files are skipped, so audio is optional.

const SFX_PATH_FORMAT := "res://assets/audio/sfx/%s.wav"
const SFX_VOICES := 6

var _voices: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _muted := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in SFX_VOICES:
		var voice := AudioStreamPlayer.new()
		voice.bus = Settings.SFX_BUS
		add_child(voice)
		_voices.append(voice)
	EventBus.sfx_requested.connect(play)


func is_muted() -> bool:
	return _muted


func set_muted(muted: bool) -> void:
	_muted = muted
	AudioServer.set_bus_mute(AudioServer.get_bus_index("Master"), muted)


func play(sfx_name: String) -> void:
	var stream := _stream_for(sfx_name)
	if stream == null:
		return
	for voice in _voices:
		if not voice.playing:
			voice.stream = stream
			voice.play()
			return


func _stream_for(sfx_name: String) -> AudioStream:
	if not _streams.has(sfx_name):
		var path := SFX_PATH_FORMAT % sfx_name
		_streams[sfx_name] = load(path) if ResourceLoader.exists(path) else null
	return _streams[sfx_name]
