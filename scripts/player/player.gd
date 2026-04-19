extends CharacterBody3D

signal view_mode_exited

@export var mouse_sensitivity: float = 0.0018

# Seated player — can look around but not move
const PITCH_MIN := -40.0
const PITCH_MAX := 25.0
const YAW_MIN := -90.0
const YAW_MAX := 90.0

const VIEW_MODE_TWEEN_TIME := 0.35
const VIEW_MODE_EYE_OFFSET := 0.32  # metres in front of display target

enum PlayerState { FREE_LOOK, VIEWING }

@onready var camera: Camera3D = $Camera3D
@onready var hands: Node3D = $Camera3D/Hands
@onready var interaction_ray: RayCast3D = $Camera3D/InteractionRay
@onready var interact_prompt_panel: PanelContainer = $HUD/InteractPromptPanel
@onready var interact_prompt: Label = $HUD/InteractPromptPanel/InteractPrompt
@onready var crosshair: Control = $HUD/Crosshair
@onready var held_label: Label = $HUD/HeldLabel

const BLOCKED_PROMPT_TEXT := "— NO TARGET —"
var _panel_style_active: StyleBox
var _panel_style_blocked: StyleBox

var _yaw: float = 0.0
var _pitch: float = -18.0
var _state: PlayerState = PlayerState.FREE_LOOK
var _current_interactable: Interactable = null
var _held_cartridge: Cartridge = null
var _busy_transport: bool = false

# View-mode state
var _saved_cam_transform: Transform3D
var _view_target: Node3D = null

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_apply_rotation()
	add_to_group("player")
	# Scene starts in the "blocked" appearance (dim green); capture and derive
	# the brighter active variant by raising the bg alpha.
	_panel_style_blocked = interact_prompt_panel.get_theme_stylebox("panel")
	var active := StyleBoxFlat.new()
	active.bg_color = Color(0.18, 0.85, 0.38, 0.92)
	active.content_margin_left = 10.0
	active.content_margin_top = 4.0
	active.content_margin_right = 10.0
	active.content_margin_bottom = 4.0
	_panel_style_active = active

func _input(event: InputEvent) -> void:
	if _state != PlayerState.FREE_LOOK:
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_yaw   = clamp(_yaw   - rad_to_deg(event.relative.x * mouse_sensitivity), YAW_MIN,   YAW_MAX)
		_pitch = clamp(_pitch - rad_to_deg(event.relative.y * mouse_sensitivity), PITCH_MIN, PITCH_MAX)
		_apply_rotation()

func _apply_rotation() -> void:
	rotation_degrees.y = _yaw
	camera.rotation_degrees.x = _pitch

func _process(_delta: float) -> void:
	if _state == PlayerState.FREE_LOOK:
		_poll_interactable()
	_update_held_label()

func _update_held_label() -> void:
	if _held_cartridge != null and _state == PlayerState.FREE_LOOK:
		var label := CartridgeDatabase.get_cartridge_full_name(_held_cartridge.cartridge_id)
		held_label.text = "HOLDING: " + label + "  —  [E] on slot to insert / place"
		held_label.visible = true
	else:
		held_label.visible = false

func _poll_interactable() -> void:
	var found: Interactable = null
	if interaction_ray.is_colliding():
		found = _find_interactable(interaction_ray.get_collider())
	_set_interactable(found)

	var prompt: String = found.get_interact_prompt(self) if found != null else ""
	if prompt.is_empty():
		_set_prompt_blocked()
	else:
		_set_prompt_active(prompt)

func _set_prompt_active(text: String) -> void:
	interact_prompt.text = text
	interact_prompt_panel.add_theme_stylebox_override("panel", _panel_style_active)
	crosshair.modulate = Color(1.1, 1.1, 0.7, 1.0)

func _set_prompt_blocked() -> void:
	interact_prompt.text = BLOCKED_PROMPT_TEXT
	interact_prompt_panel.add_theme_stylebox_override("panel", _panel_style_blocked)
	crosshair.modulate = Color(0.55, 0.75, 0.55, 0.75)

func _set_interactable(i: Interactable) -> void:
	if i == _current_interactable:
		return
	if _current_interactable and _current_interactable.has_method("set_ghost_visible"):
		_current_interactable.set_ghost_visible(false)
	_current_interactable = i
	if i and i.has_method("set_ghost_visible"):
		i.set_ghost_visible(_held_cartridge != null)

func _find_interactable(node: Node) -> Interactable:
	var n := node
	for _i in 4:
		if n == null:
			break
		if n is Interactable:
			return n
		n = n.get_parent()
	return null

