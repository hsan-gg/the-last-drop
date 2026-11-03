extends Node
## Sound effects (by name, via EventBus.sfx_requested), the ambient loop, and a
## mute toggle on the M key. Missing files are skipped, so audio is optional.

const SFX_PATH_FORMAT := "res://assets/audio/sfx/%s.wav"
const AMBIENT_PATH := "res://assets/audio/ambient.ogg"
const SFX_VOICES := 6
const AMBIENT_VOLUME_DB := -10.0

var _voices: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _muted := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in SFX_VOICES:
		var voice := AudioStreamPlayer.new()
		add_child(voice)
		_voices.append(voice)
	EventBus.sfx_requested.connect(play)
	_start_ambient()


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


func _unhandled_input(event: InputEvent) -> void:
	var key := event as InputEventKey
	if key != null and key.pressed and not key.echo and key.keycode == KEY_M:
		set_muted(not _muted)


func _stream_for(sfx_name: String) -> AudioStream:
	if not _streams.has(sfx_name):
		var path := SFX_PATH_FORMAT % sfx_name
		_streams[sfx_name] = load(path) if ResourceLoader.exists(path) else null
	return _streams[sfx_name]


func _start_ambient() -> void:
	if not ResourceLoader.exists(AMBIENT_PATH):
		return
	var stream: AudioStream = load(AMBIENT_PATH)
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	var ambient := AudioStreamPlayer.new()
	ambient.stream = stream
	ambient.volume_db = AMBIENT_VOLUME_DB
	add_child(ambient)
	ambient.play()
