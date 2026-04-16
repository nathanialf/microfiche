extends Node3D

# The central microfiche reader terminal

signal cartridge_inserted(cartridge_id: String)
signal cartridge_ejected(cartridge_id: String)

@onready var cartridge_slot: Node3D = $TerminalBody/CartridgeSlot
@onready var slot_light: OmniLight3D = $TerminalBody/CartridgeSlot/SlotLight
@onready var screen_glow: OmniLight3D = $TerminalBody/Screen/ScreenGlow

var _current_cartridge_id: String = ""
var _terminal_ui: Control = null

func _ready() -> void:
	add_to_group("microfiche_reader")
	_boot_sequence()

func _get_terminal_ui() -> Control:
	if _terminal_ui == null:
		_terminal_ui = get_tree().get_first_node_in_group("terminal_ui")
	return _terminal_ui

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
		var ui := _get_terminal_ui()
		if ui:
			ui.show_boot_screen()
	)

func get_interact_prompt() -> String:
	if _current_cartridge_id.is_empty():
		return "[E] Insert cartridge  [N] Notes"
	return "[E] Read  [R] Eject  [N] Notes"

func interact(player: Node) -> void:
	var ui := _get_terminal_ui()
	if ui == null:
		return
	player.set_interaction_enabled(false)
	if _current_cartridge_id.is_empty():
		ui.show_cartridge_select()
	else:
		ui.show_document_reader(_current_cartridge_id)
	ui.interaction_ended.connect(
		func(): player.set_interaction_enabled(true),
		CONNECT_ONE_SHOT
	)

func insert_cartridge(cartridge_id: String, player: Node = null) -> void:
	if not _current_cartridge_id.is_empty():
		return
	_current_cartridge_id = cartridge_id
	slot_light.light_color = CartridgeDatabase.get_cartridge_color(cartridge_id)

	var tween := create_tween()
	tween.tween_property(slot_light, "light_energy", 1.4, 0.08)
	tween.tween_property(slot_light, "light_energy", 0.5, 0.3)

	emit_signal("cartridge_inserted", cartridge_id)
	AudioManager.sound_cartridge_insert()

	# Small delay so insert animation plays first
	await get_tree().create_timer(0.3).timeout

	var ui := _get_terminal_ui()
	if ui == null:
		if player:
			player.set_interaction_enabled(true)
		return

	# Enter terminal mode: show mouse cursor, keep camera locked
	# Then re-enable movement when UI closes (same as direct reader interaction)
	if player:
		player.set_interaction_enabled(false)
		ui.interaction_ended.connect(
			func(): player.set_interaction_enabled(true),
			CONNECT_ONE_SHOT
		)

	if CartridgeDatabase.is_access_denied(cartridge_id):
		ui.show_access_denied(cartridge_id)
	else:
		ui.show_document_reader(cartridge_id)

func eject_cartridge() -> void:
	if _current_cartridge_id.is_empty():
		return
	var ejected := _current_cartridge_id
	_current_cartridge_id = ""

	AudioManager.sound_cartridge_eject()

	var tween := create_tween()
	tween.tween_property(slot_light, "light_energy", 0.0, 0.2)

	var ui := _get_terminal_ui()
	if ui:
		ui.show_idle_screen()

	# Return cartridge to shelf
	var cartridges := get_tree().get_nodes_in_group("cartridges")
	for c in cartridges:
		if c.cartridge_id == ejected:
			c.return_to_shelf()
			break

	emit_signal("cartridge_ejected", ejected)

func get_loaded_cartridge() -> String:
	return _current_cartridge_id

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("eject_cartridge") and not _current_cartridge_id.is_empty():
		eject_cartridge()
