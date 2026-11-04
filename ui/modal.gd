class_name Modal
extends RefCounted
## Whether a panel that takes the keyboard is open (a menu, quiz, puzzle or the
## sorting screen). The player stands still and keeps their hands to themselves
## while one is up, even though the world keeps moving around them.


static func any_open(tree: SceneTree) -> bool:
	for node in tree.get_nodes_in_group("modal"):
		if node is CanvasItem and (node as CanvasItem).visible:
			return true
		if node is CanvasLayer and (node as CanvasLayer).visible:
			return true
	return false
