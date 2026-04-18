@tool
extends Node3D

# Auto-orients this node so its local -Z axis points at the player (or a named
# group target). Runs once at _ready and also in the editor (@tool) for preview.
#
# Useful for objects placed on the curved desk arc where hand-computed yaw
# rotations are fiddly — just drop this script on the node, pick which local
# axis should face the target, and it'll aim itself.

@export var target_group: StringName = &"player"
@export var target_path: NodePath  # optional explicit override (editor-time)
@export_enum("-Z (forward)", "+Z (back)", "+X (right)", "-X (left)")
var facing_axis: int = 0

func _ready() -> void:
	if Engine.is_editor_hint():
		return
	call_deferred("_aim")

func _aim() -> void:
	var target: Node3D = _find_target()
	if target == null:
		return
	var from := global_transform.origin
	var to := target.global_transform.origin
	# Lock pitch: keep target at the same height so we only rotate in yaw.
	to.y = from.y
	if from.distance_to(to) < 0.001:
		return
	look_at(to, Vector3.UP)
	# look_at aims local -Z at `to`. If the user picked a different axis,
	# apply an extra yaw so the picked axis ends up aimed.
	match facing_axis:
		1: rotate_y(PI)           # +Z facing target
		2: rotate_y(-PI / 2.0)    # +X facing target
		3: rotate_y(PI / 2.0)     # -X facing target

func _find_target() -> Node3D:
	if target_path != NodePath():
		var n := get_node_or_null(target_path)
		if n is Node3D:
			return n
	var found := get_tree().get_first_node_in_group(target_group) if get_tree() else null
	return found as Node3D
