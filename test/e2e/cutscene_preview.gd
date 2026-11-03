extends Node
## Preview-only: plays the intro cutscene (skipping nothing) so each beat can be screenshotted.


func _ready() -> void:
	Cutscenes.pending_id = "intro"
	add_child(preload("res://ui/cutscene.tscn").instantiate())
