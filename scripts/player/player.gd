extends CharacterBody3D

@export var mouse_sensitivity: float = 0.0018

# Seated player — can look around but not move
const PITCH_MIN := -40.0
const PITCH_MAX := 25.0
const YAW_MIN := -75.0
const YAW_MAX := 75.0

@onready var camera: Camera3D = $Camera3D
@onready var hands: Node3D = $Camera3D/Hands
@onready var interaction_ray: RayCast3D = $Camera3D/InteractionRay
@onready var interact_prompt: Label = $HUD/InteractPrompt
@onready var crosshair: Control = $HUD/Crosshair

var _yaw: float = 0.0
var _pitch: float = -18.0
var _locked: bool = false
var _current_interactable: Node = null

func _ready() -> void:
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	_apply_rotation()

func _input(event: InputEvent) -> void:
	if _locked:
		return
	if event is InputEventMouseMotion and Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
		_yaw   = clamp(_yaw   - rad_to_deg(event.relative.x * mouse_sensitivity), YAW_MIN,   YAW_MAX)
		_pitch = clamp(_pitch - rad_to_deg(event.relative.y * mouse_sensitivity), PITCH_MIN, PITCH_MAX)
		_apply_rotation()

func _apply_rotation() -> void:
	rotation_degrees.y = _yaw
	camera.rotation_degrees.x = _pitch

func _process(_delta: float) -> void:
	_poll_interactable()

func _poll_interactable() -> void:
	if not interaction_ray.is_colliding():
		if _current_interactable != null:
			_current_interactable = null
			interact_prompt.visible = false
			crosshair.modulate = Color(0.55, 0.75, 0.55, 0.75)
		return

	var hit := interaction_ray.get_collider()
	# Walk up to the interactable root (the reader/cartridge is parent of the StaticBody)
	var interactable := _find_interactable(hit)

	if interactable != _current_interactable:
		_current_interactable = interactable
		if interactable and interactable.has_method("get_interact_prompt"):
			interact_prompt.text = interactable.get_interact_prompt()
			interact_prompt.visible = true
			crosshair.modulate = Color(1.1, 1.1, 0.7, 1.0)
		else:
			interact_prompt.visible = false
			crosshair.modulate = Color(0.55, 0.75, 0.55, 0.75)

func _find_interactable(node: Node) -> Node:
	# Walk up the tree looking for something with interact()
	var n := node
	for _i in 4:
		if n == null:
			break
		if n.has_method("interact"):
			return n
		n = n.get_parent()
	return null

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("interact") and not _locked:
		_try_interact()
	if event.is_action_pressed("open_notepad") and not _locked:
		_toggle_notepad()
	if event.is_action_pressed("ui_cancel") and _locked:
		# Don't capture — let the UI handle it
		pass

func _try_interact() -> void:
	if _current_interactable == null or not _current_interactable.has_method("interact"):
		return
	_locked = true
	if hands.has_method("reach_toward"):
		hands.reach_toward(_current_interactable.global_position)
		await hands.reach_complete
	_current_interactable.interact(self)

func _toggle_notepad() -> void:
	var ui := get_tree().get_first_node_in_group("terminal_ui")
	if ui and ui.has_method("toggle_notepad"):
		ui.toggle_notepad()

func set_interaction_enabled(enabled: bool) -> void:
	_locked = not enabled
	if enabled:
		Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	else:
		Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

func retract_hands() -> void:
	if hands and hands.has_method("retract"):
		hands.retract()
