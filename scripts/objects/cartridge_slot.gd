class_name CartridgeSlot
extends Interactable

# A slot in the cartridge display stand.
# Empty slots are interactable (layer 2); occupied slots are not (layer 0).

@onready var slot_collider: StaticBody3D = $SlotCollider

var _occupant: Node = null

func _ready() -> void:
	add_to_group("cartridge_slots")

func get_interact_prompt(player: Node = null) -> String:
	if _occupant != null:
		return ""
	if player and player.has_held_cartridge():
		var held: Cartridge = player.get_held_cartridge()
		return "[E] Place — " + CartridgeDatabase.get_cartridge_label(held.cartridge_id)
	return ""

func interact(player: Node) -> bool:
	if _occupant != null or not player.has_held_cartridge():
		return false
	player.return_held_to_slot(self)
	return false

func set_occupant(cart: Node) -> void:
	_occupant = cart
	slot_collider.collision_layer = 0

func clear_occupant() -> void:
	_occupant = null
	slot_collider.collision_layer = 2

func get_occupant() -> Node:
	return _occupant
