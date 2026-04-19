extends Node3D

@onready var terminal_glow: OmniLight3D = $Lighting/TerminalGlow
@onready var tower: Node3D = $Objects/CartridgeTower

# Maps cart id → the tower slot node that holds it on reload. The dispenser
# spawns carts at runtime; on reload we materialise dispensed carts here so
# they don't vanish between sessions.
const SLOT_BY_CARTRIDGE := {
	"threshold": "SlotThreshold",
	"omicron": "SlotOmicron",
	"mox": "SlotMox",
	"sable": "SlotSable",
	"classified": "SlotClassified",
	"vex": "SlotVex",
	"caul": "SlotCaul",
	"choir": "SlotChoir",
	"litany": "SlotLitany",
	"expanse": "SlotExpanse",
	"kaya": "SlotKaya",
	"watcher": "SlotWatcher",
	"blade": "SlotBlade",
}

func _ready() -> void:
	_start_terminal_breathe()
	call_deferred("_restore_dispensed_cartridges")

func _start_terminal_breathe() -> void:
	var tween := create_tween().set_loops()
	tween.tween_property(terminal_glow, "light_energy", 0.38, 2.2).set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(terminal_glow, "light_energy", 0.18, 2.8).set_ease(Tween.EASE_IN_OUT)

func _restore_dispensed_cartridges() -> void:
	var scene_ids: Dictionary = {}
	for node in get_tree().get_nodes_in_group("cartridges"):
		scene_ids[node.cartridge_id] = true
	for cart_id in GameState.dispensed_cartridges:
		if cart_id in scene_ids:
			continue
		_spawn_in_tower(cart_id)

func _spawn_in_tower(cart_id: String) -> void:
	var slot_name: String = SLOT_BY_CARTRIDGE.get(cart_id, "")
	if slot_name.is_empty():
		return
	var slot: Node3D = tower.get_node_or_null(slot_name)
	if slot == null:
		return
	var cart: Cartridge = preload("res://scenes/objects/cartridge.tscn").instantiate()
	cart.cartridge_id = cart_id
	# Slot is a sibling — same parent-space, so copy local transform directly.
	# Set before add_child so Cartridge._ready captures the right _original_transform.
	cart.transform = slot.transform
	tower.add_child(cart)
