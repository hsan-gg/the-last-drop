extends Node
## Background music. Each place has its own track and they crossfade as you move
## between them; when zombies are hunting you, the combat track takes over and
## fades back once things are calm. Tracks live in assets/audio/music/.

const PATH_FORMAT := "res://assets/audio/music/%s.ogg"
const FADE_SECONDS := 1.4
const PLAYING_DB := -3.0
const SILENT_DB := -60.0
const COMBAT_TRACK := "combat"
## Seconds of calm before leaving the combat track.
const CALM_SECONDS := 4.0
const POLL_SECONDS := 0.4

var _players: Array[AudioStreamPlayer] = []
var _front := 0
var _current := ""
var _area_track := ""
var _calm_for := 0.0
var _poll := 0.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for _i in 2:
		var player := AudioStreamPlayer.new()
		player.bus = Settings.MUSIC_BUS
		# Web builds default to "sample" playback, which hands the sound straight
		# to the browser: later volume changes (our crossfade) and bus volumes
		# never reach it, so music faded in from silence stayed silent. Streamed
		# playback goes through Godot's own mixer, where fades and buses work.
		player.playback_type = AudioServer.PLAYBACK_TYPE_STREAM
		player.volume_db = SILENT_DB
		add_child(player)
		_players.append(player)


func current() -> String:
	return _current


func area_track() -> String:
	return _area_track


## Crossfades to a track. Unknown tracks and repeats are ignored.
func play(track: String, loop: bool = true) -> void:
	if track == _current:
		return
	var path := PATH_FORMAT % track
	if not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStream
	if stream is AudioStreamOggVorbis:
		stream.loop = loop
	var outgoing := _players[_front]
	_front = 1 - _front
	var incoming := _players[_front]
	incoming.stream = stream
	incoming.volume_db = SILENT_DB
	incoming.play()
	_current = track
	var fade := create_tween().set_parallel()
	fade.tween_property(incoming, "volume_db", PLAYING_DB, FADE_SECONDS)
	fade.tween_property(outgoing, "volume_db", SILENT_DB, FADE_SECONDS)
	fade.chain().tween_callback(outgoing.stop)


## The calm track for an area; combat music can still take over from it.
func play_area(area_id: String) -> void:
	_area_track = area_id
	_calm_for = CALM_SECONDS
	play(area_id)


func stop_area() -> void:
	_area_track = ""


## Pure decision used by the poll: should combat music be playing?
static func wants_combat(hunters: int, calm_seconds: float, in_combat: bool) -> bool:
	if hunters > 0:
		return true
	return in_combat and calm_seconds < CALM_SECONDS


func _process(delta: float) -> void:
	if _area_track.is_empty():
		return
	_poll -= delta
	if _poll > 0.0:
		return
	_poll = POLL_SECONDS
	var hunters := Combat.hunters()
	_calm_for = 0.0 if hunters > 0 else _calm_for + POLL_SECONDS
	if wants_combat(hunters, _calm_for, _current == COMBAT_TRACK):
		play(COMBAT_TRACK)
	elif _current == COMBAT_TRACK:
		play(_area_track)
