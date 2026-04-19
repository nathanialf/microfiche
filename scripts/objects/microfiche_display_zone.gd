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
	if reader and reader.has_method("notify_view_entered"):
		reader.notify_view_entered()
	if player.has_signal("view_mode_exited") \
			and not player.view_mode_exited.is_connected(_on_view_mode_exited):
		player.view_mode_exited.connect(_on_view_mode_exited, CONNECT_ONE_SHOT)
	return true  # takes the player out of FREE_LOOK

func _on_view_mode_exited() -> void:
	if reader and reader.has_method("notify_view_exited"):
		reader.notify_view_exited()
