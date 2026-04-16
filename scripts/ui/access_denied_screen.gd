extends Control

# CLASSIFIED-7 access denied — Grimoire Void display
# The data exists. The reader finds it. It cannot reach it.
# Garbled corruption with fragments of the real content bleeding through.

@onready var message_label: RichTextLabel = $Frame/MessageLabel
@onready var status_label: Label = $Frame/StatusLabel
@onready var void_overlay: ColorRect = $VoidOverlay
@onready var static_overlay: ColorRect = $StaticOverlay

const VOID_PURPLE := Color(0.45, 0.18, 0.72)
const VOID_DARK := Color(0.08, 0.0, 0.14)
const AMBER_DIM := Color(0.6, 0.45, 0.08)
const AMBER := Color(0.98, 0.72, 0.12)

# Corruption character pool
const CORRUPT_CHARS := "▓▒░█▄▀■□▪▫◆◇▸◂▴▾╬╪╫╩╦╠═╔╗╚╝│─┼┤├┬┴╱╲╳⌂⌐¬±«»░▒▓"
const VOID_GLYPHS := "⣿⣾⣽⣻⢿⡿⣟⣯⣷⠿⠻⠽⠾⠿"

var _rng := RandomNumberGenerator.new()
var _fragments: Array = []
var _animating: bool = false

func _ready() -> void:
	_rng.randomize()
	if void_overlay and void_overlay.material:
		void_overlay.material.set_shader_parameter("corruption_intensity", 0.0)

func display(_unused_message: String) -> void:
	_fragments = CartridgeDatabase.get_void_fragments("classified")
	_run_void_sequence()

func _run_void_sequence() -> void:
	if _animating:
		return
	_animating = true

	message_label.clear()
	status_label.text = ""

	# Phase 1: reader attempts contact
	await _show_status("READING CARTRIDGE...", AMBER_DIM, 0.4)
	await _show_status("LOCATING DATA RECORD...", AMBER_DIM, 0.6)

	# Phase 2: something is found but wrong
	await _show_status("RECORD FOUND", AMBER, 0.15)
	await _show_status("DATA STATE: ANOMALOUS", AMBER, 0.2)

	# Phase 3: void corruption starts
	_start_void_overlay()
	await get_tree().create_timer(0.3).timeout

	await _show_status("RETRIEVAL FAILED", Color(0.9, 0.3, 0.2), 0.1)

	# Phase 4: garbled location data
	await _garble_location()

	# Phase 5: fragments bleed through
	await _show_fragments()

	# Phase 6: terminal gives up
	await get_tree().create_timer(0.4).timeout
	await _show_status("CANNOT RETRIEVE FROM GRIMOIRE VOID", VOID_PURPLE, 0.0)
	_animating = false

func _show_status(text: String, color: Color, hold: float) -> void:
	status_label.text = text
	status_label.modulate = color
	if hold > 0.0:
		await get_tree().create_timer(hold).timeout

func _start_void_overlay() -> void:
	if void_overlay.material:
		var tween := create_tween()
		tween.tween_method(
			func(v: float): void_overlay.material.set_shader_parameter("corruption_intensity", v),
			0.0, 0.7, 0.4
		)

func _garble_location() -> void:
	message_label.clear()
	message_label.bbcode_enabled = true

	# Show location resolving through corruption — from pure noise down to readable
	var final_text := "LOCATION: GRIMOIRE VOID"
	var steps := 14

	for i in steps:
		message_label.clear()
		var progress := float(i) / float(steps - 1)
		var line := ""

		for j in final_text.length():
			if randf() < progress:
				line += final_text[j]
			else:
				line += CORRUPT_CHARS[_rng.randi_range(0, CORRUPT_CHARS.length() - 1)]

		message_label.push_color(VOID_PURPLE.lerp(AMBER, progress))
		message_label.push_bold()
		message_label.append_text(line + "\n")
		message_label.pop()
		message_label.pop()

		await get_tree().create_timer(0.07).timeout

	# Hold the resolved text
	message_label.clear()
	message_label.push_color(VOID_PURPLE)
	message_label.push_bold()
	message_label.append_text("LOCATION: GRIMOIRE VOID\n")
	message_label.pop()
	message_label.pop()
	await get_tree().create_timer(0.5).timeout

func _show_fragments() -> void:
	# Fragments of the real content bleed through, garbled, in sequence
	var to_show := _fragments.duplicate()
	to_show.shuffle()

	# Show 6-8 fragments
	var count := mini(to_show.size(), _rng.randi_range(6, 8))

	for i in count:
		var fragment: String = to_show[i]
		await _show_one_fragment(fragment)
		await get_tree().create_timer(_rng.randf_range(0.08, 0.22)).timeout

func _show_one_fragment(fragment: String) -> void:
	# Each fragment flickers in partially corrupted then fades
	var corrupted := _corrupt_string(fragment, 0.45)
	var less_corrupt := _corrupt_string(fragment, 0.15)

	# Flash corrupted
	message_label.push_color(Color(0.35, 0.12, 0.55, 0.7))
	message_label.append_text(corrupted + "\n")
	message_label.pop()
	await get_tree().create_timer(0.06).timeout

	# Resolve slightly
	message_label.clear()
	_redraw_location()
	message_label.push_color(AMBER_DIM.lerp(VOID_PURPLE, 0.5))
	message_label.append_text(less_corrupt + "\n")
	message_label.pop()
	await get_tree().create_timer(0.12).timeout

	# Collapse back to noise
	message_label.clear()
	_redraw_location()
	message_label.push_color(Color(0.2, 0.05, 0.35, 0.5))
	message_label.append_text(_corrupt_string(fragment, 0.85) + "\n")
	message_label.pop()
	await get_tree().create_timer(0.05).timeout

func _redraw_location() -> void:
	message_label.push_color(VOID_PURPLE)
	message_label.push_bold()
	message_label.append_text("LOCATION: GRIMOIRE VOID\n")
	message_label.pop()
	message_label.pop()

func _corrupt_string(text: String, corruption: float) -> String:
	var result := ""
	for i in text.length():
		if text[i] == " " or text[i] == "." or text[i] == ":":
			result += text[i]
		elif randf() < corruption:
			result += CORRUPT_CHARS[_rng.randi_range(0, CORRUPT_CHARS.length() - 1)]
		else:
			result += text[i]
	return result
