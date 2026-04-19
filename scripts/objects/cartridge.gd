class_name Cartridge
extends Interactable

@export var cartridge_id: String = ""

@onready var cartridge_mesh: MeshInstance3D = $CartridgeMesh
@onready var highlight_light: OmniLight3D = $HighlightLight
@onready var cartridge_collider: StaticBody3D = $CartridgeCollider

enum CartState { IDLE, HELD, IN_READER }

const LAYER_IDLE := 2          # pickable
const LAYER_HIDDEN := 0        # not pickable (held / in reader)

# Local pose for a cart while parented to HandAnchor. Identity keeps the cart
# in its natural upright pose (label at +Z = toward anchor +Z = toward camera
# eye, so the label faces the player; arched top at +Y = up in camera view).
const HELD_LOCAL_TRANSFORM := Transform3D.IDENTITY

var _state: CartState = CartState.IDLE
var _held_by: Node = null
var _slot: Node = null  # CartridgeSlot this cart lives in (null if none)
var _original_parent: Node = null
var _original_transform: Transform3D
var _original_rotation: Vector3

func _ready() -> void:
	_original_parent = get_parent()
	_original_transform = transform
	_original_rotation = rotation_degrees
	_apply_appearance()
	add_to_group("cartridges")
	GameState.document_read.connect(_on_state_changed)
	GameState.cartridge_touched.connect(_on_state_changed)
	# Non-starting carts are scene-placed for editor layout but stay hidden at
	# runtime — they enter play via the dispensing flow (not via unlock). Skip
	# slot registration too so the slot reads as empty for the dispenser.
	if GameState.has_cartridge(cartridge_id):
		call_deferred("_register_with_slot")
	else:
		visible = false
		cartridge_collider.collision_layer = LAYER_HIDDEN

func _on_state_changed(_id: String) -> void:
	# A doc was read or any cart was touched somewhere — cheap to refresh.
	_apply_appearance()

func _register_with_slot() -> void:
	var slots := get_tree().get_nodes_in_group("cartridge_slots")
	var closest_slot: Node3D = null
	var closest_dist := 0.18  # max matching radius in metres (scaled up for larger carts)
	for slot_node in slots:
		var slot := slot_node as Node3D
		if not slot:
			continue
		var d := global_position.distance_to(slot.global_position)
		if d < closest_dist:
			closest_dist = d
			closest_slot = slot
	if closest_slot:
		_slot = closest_slot
		closest_slot.call("set_occupant", self)

func _apply_appearance() -> void:
	if cartridge_id.is_empty():
		return
	# Once a cart has been touched (picked up) or used (doc read), drop the
	# colour tint back to a neutral grey. Untouched carts are the ones that pop.
	var spent := _is_spent()
	var base := Color(0.55, 0.55, 0.55) if spent else CartridgeDatabase.get_cartridge_color(cartridge_id)
	highlight_light.light_color = base
	var label := cartridge_mesh.get_node_or_null("LabelPanel") as MeshInstance3D
	if label:
		var mat := StandardMaterial3D.new()
		mat.albedo_color = base.lerp(Color(0.92, 0.88, 0.78), 0.55)
		mat.roughness = 0.96
		label.set_surface_override_material(0, mat)
	# Access-denied carts get their full body tinted so they read as a distinct
	# object on the shelf — the "red card" that never opens.
	if CartridgeDatabase.is_access_denied(cartridge_id):
		var body_mat := StandardMaterial3D.new()
		body_mat.albedo_color = CartridgeDatabase.get_cartridge_color(cartridge_id)
		body_mat.roughness = 0.82
		body_mat.metallic = 0.04
		cartridge_mesh.set_surface_override_material(0, body_mat)
		for child_name in ["ShoulderLeft", "ShoulderRight", "ArchCap", "ArchCrown"]:
			var m := cartridge_mesh.get_node_or_null(child_name) as MeshInstance3D
			if m:
				m.set_surface_override_material(0, body_mat)

