extends Node3D

@onready var objects: Node3D = $Objects
@onready var terminal_glow: OmniLight3D = $Lighting/TerminalGlow

# Desk positions for dynamically spawned cartridges
# Placed as if someone set them down — slight angle variation
const SPAWN_TRANSFORMS := [
	[Vector3(0, deg_to_rad(12),  deg_to_rad(3)),  Vector3(1.08, 0.865, -1.38)],
	[Vector3(0, deg_to_rad(-8),  deg_to_rad(-2)), Vector3(1.28, 0.865, -1.41)],
	[Vector3(0, deg_to_rad(22),  deg_to_rad(4)),  Vector3(1.48, 0.865, -1.37)],
	[Vector3(0, deg_to_rad(-5),  deg_to_rad(1)),  Vector3(1.68, 0.865, -1.42)],
	[Vector3(0, deg_to_rad(15),  deg_to_rad(-3)), Vector3(1.88, 0.865, -1.39)],
]

var _spawned: Dictionary = {}

func _ready() -> void:
	GameState.cartridge_unlocked.connect(_on_cartridge_unlocked)
	_start_terminal_breathe()

func _start_terminal_breathe() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(terminal_glow, "light_energy", 0.38, 2.2).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(terminal_glow, "light_energy", 0.18, 2.8).set_ease(Tween.EASE_IN_OUT)

func _on_cartridge_unlocked(cartridge_id: String) -> void:
	_spawn_cartridge(cartridge_id)

func _spawn_cartridge(cartridge_id: String) -> void:
	if cartridge_id in _spawned:
		return
	# Check if already present as a scene-placed node
	for node in get_tree().get_nodes_in_group("cartridges"):
		if node.cartridge_id == cartridge_id:
			return

	var scene: PackedScene = preload("res://scenes/objects/cartridge.tscn")
	var instance: Node3D = scene.instantiate()
	instance.cartridge_id = cartridge_id

	var slot_idx := _spawned.size()
	if slot_idx < SPAWN_TRANSFORMS.size():
		var xform: Array = SPAWN_TRANSFORMS[slot_idx]
		instance.rotation = xform[0]
		instance.position = xform[1]
	else:
		instance.position = Vector3(0.5 + slot_idx * 0.14, 0.865, -1.40)

	# Drop in from above
	var land_pos := instance.position
	instance.position = land_pos + Vector3(0, 0.5, 0)
	objects.add_child(instance)
	_spawned[cartridge_id] = instance

	var tween := create_tween().set_ease(Tween.EASE_OUT)
	tween.tween_property(instance, "position", land_pos, 0.30)
