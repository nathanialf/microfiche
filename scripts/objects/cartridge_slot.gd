class_name CartridgeSlot
extends Interactable

# A slot in the cartridge display stand.
# Empty slots are interactable (layer 2); occupied slots are not (layer 0).

@onready var slot_collider: StaticBody3D = $SlotCollider

# Rough cart silhouette for the placement ghost. Slightly under-sized vs. the
# actual cart body so the amber glow reads as a hint rather than a duplicate.
const GHOST_SIZE := Vector3(0.140, 0.280, 0.034)
# Cart mesh sits a touch below its local origin (see cartridge.tscn); match so
# the ghost lines up with where the real cart would sit after placement.
const GHOST_OFFSET := Vector3(0, -0.028, 0)

var _occupant: Node = null
var _ghost: MeshInstance3D

func _ready() -> void:
	add_to_group("cartridge_slots")
	_build_ghost()

func _build_ghost() -> void:
	_ghost = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = GHOST_SIZE
	_ghost.mesh = box
	_ghost.position = GHOST_OFFSET
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.albedo_color = Color(1.0, 0.62, 0.14, 0.22)
	mat.emission_enabled = true
	mat.emission = Color(1.0, 0.55, 0.14)
	mat.emission_energy_multiplier = 0.9
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost.material_override = mat
	_ghost.visible = false
	add_child(_ghost)

func set_ghost_visible(show: bool) -> void:
	if _ghost == null:
		return
	_ghost.visible = show and _occupant == null

func get_interact_prompt(player: Node = null) -> String:
	if _occupant != null:
		return ""
	if player and player.has_held_cartridge():
		var held: Cartridge = player.get_held_cartridge()
		return "[E] Place — " + CartridgeDatabase.get_cartridge_full_name(held.cartridge_id)
	return ""

func interact(player: Node) -> bool:
	if _occupant != null or not player.has_held_cartridge():
		return false
	player.return_held_to_slot(self)
	return false

func set_occupant(cart: Node) -> void:
	_occupant = cart
	slot_collider.collision_layer = 0
	if _ghost:
		_ghost.visible = false

func clear_occupant() -> void:
	_occupant = null
	slot_collider.collision_layer = 2

func get_occupant() -> Node:
	return _occupant
