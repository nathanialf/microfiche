extends Node3D

# Station-based cartridge transport.
#
# Hands are camera-local. A held cartridge is parented to HandAnchor and moved
# through named station poses via tweens. Hands follow HandAnchor's pose with
# a slight gripping offset so they appear to be carrying the cart.
#
# Stations (anchor transform in parent-local / camera-local space):
#   "rest"      — hands-down neutral (used when nothing is held and no reach is active)
#   "extended"  — extended resting arm pose between player and desk (default hold)
#   "inspect"   — cartridge face turned toward the player (reserved for future use)
#
# World-space targets (grab origin, reader slot) are handled via move_anchor_to_world,
# which converts a world transform into the anchor's parent-local space.

signal transport_complete

@export var idle_tremor_intensity: float = 0.0012

@onready var right_hand: Node3D = $RightHand
@onready var left_hand: Node3D = $LeftHand
@onready var hand_anchor: Node3D = $HandAnchor

# Station poses: position, rotation_deg in camera-local space (Hands is now an
# identity child of Camera, so anchor-local == camera-local).
#
# Camera FOV 65° + default pitch -18°. Vertical FOV half-angle at distance D is
# D·tan(32.5°) = 0.637·D. To stay in frame the anchor's Y (below center) must
# not exceed that at the anchor's forward distance.
const STATION_POSES: Dictionary = {
	"rest":     [Vector3(0.0, -0.15, -0.10), Vector3(0, 0, 0)],
	"extended": [Vector3(0.0, -0.15, -0.40), Vector3(-8, 0, 0)],
	"inspect":  [Vector3(0.0, -0.05, -0.30), Vector3(-4, 0, 0)],
}

var _idle_time: float = 0.0
var _busy: bool = false
var _hand_grip: bool = false  # hands follow the anchor when true (gripping a cart)
var _rh_rest: Vector3
var _lh_rest: Vector3
var _rh_rot_rest: Vector3
var _lh_rot_rest: Vector3

func _ready() -> void:
	_rh_rest = right_hand.position
	_lh_rest = left_hand.position
	_rh_rot_rest = right_hand.rotation_degrees
	_lh_rot_rest = left_hand.rotation_degrees
	# Anchor starts at "rest" station.
	_apply_station_instant("rest")

func _process(delta: float) -> void:
	_idle_time += delta
	if _hand_grip:
		_follow_anchor()
	elif not _busy:
		_animate_idle()

# ── Idle / follow ────────────────────────────────────────────────────────────

func _animate_idle() -> void:
	if not right_hand.visible:
		return
	var t := _idle_time
	right_hand.position = _rh_rest + Vector3(
		sin(t * 7.3 + 1.0) * idle_tremor_intensity,
		sin(t * 5.1 + 2.3) * idle_tremor_intensity * 0.5,
		sin(t * 9.7 + 0.7) * idle_tremor_intensity * 0.3
	)
	left_hand.position = _lh_rest + Vector3(
		sin(t * 6.8 + 3.1) * idle_tremor_intensity,
		sin(t * 4.9 + 1.7) * idle_tremor_intensity * 0.5,
		sin(t * 8.2 + 2.5) * idle_tremor_intensity * 0.3
	)

func _follow_anchor() -> void:
	# Hands flank the anchor with a small outward + forward offset to look like they grip the cart.
	right_hand.position = hand_anchor.position + Vector3(0.08, 0.0, 0.0)
	right_hand.rotation_degrees = hand_anchor.rotation_degrees + Vector3(-10, 0, -2)
	left_hand.position = hand_anchor.position + Vector3(-0.08, 0.0, 0.0)
	left_hand.rotation_degrees = hand_anchor.rotation_degrees + Vector3(-10, 0, 2)

# ── Visibility ───────────────────────────────────────────────────────────────

func show_hands() -> void:
	right_hand.visible = true
	left_hand.visible = true

func hide_hands() -> void:
	right_hand.visible = false
	left_hand.visible = false

# ── Station-based motion ─────────────────────────────────────────────────────

func _station_transform(station: String) -> Transform3D:
	var pose: Array = STATION_POSES.get(station, STATION_POSES["rest"])
	var rot_rad := (pose[1] as Vector3) * PI / 180.0
	return Transform3D(Basis.from_euler(rot_rad), pose[0] as Vector3)

func _apply_station_instant(station: String) -> void:
	hand_anchor.transform = _station_transform(station)

func move_to_station(station: String, duration: float = 0.4) -> void:
	_busy = true
	var tween := create_tween().set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(hand_anchor, "transform", _station_transform(station), duration)
	await tween.finished
	_busy = false
	transport_complete.emit()

func move_to_world(target_global_pos: Vector3, target_global_basis: Basis, duration: float = 0.4) -> void:
	# Convert world pose to parent-local (camera-local) and tween anchor there.
	var parent := hand_anchor.get_parent() as Node3D
	if parent == null:
		return
	var parent_t := parent.global_transform
	var inv := parent_t.affine_inverse()
	var local_pos := inv * target_global_pos
	var local_basis := parent_t.basis.inverse() * target_global_basis
	var target_t := Transform3D(local_basis, local_pos)
	_busy = true
	var tween := create_tween().set_ease(Tween.EASE_IN_OUT)
	tween.tween_property(hand_anchor, "transform", target_t, duration)
	await tween.finished
	_busy = false
	transport_complete.emit()

# ── Grip state (hands follow anchor while true) ──────────────────────────────

func begin_grip() -> void:
	show_hands()
	_hand_grip = true

func release_grip() -> void:
	_hand_grip = false

# ── Insert push at current anchor pose ───────────────────────────────────────

func animate_insert_push() -> void:
	# A short forward jab in the anchor's -Z to "push" a cart into a slot.
	_busy = true
	var start_pos := hand_anchor.position
	var push_delta := hand_anchor.transform.basis.z * -0.04
	var tween := create_tween().set_ease(Tween.EASE_IN)
	tween.tween_property(hand_anchor, "position", start_pos + push_delta, 0.12)
	tween.tween_property(hand_anchor, "position", start_pos, 0.08)
	await tween.finished
	AudioManager.sound_cartridge_insert()
	_busy = false
