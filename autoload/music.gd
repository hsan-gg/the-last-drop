extends Node
## Background music. Each place has its own track and they crossfade as you move
## between them; when zombies are hunting you, the combat track takes over and
## fades back once things are calm. Tracks live in assets/audio/music/.

const PATH_FORMAT := "res://assets/audio/music/%s.ogg"
const FADE_SECONDS := 1.4
const PLAYING_DB := -3.0
const SILENT_DB := -60.0
const COMBAT_TRACK := "combat"
## Seconds of calm before leaving the combat track: short, so the fight music
## stops soon after the fight does instead of droning on.
const CALM_SECONDS := 1.2
## The fight is over: the combat track drops away quickly.
const COMBAT_EXIT_FADE := 0.6
const POLL_SECONDS := 0.4

var _players: Array[AudioStreamPlayer] = []
var _front := 0
var _current := ""
var _area_track := ""
var _calm_for := 0.0
var _poll := 0.0
var _fade: Tween
## Where each track was when it faded out, so the area music picks up where it
## left off after a fight instead of starting over.
var _resume_at: Dictionary = {}


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
func play(track: String, loop: bool = true, fade_seconds: float = FADE_SECONDS) -> void:
	if track == _current:
		return
	var path := PATH_FORMAT % track
	if not ResourceLoader.exists(path):
		return
	var stream := load(path) as AudioStream
	if stream is AudioStreamOggVorbis:
		stream.loop = loop
	var outgoing := _players[_front]
	if outgoing.playing and not _current.is_empty():
		_resume_at[_current] = outgoing.get_playback_position()
	_front = 1 - _front
	var incoming := _players[_front]
	# A crossfade still running (a fight shorter than the fade) must not go on
	# to stop the player that is now coming back in: that silenced the music.
	if _fade != null and _fade.is_valid():
		_fade.kill()
	if not (incoming.playing and incoming.stream == stream):
		# (Still fading out the same track: let it carry on and simply fade back up.)
		incoming.stream = stream
		incoming.volume_db = SILENT_DB
		incoming.play(_resume_position(track, stream))
	_current = track
	_fade = create_tween().set_parallel()
	_fade.tween_property(incoming, "volume_db", PLAYING_DB, FADE_SECONDS)
	_fade.tween_property(outgoing, "volume_db", SILENT_DB, fade_seconds)
	_fade.chain().tween_callback(_stop_unless_current.bind(outgoing))


## Whether a track is audible now (for tests and the e2e driver).
func is_audible() -> bool:
	var front := _players[_front]
	return front.playing and front.volume_db > SILENT_DB + 20.0


func _resume_position(track: String, stream: AudioStream) -> float:
	var at := float(_resume_at.get(track, 0.0))
	var length := stream.get_length()
	return at if length <= 0.0 or at < length - 1.0 else 0.0


func _stop_unless_current(player: AudioStreamPlayer) -> void:
	if player != _players[_front]:
		player.stop()


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
		play(_area_track, true, COMBAT_EXIT_FADE)
