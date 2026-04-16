extends Node3D

signal reach_complete

@export var idle_tremor_intensity: float = 0.0012

@onready var right_hand: Node3D = $RightHand
@onready var left_hand: Node3D = $LeftHand

var _idle_time: float = 0.0
var _reaching: bool = false
var _rh_rest: Vector3
var _lh_rest: Vector3
var _rh_rot_rest: Vector3
var _lh_rot_rest: Vector3

func _ready() -> void:
	_rh_rest = right_hand.position
	_lh_rest = left_hand.position
	_rh_rot_rest = right_hand.rotation_degrees
	_lh_rot_rest = left_hand.rotation_degrees

func _process(delta: float) -> void:
	_idle_time += delta
	if not _reaching:
		_animate_idle()

func _animate_idle() -> void:
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

func reach_toward(_world_target: Vector3) -> void:
	_reaching = true
	AudioManager.sound_hands_reach()

	var tween := create_tween().set_ease(Tween.EASE_IN_OUT).set_parallel(true)
	tween.tween_property(right_hand, "position", _rh_rest + Vector3(0.055, 0.038, -0.11), 0.28)
	tween.tween_property(right_hand, "rotation_degrees", _rh_rot_rest + Vector3(-18, 4, -2), 0.28)
	tween.tween_property(left_hand, "position", _lh_rest + Vector3(-0.018, 0.012, -0.04), 0.28)

	await tween.finished
	AudioManager.sound_hands_grasp()
	reach_complete.emit()

func retract() -> void:
	var tween := create_tween().set_ease(Tween.EASE_OUT).set_parallel(true)
	tween.tween_property(right_hand, "position", _rh_rest, 0.22)
	tween.tween_property(right_hand, "rotation_degrees", _rh_rot_rest, 0.22)
	tween.tween_property(left_hand, "position", _lh_rest, 0.22)
	await tween.finished
	_reaching = false

func animate_insert_cartridge() -> void:
	_reaching = true
	var t1 := create_tween().set_ease(Tween.EASE_IN_OUT).set_parallel(true)
	t1.tween_property(right_hand, "position", _rh_rest + Vector3(0.02, 0.05, -0.08), 0.18)
	t1.tween_property(left_hand, "position", _lh_rest + Vector3(-0.02, 0.05, -0.08), 0.18)
	await t1.finished

	var t2 := create_tween().set_ease(Tween.EASE_IN).set_parallel(true)
	t2.tween_property(right_hand, "position", right_hand.position + Vector3(0, 0, -0.04), 0.12)
	t2.tween_property(left_hand, "position", left_hand.position + Vector3(0, 0, -0.04), 0.12)
	await t2.finished

	AudioManager.sound_cartridge_insert()
	await get_tree().create_timer(0.08).timeout
	retract()

func animate_eject_cartridge() -> void:
	_reaching = true
	var t1 := create_tween().set_ease(Tween.EASE_OUT)
	t1.tween_property(right_hand, "position", _rh_rest + Vector3(0.02, 0.06, -0.10), 0.18)
	await t1.finished

	var t2 := create_tween().set_ease(Tween.EASE_OUT)
	t2.tween_property(right_hand, "position", _rh_rest + Vector3(0.04, 0.09, -0.02), 0.22)
	await t2.finished

	AudioManager.sound_cartridge_eject()
	retract()
