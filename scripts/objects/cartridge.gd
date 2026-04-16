extends Node3D

@export var cartridge_id: String = ""

@onready var cartridge_mesh: MeshInstance3D = $CartridgeMesh
@onready var highlight_light: OmniLight3D = $HighlightLight

var _original_position: Vector3
var _original_rotation: Vector3
var _in_reader: bool = false

func _ready() -> void:
	_original_position = position
	_original_rotation = rotation_degrees
	_apply_appearance()
	add_to_group("cartridges")

func _apply_appearance() -> void:
	if cartridge_id.is_empty():
		return
	var mat := StandardMaterial3D.new()
	mat.albedo_color = CartridgeDatabase.get_cartridge_color(cartridge_id)
	mat.roughness = 0.82
	mat.metallic = 0.15
	cartridge_mesh.set_surface_override_material(0, mat)

	highlight_light.light_color = CartridgeDatabase.get_cartridge_color(cartridge_id)

func get_interact_prompt() -> String:
	if _in_reader:
		return ""
	var written := CartridgeDatabase.get_handwritten_label(cartridge_id)
	if written.is_empty():
		return "[E] Pick up — " + CartridgeDatabase.get_cartridge_label(cartridge_id)
	return "[E] Pick up — \"%s\"" % written

func interact(player: Node) -> void:
	if _in_reader:
		player.set_interaction_enabled(true)
		return
	var reader := get_tree().get_first_node_in_group("microfiche_reader")
	if reader == null:
		player.set_interaction_enabled(true)
		return
	# Don't insert if reader already has a cartridge
	if not reader.get_loaded_cartridge().is_empty():
		player.set_interaction_enabled(true)
		return

	_in_reader = true
	_animate_pickup()
	await get_tree().create_timer(0.35).timeout
	visible = false
	player.retract_hands()
	reader.insert_cartridge(cartridge_id, player)

func _animate_pickup() -> void:
	AudioManager.sound_hands_grasp()
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_parallel(true)
	tween.tween_property(self, "position", position + Vector3(0, 0.06, 0), 0.14)
	tween.tween_property(self, "rotation_degrees",
		_original_rotation + Vector3(4, 8, 2), 0.14)

func return_to_shelf() -> void:
	_in_reader = false
	visible = true
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_parallel(true)
	tween.tween_property(self, "position", _original_position, 0.38)
	tween.tween_property(self, "rotation_degrees", _original_rotation, 0.38)
