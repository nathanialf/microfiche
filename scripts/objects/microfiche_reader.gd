extends Node3D

# The microfiche reader. State holder + boot sequence + cart I/O coordinator.
# Interaction is delegated to two child zones:
#   TerminalBody/SlotZone      — SlotInteractable (insert / eject)
#   TerminalBody/DisplayZone   — DisplayInteractable (enter view mode)

signal cartridge_inserted(cartridge_id: String)
signal cartridge_ejected(cartridge_id: String)

@onready var cartridge_slot: Node3D = $TerminalBody/CartridgeSlot
@onready var screen_glow: OmniLight3D = $TerminalBody/Screen/ScreenGlow
@onready var screen_viewport: SubViewport = $TerminalBody/Screen/SubViewport
@onready var screen_surface: MeshInstance3D = $TerminalBody/Screen/ScreenSurface
@onready var _ui_node: Control = $TerminalBody/Screen/SubViewport/MicroficheUI

var _current_cartridge_id: String = ""
var _ui: Control = null

func _ready() -> void:
	add_to_group("microfiche_reader")
	_ui = _ui_node
	print("[microfiche_reader] _ready; ui=", _ui, " viewport_size=", screen_viewport.size)
	_wire_screen_texture()
	_boot_sequence()

func _wire_screen_texture() -> void:
	# ViewportTexture sub_resources with viewport_path often fail to resolve at
	# scene load time; build the material at runtime from the live SubViewport.
	var vtex := screen_viewport.get_texture()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = vtex
	mat.emission_enabled = true
	mat.emission_texture = vtex
	mat.emission_energy_multiplier = 1.4
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	screen_surface.set_surface_override_material(0, mat)
	print("[microfiche_reader] wired screen texture: ", vtex, " viewport_size=", screen_viewport.size)

func _get_ui() -> Control:
	return _ui

func _boot_sequence() -> void:
	screen_glow.light_energy = 0.0
	AudioManager.sound_terminal_boot()
	var tween := create_tween()
	tween.tween_property(screen_glow, "light_energy", 0.3, 0.05)
	tween.tween_property(screen_glow, "light_energy", 0.0, 0.05)
	tween.tween_property(screen_glow, "light_energy", 0.5, 0.05)
	tween.tween_property(screen_glow, "light_energy", 0.1, 0.08)
	tween.tween_property(screen_glow, "light_energy", 0.8, 0.15)
	tween.tween_callback(func():
		var ui := _get_ui()
		print("[microfiche_reader] boot tween done; ui=", ui)
		if ui:
			ui.show_boot_screen()
	)

func insert_cartridge(cartridge_id: String) -> void:
	print("[microfiche_reader] insert_cartridge: ", cartridge_id)
	if not _current_cartridge_id.is_empty():
		return
	_current_cartridge_id = cartridge_id

	emit_signal("cartridge_inserted", cartridge_id)
	AudioManager.sound_cartridge_insert()

	await get_tree().create_timer(0.3).timeout

	var ui := _get_ui()
	print("[microfiche_reader] insert after delay; ui=", ui, " access_denied=", CartridgeDatabase.is_access_denied(cartridge_id))
	if ui == null:
		return

	if CartridgeDatabase.is_access_denied(cartridge_id):
		GameState.increment_classified_inserts()
		ui.show_access_denied(cartridge_id)
	else:
		ui.show_document_reader(cartridge_id)

func eject_cartridge() -> void:
	if _current_cartridge_id.is_empty():
		return
	var ejected := _current_cartridge_id
	_current_cartridge_id = ""

	AudioManager.sound_cartridge_eject()

	var ui := _get_ui()
	if ui:
		ui.show_idle_screen()

	# Hand the cart back to the player — they'll transport it to extended rest.
	# If the player's hands are full, fall back to returning to the cart's origin slot.
	var player := get_tree().get_first_node_in_group("player")
	for c in get_tree().get_nodes_in_group("cartridges"):
		if c.cartridge_id == ejected:
			if player and not player.has_held_cartridge():
				player.receive_ejected_cartridge(c, cartridge_slot.global_transform)
			else:
				c.release_to_original_slot()
			break

	emit_signal("cartridge_ejected", ejected)

func get_loaded_cartridge() -> String:
	return _current_cartridge_id

func _unhandled_input(event: InputEvent) -> void:
	# Terminal UI lives inside a SubViewport and won't receive input otherwise
	if screen_viewport:
		screen_viewport.push_input(event)
