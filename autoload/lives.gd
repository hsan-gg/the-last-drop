extends Node
## Three lives per run. Collapsing (health reaching zero) costs one and sends
## the player back to the area's start; with none left the run is over.

const DEFAULT_LIVES := 3

## Off until a real run starts, so tests that knock the player out stay peaceful.
var active := false
var max_lives := DEFAULT_LIVES
var lives := DEFAULT_LIVES


func _ready() -> void:
	EventBus.player_collapsed.connect(_on_collapse)


func start_run() -> void:
	Difficulty.begin_run()
	max_lives = int(Difficulty.value("lives"))
	lives = max_lives
	active = true
	EventBus.lives_changed.emit(lives)


func reset() -> void:
	max_lives = DEFAULT_LIVES
	lives = DEFAULT_LIVES
	active = false
	EventBus.lives_changed.emit(lives)


func _on_collapse() -> void:
	if not active:
		return
	lives = maxi(lives - 1, 0)
	EventBus.lives_changed.emit(lives)
	if lives > 0:
		EventBus.life_lost.emit(lives)
	else:
		active = false
		EventBus.game_over.emit()