func _is_spent() -> bool:
	if cartridge_id in GameState.touched_cartridges:
		return true
	for doc in CartridgeDatabase.get_documents(cartridge_id):
		if doc.get("id", "") in GameState.read_documents:
			return true
	return false

func get_interact_prompt(player: Node = null) -> String:
	if _state != CartState.IDLE:
		return ""
	if player and player.has_held_cartridge():
		return ""
	return "[E] Pick up — " + CartridgeDatabase.get_cartridge_full_name(cartridge_id)

func interact(player: Node) -> bool:
	if _state != CartState.IDLE or player.has_held_cartridge():
		return false
	player.pick_up_cartridge(self)
	return false

# ── Public transition API used by player / reader / slot ─────────────────────

func attach_to_anchor(anchor: Node3D, player: Node) -> void:
	# Transition to HELD: reparent under anchor, keeping global pose, then snap
	# to the canonical held local transform. The player holds us from here.
	_state = CartState.HELD
	_held_by = player
	if _slot != null:
		_slot.clear_occupant()
		_slot = null
	cartridge_collider.collision_layer = LAYER_HIDDEN
	visible = true
	_reparent_preserving_global(anchor)
	transform = HELD_LOCAL_TRANSFORM
	# First time the player handles this cart — mark it spent (drops colour).
	GameState.mark_cartridge_touched(cartridge_id)

func place_in_reader() -> void:
	# Cart stays visible with its spine poking out of the reader's slot. Reparent
	# to the reader's CartridgeSlot node so the cart rides with the reader, then
	# orient cart +Y (spine) along slot +Z (out of slot toward player) and push
	# the body deep enough that only the arch pokes through.
	_state = CartState.IN_READER
	_held_by = null
	visible = true
	cartridge_collider.collision_layer = LAYER_HIDDEN
	var reader := get_tree().get_first_node_in_group("microfiche_reader")
	if reader != null:
		var slot: Node3D = reader.get("cartridge_slot")
		if slot != null:
			_reparent_preserving_global(slot)
			# Align cart axes with the slot's landscape opening:
			#   cart +Y (spine)  → slot +Z → world +Z  (sticks out toward player)
			#   cart +X (width)  → slot +Y → world +X  (along slot's wide axis)
			#   cart +Z (label)  → slot +X → world -Y  (facing down inside reader)
			# Composed basis columns = image of cart's X/Y/Z axes in slot-local.
			transform = Transform3D(
				Basis(Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 0, 0)),
				Vector3(0, 0, -0.14)
			)
			return
	# Fallback: hide if we can't find the reader (shouldn't happen in normal play).
	visible = false
	_reparent_preserving_global(_original_parent)

func eject_to_hand(anchor: Node3D, player: Node) -> void:
	# Caller has already positioned the anchor at the slot pose. Attach and go.
	attach_to_anchor(anchor, player)

func release_to_slot(slot: Node) -> void:
	_state = CartState.IDLE
	_held_by = null
	visible = true
	cartridge_collider.collision_layer = LAYER_IDLE
	var slot_node := slot as Node3D
	_reparent_preserving_global(slot_node.get_parent())
	global_transform = slot_node.global_transform
	_slot = slot
	slot.set_occupant(self)

func release_to_original_slot() -> void:
	_state = CartState.IDLE
	_held_by = null
	visible = true
	cartridge_collider.collision_layer = LAYER_IDLE
	_reparent_preserving_global(_original_parent)
	transform = _original_transform
	if _slot == null:
		# Try to rejoin the closest slot again.
		_register_with_slot()

# ── Internals ────────────────────────────────────────────────────────────────

func _reparent_preserving_global(new_parent: Node) -> void:
	if new_parent == null or new_parent == get_parent():
		return
	var world_t := global_transform
	get_parent().remove_child(self)
	new_parent.add_child(self)
	global_transform = world_t
