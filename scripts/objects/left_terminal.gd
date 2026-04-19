class_name LeftTerminal
extends Node3D

# Left-desk keyword-query terminal with a built-in cassette-style dispenser.
# Captures keyboard input directly (no LineEdit / SubViewport focus plumbing) —
# builds a query buffer and submits on Enter. The UI is purely display.

const HATCH_CLOSED_ROT_X := 0.0
const HATCH_OPEN_ROT_X := deg_to_rad(-55.0)
const HATCH_TWEEN_TIME := 0.35
const CART_POP_TIME := 0.55
const DISPENSE_GRACE := 1.5
const MAX_QUERY_LEN := 64

@onready var screen_viewport: SubViewport = $Monitor/Screen/SubViewport
@onready var screen_surface: MeshInstance3D = $Monitor/Screen/ScreenSurface
@onready var ui: Control = $Monitor/Screen/SubViewport/LeftTerminalUI
@onready var screen_glow: OmniLight3D = $Monitor/Screen/ScreenGlow
@onready var hatch: Node3D = $Monitor/DispenserHousing/DispenserHatch
@onready var cart_mount: Node3D = $Monitor/DispenserHousing/CartMount

var _pending_cart_id: String = ""
var _active_cart: Cartridge = null
var _in_view_mode: bool = false
var _accepting_input: bool = false
var _query_buffer: String = ""

func _ready() -> void:
	add_to_group("left_terminal")
	_wire_screen_texture()

func _wire_screen_texture() -> void:
	var vtex := screen_viewport.get_texture()
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_texture = vtex
	mat.emission_enabled = true
	mat.emission_texture = vtex
	mat.emission_energy_multiplier = 1.4
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	screen_surface.set_surface_override_material(0, mat)

func notify_view_entered() -> void:
	_in_view_mode = true
	_accepting_input = true
	_query_buffer = ""
	if ui and ui.has_method("set_input_text"):
		ui.set_input_text("")

func notify_view_exited() -> void:
	_in_view_mode = false
	_accepting_input = false
	_query_buffer = ""
	if ui and ui.has_method("set_input_text"):
		ui.set_input_text("")

# Consumed by player.gd to suppress the global KEY_E-exits-view behaviour.
func consumes_view_input() -> bool:
	return _in_view_mode

func _unhandled_input(event: InputEvent) -> void:
	if not _in_view_mode:
		return
	# Allow key repeat (echo events) so held keys auto-repeat at the OS rate —
	# needed for backspace-hold-to-delete.
	if event is InputEventKey and event.pressed:
		if _handle_key(event):
			get_viewport().set_input_as_handled()

func _handle_key(event: InputEventKey) -> bool:
	# ESC: exit view mode, wherever the query buffer is.
	if event.physical_keycode == KEY_ESCAPE:
		var player := get_tree().get_first_node_in_group("player")
		if player and player.has_method("exit_view_mode"):
			player.exit_view_mode()
		return true
	if not _accepting_input:
		return false
	if event.physical_keycode == KEY_ENTER or event.physical_keycode == KEY_KP_ENTER:
		var keyword := _query_buffer.strip_edges()
		_query_buffer = ""
		ui.set_input_text("")
		if not keyword.is_empty():
			_submit_query(keyword)
		return true
	if event.physical_keycode == KEY_BACKSPACE:
		if _query_buffer.length() > 0:
			_query_buffer = _query_buffer.substr(0, _query_buffer.length() - 1)
			ui.set_input_text(_query_buffer)
			AudioManager.sound_typewriter_key()
		return true
	# Printable ASCII 32..126 plus common extended (latin-1 letters could matter, skip for now).
	if event.unicode >= 32 and event.unicode < 127:
		if _query_buffer.length() >= MAX_QUERY_LEN:
			return true
		_query_buffer += String.chr(event.unicode)
		ui.set_input_text(_query_buffer)
		AudioManager.sound_typewriter_key()
		return true
	return false

func _on_view_mode_exited() -> void:
	_in_view_mode = false
	if not _pending_cart_id.is_empty():
		_run_dispense_animation(_pending_cart_id)

func _submit_query(keyword: String) -> void:
	var cid := GameState.get_dispense_target(keyword)
	if cid.is_empty():
		ui.show_invalid(keyword)
		AudioManager.sound_query_invalid()
		return
	var title := CartridgeDatabase.get_cartridge_full_name(cid)
	var doc_type := CartridgeDatabase.get_cartridge_doc_type(cid)
	var label := ("%s: %s" % [doc_type, title]) if not doc_type.is_empty() else title
	if cid in GameState.dispensed_cartridges:
		ui.show_already_dispensed(keyword, label)
		AudioManager.sound_query_rejected()
		return
	if not GameState.is_keyword_seen(keyword):
		ui.show_invalid(keyword)
		AudioManager.sound_query_invalid()
		return
	_pending_cart_id = cid
	_accepting_input = false
	ui.show_dispensing(keyword, label)
	AudioManager.sound_query_accepted()
	GameState.try_dispense_by_keyword(keyword)
	await get_tree().create_timer(DISPENSE_GRACE).timeout
	var player := get_tree().get_first_node_in_group("player")
	if player == null or not player.has_method("exit_view_mode"):
		_run_dispense_animation(_pending_cart_id)
		return
	if not player.view_mode_exited.is_connected(_on_view_mode_exited):
		player.view_mode_exited.connect(_on_view_mode_exited, CONNECT_ONE_SHOT)
	player.exit_view_mode()

func _run_dispense_animation(cart_id: String) -> void:
	if cart_id.is_empty():
		return
	AudioManager.sound_hatch_open()
	var hatch_tween := create_tween().set_ease(Tween.EASE_OUT)
	hatch_tween.tween_property(hatch, "rotation:x", HATCH_OPEN_ROT_X, HATCH_TWEEN_TIME)
	await hatch_tween.finished

	var cart_scene: PackedScene = preload("res://scenes/objects/cartridge.tscn")
	var cart: Cartridge = cart_scene.instantiate()
	cart.cartridge_id = cart_id
	cart_mount.add_child(cart)
	var start_t := Transform3D(Basis(), Vector3(0, -0.06, -0.03))
	var pop_t := Transform3D(Basis.from_euler(Vector3(deg_to_rad(-20), 0, 0)), Vector3.ZERO)
	cart.transform = start_t
	AudioManager.sound_cart_pop()
	var pop_tween := create_tween().set_ease(Tween.EASE_OUT)
	pop_tween.tween_property(cart, "transform", pop_t, CART_POP_TIME)
	await pop_tween.finished

	_active_cart = cart
	if not GameState.cartridge_touched.is_connected(_on_cart_picked_up):
		GameState.cartridge_touched.connect(_on_cart_picked_up)

func _on_cart_picked_up(cart_id: String) -> void:
	if cart_id != _pending_cart_id:
		return
	if GameState.cartridge_touched.is_connected(_on_cart_picked_up):
		GameState.cartridge_touched.disconnect(_on_cart_picked_up)
	_pending_cart_id = ""
	_active_cart = null
	AudioManager.sound_hatch_close()
	var close_tween := create_tween().set_ease(Tween.EASE_IN_OUT)
	close_tween.tween_property(hatch, "rotation:x", HATCH_CLOSED_ROT_X, HATCH_TWEEN_TIME)
	await close_tween.finished
	ui.show_prompt()
