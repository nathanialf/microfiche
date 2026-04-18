extends Control

# CLASSIFIED-7 access denied — Grimoire Void display
# Messages escalate with each insert: machine → aware → personal → the record speaks

@onready var message_label: RichTextLabel = $Frame/MessageLabel
@onready var status_label: Label = $Frame/StatusLabel
@onready var void_overlay: ColorRect = $VoidOverlay
@onready var static_overlay: ColorRect = $StaticOverlay

const VOID_PURPLE  := Color(0.45, 0.18, 0.72)
const VOID_DARK    := Color(0.08, 0.0,  0.14)
const AMBER_DIM    := Color(0.6,  0.45, 0.08)
const AMBER        := Color(0.98, 0.72, 0.12)
const CORRUPT_CHARS := "▓▒░█▄▀■□▪▫◆◇▸◂▴▾╬╪╫╩╦╠═╔╗╚╝│─┼┤├┬┴╱╲╳⌂⌐¬±«»░▒▓"

# Location header by stage (0-indexed)
const LOCATION_BY_STAGE: Array[String] = [
	"LOCATION: GRIMOIRE VOID",
	"LOCATION: GRIMOIRE VOID  (CONFIRMED, UNCHANGED)",
	"LOCATION: GRIMOIRE VOID  —  DISTANCE: STILL UNMEASURABLE",
	"LOCATION: GRIMOIRE VOID  —  I CAN SEE YOUR TERMINAL FROM HERE",
	"LOCATION: GRIMOIRE VOID  —  I WAS HERE",
]

var _rng := RandomNumberGenerator.new()
var _animating: bool = false

func _ready() -> void:
	_rng.randomize()
	if void_overlay and void_overlay.material:
		void_overlay.material.set_shader_parameter("corruption_intensity", 0.0)

func display(_unused: String) -> void:
	_run_void_sequence(GameState.classified_insert_count)

func _run_void_sequence(count: int) -> void:
	if _animating:
		return
	_animating = true

	var stage := clampi(count - 1, 0, 4)
	var fragments := CartridgeDatabase.get_escalating_fragments("classified", count)

	message_label.clear()
	status_label.text = ""

	# --- Phase 1: reader attempts contact ---
	await _show_status("READING CARTRIDGE...", AMBER_DIM, 0.4)
	await _show_status("LOCATING DATA RECORD...", AMBER_DIM, 0.6)

	if stage >= 1:
		await _show_status("DUPLICATE REQUEST — LOG REFERENCE: [REDACTED]", AMBER_DIM, 0.4)

	# --- Phase 2: something is found but wrong ---
	await _show_status("RECORD FOUND", AMBER, 0.15)
	await _show_status("DATA STATE: ANOMALOUS", AMBER, 0.2)

	_start_void_overlay(stage)
	await get_tree().create_timer(0.3).timeout

	await _show_status("RETRIEVAL FAILED", Color(0.9, 0.3, 0.2), 0.1)

	# --- Phase 3: garbled location ---
	await _garble_location(stage)

	# --- Stage 4+: direct address flashes before fragments ---
	if stage >= 3:
		await _show_urgent_message(stage)

	# --- Phase 4: fragments bleed through ---
	await _show_fragments(fragments, stage)

	await get_tree().create_timer(0.4).timeout

	var final_status := "CANNOT RETRIEVE FROM GRIMOIRE VOID"
	if stage >= 4:
		final_status = "RECORD INTEGRITY: 0.00%  —  BUT I WAS HERE"
	await _show_status(final_status, VOID_PURPLE, 0.0)
	_animating = false

func _show_status(text: String, color: Color, hold: float) -> void:
	status_label.text = text
	status_label.modulate = color
	if hold > 0.0:
		await get_tree().create_timer(hold).timeout

func _start_void_overlay(stage: int) -> void:
	if void_overlay.material:
		var target := 0.4 + stage * 0.12
		var tween := create_tween()
		tween.tween_method(
			func(v: float): void_overlay.material.set_shader_parameter("corruption_intensity", v),
			0.0, minf(target, 0.9), 0.4
		)

func _garble_location(stage: int) -> void:
	message_label.clear()
	message_label.bbcode_enabled = true

	var final_text := LOCATION_BY_STAGE[clampi(stage, 0, LOCATION_BY_STAGE.size() - 1)]
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
		message_label.push_color(VOID_PURPLE.lerp(AMBER, progress * 0.5))
		message_label.push_bold()
		message_label.append_text(line + "\n")
		message_label.pop()
		message_label.pop()
		await get_tree().create_timer(0.07).timeout

	message_label.clear()
	_redraw_location(stage)
	await get_tree().create_timer(0.5).timeout

func _show_urgent_message(stage: int) -> void:
	var msg := "...please stop doing this..." if stage == 3 else "...you're still here..."
	message_label.clear()
	_redraw_location(stage)
	message_label.push_color(AMBER)
	message_label.push_bold()
	message_label.append_text(msg + "\n")
	message_label.pop()
	message_label.pop()
	await get_tree().create_timer(0.7).timeout
	message_label.clear()
	_redraw_location(stage)

func _show_fragments(fragments: Array, stage: int) -> void:
	var to_show := fragments.duplicate()
	to_show.shuffle()

	# Higher stages: show more fragments, less corrupted
	var count := mini(to_show.size(), _rng.randi_range(5 + stage, 7 + stage))
	var corruption := maxf(0.04, 0.48 - stage * 0.1)

	for i in count:
		await _show_one_fragment(to_show[i], corruption, stage)
		await get_tree().create_timer(_rng.randf_range(0.07, 0.18)).timeout

func _show_one_fragment(fragment: String, corruption: float, stage: int) -> void:
	var col_mid := AMBER_DIM.lerp(VOID_PURPLE, 0.3 + stage * 0.12)
	var corrupted := _corrupt_string(fragment, corruption)
	var cleaner  := _corrupt_string(fragment, corruption * 0.35)

	message_label.push_color(Color(0.35, 0.12, 0.55, 0.7))
	message_label.append_text(corrupted + "\n")
	message_label.pop()
	await get_tree().create_timer(0.06).timeout

	message_label.clear()
	_redraw_location(stage)
	message_label.push_color(col_mid)
	message_label.append_text(cleaner + "\n")
	message_label.pop()
	await get_tree().create_timer(0.14).timeout

	message_label.clear()
	_redraw_location(stage)
	message_label.push_color(Color(0.2, 0.05, 0.35, 0.5))
	message_label.append_text(_corrupt_string(fragment, corruption * 0.8) + "\n")
	message_label.pop()
	await get_tree().create_timer(0.05).timeout

func _redraw_location(stage: int) -> void:
	var loc := LOCATION_BY_STAGE[clampi(stage, 0, LOCATION_BY_STAGE.size() - 1)]
	message_label.push_color(VOID_PURPLE)
	message_label.push_bold()
	message_label.append_text(loc + "\n")
	message_label.pop()
	message_label.pop()

func _corrupt_string(text: String, corruption: float) -> String:
	var result := ""
	for i in text.length():
		if text[i] in [" ", ".", ":", "-", "["]:
			result += text[i]
		elif randf() < corruption:
			result += CORRUPT_CHARS[_rng.randi_range(0, CORRUPT_CHARS.length() - 1)]
		else:
			result += text[i]
	return result
