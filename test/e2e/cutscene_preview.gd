extends Node
## Preview-only: plays one beat per cutscene scene so each can be screenshotted.


func _ready() -> void:
	Cutscenes.pending_id = "intro"
	var player: CutscenePlayer = preload("res://ui/cutscene.tscn").instantiate()
	add_child(player)
	var beats: Array = []
	for kind in ["fields", "industry", "sanctuary", "ruins", "outpost", "factory", "dump", "river", "spring"]:
		beats.append({"visual": kind, "title": kind.to_upper(), "text": "A preview of the %s scene." % kind, "focus": []})
	player.play_beats(beats)