func _unhandled_input(event: InputEvent) -> void:
	if _state == PlayerState.VIEWING:
		# Targets that own an input field (e.g. the keyword terminal) opt out so
		# typing E doesn't kick the player out of view mode.
		if _view_target and _view_target.has_method("consumes_view_input") \
				and _view_target.consumes_view_input():
			return
		# Default: E exits. Click and ESC are inert so scrolling / clicking in
		# the doc doesn't pop the player out.
		if event is InputEventKey and event.pressed and not event.echo \
				and event.physical_keycode == KEY_E:
			exit_view_mode()
		return
	if _state == PlayerState.FREE_LOOK and event.is_action_pressed("interact"):
		_try_interact()

func _try_interact() -> void:
	if _current_interactable == null or _busy_transport:
		return
	var prompt := _current_interactable.get_interact_prompt(self)
	if prompt.is_empty():
		return  # no valid action → no camera lock, no hand reach
	_current_interactable.interact(self)

# ── View mode ────────────────────────────────────────────────────────────────

func enter_view_mode(target: Node3D) -> void:
	if _state == PlayerState.VIEWING:
		return
	_state = PlayerState.VIEWING
	_view_target = target
	_saved_cam_transform = camera.transform
	interact_prompt_panel.visible = false
	crosshair.modulate = Color(0, 0, 0, 0)
	Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	var target_global_pos: Vector3 = target.global_transform.origin + target.global_transform.basis.z * VIEW_MODE_EYE_OFFSET
	var target_local_pos: Vector3 = global_transform.affine_inverse() * target_global_pos
	var look_at_pos: Vector3 = global_transform.affine_inverse() * target.global_transform.origin

	var target_transform := Transform3D(Basis(), target_local_pos).looking_at(look_at_pos, Vector3.UP)
	var tween := create_tween().set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "transform", target_transform, VIEW_MODE_TWEEN_TIME)

func exit_view_mode() -> void:
	if _state != PlayerState.VIEWING:
		return
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	var tween := create_tween().set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(camera, "transform", _saved_cam_transform, VIEW_MODE_TWEEN_TIME)
	await tween.finished
	_state = PlayerState.FREE_LOOK
	_view_target = null
	_apply_rotation()
	# Restore HUD hidden by enter_view_mode. _poll_interactable will repopulate
	# the prompt text/style on the next frame.
	interact_prompt_panel.visible = true
	crosshair.modulate = Color(0.55, 0.75, 0.55, 0.75)
	view_mode_exited.emit()

# ── Cart transport ───────────────────────────────────────────────────────────

func has_held_cartridge() -> bool:
	return _held_cartridge != null

func get_held_cartridge() -> Cartridge:
	return _held_cartridge

func pick_up_cartridge(cart: Cartridge) -> void:
	# Snap anchor to cart's world pose, attach cart, then transport to extended rest.
	if _held_cartridge != null or _busy_transport:
		return
	_busy_transport = true
	_held_cartridge = cart
	var anchor: Node3D = hands.hand_anchor
	anchor.global_transform = cart.global_transform
	hands.begin_grip()
	cart.attach_to_anchor(anchor, self)
	AudioManager.sound_hands_grasp()
	await hands.move_to_station("extended", 0.45)
	_busy_transport = false

func insert_held_into_reader(reader: Node, slot_node: Node3D) -> void:
	if _held_cartridge == null or _busy_transport:
		return
	_busy_transport = true
	# Tween anchor to slot world position (keep current orientation — prevents weird flips).
	var anchor: Node3D = hands.hand_anchor
	await hands.move_to_world(slot_node.global_transform.origin, anchor.global_transform.basis, 0.4)
	await hands.animate_insert_push()
	var cart := _held_cartridge
	var cart_id := cart.cartridge_id
	cart.place_in_reader()
	_held_cartridge = null
	hands.release_grip()
	await hands.move_to_station("rest", 0.25)
	hands.hide_hands()
	_busy_transport = false
	reader.insert_cartridge(cart_id)

func return_held_to_slot(slot: Node) -> void:
	if _held_cartridge == null or _busy_transport:
		return
	_busy_transport = true
	var slot_node := slot as Node3D
	var anchor: Node3D = hands.hand_anchor
	await hands.move_to_world(slot_node.global_transform.origin, anchor.global_transform.basis, 0.4)
	_held_cartridge.release_to_slot(slot)
	_held_cartridge = null
	hands.release_grip()
	await hands.move_to_station("rest", 0.25)
	hands.hide_hands()
	_busy_transport = false

func receive_ejected_cartridge(cart: Cartridge, slot_global_transform: Transform3D) -> void:
	# Called by reader when ejecting with nothing held. Appear at slot, transport to rest.
	if _held_cartridge != null or _busy_transport:
		return
	_busy_transport = true
	_held_cartridge = cart
	var anchor: Node3D = hands.hand_anchor
	anchor.global_transform = slot_global_transform
	hands.begin_grip()
	cart.eject_to_hand(anchor, self)
	await hands.move_to_station("extended", 0.45)
	_busy_transport = false

func get_state() -> PlayerState:
	return _state
