extends Interactable

# Interaction zone covering the screen/display surface of the microfiche.
# E → enter view mode (camera tweens in front of screen, look-around locked).

@export var screen_target_path: NodePath  # Node3D at the screen face

@onready var reader: Node = get_parent().get_parent()
@onready var _screen_target: Node3D = get_node_or_null(screen_target_path) as Node3D

func get_interact_prompt(_player: Node) -> String:
	return "[E] Read"

func interact(player: Node) -> bool:
	var target: Node3D = _screen_target if _screen_target != null else self
	if player.has_method("enter_view_mode"):
		player.enter_view_mode(target)
	return true  # takes the player out of FREE_LOOK
