extends Control

# CRT query terminal — the LeftTerminal 3D node captures keyboard input directly
# and drives this UI via set_input_text(). This script is purely display:
# scrolling history (RichTextLabel BBCode) + a buffer line with a blinking
# underscore caret (Label). No LineEdit, no focus plumbing.

@onready var history: RichTextLabel = $VBox/History
@onready var input: Label = $VBox/InputRow/Input
@onready var prompt_prefix: Label = $VBox/InputRow/PromptPrefix

const PHOSPHOR := Color(0.20, 0.95, 0.28)
const PHOSPHOR_DIM := Color(0.10, 0.55, 0.16)
const ACCEPTED := Color(0.55, 1.0, 0.65)
const ERROR := Color(1.0, 0.46, 0.26)
const WARN := Color(1.0, 0.82, 0.28)

const CARET_BLINK_RATE := 0.5  # seconds between on/off

var _input_text: String = ""
var _caret_on: bool = true
var _caret_timer: float = 0.0
var _caret_active: bool = true  # false when terminal is dispensing / offline

func _ready() -> void:
	history.bbcode_enabled = true
	history.fit_content = false
	history.scroll_active = true
	history.scroll_following = true
	history.focus_mode = Control.FOCUS_NONE
	_print_boot_lines()
	show_prompt()

func _process(delta: float) -> void:
	if not _caret_active:
		return
	_caret_timer += delta
	if _caret_timer >= CARET_BLINK_RATE:
		_caret_timer = 0.0
		_caret_on = not _caret_on
		_render_input()

func _print_boot_lines() -> void:
	_append_raw(_color_tag(PHOSPHOR, "ARCHIVIST QUERY TERMINAL  v2.3"))
	_append_raw(_color_tag(PHOSPHOR_DIM, "READY."))

func _append_raw(bbcode_line: String) -> void:
	history.append_text(bbcode_line + "\n")

func _color_tag(c: Color, text: String) -> String:
	return "[color=#%s]%s[/color]" % [c.to_html(false), text]

func _render_input() -> void:
	var caret := "_" if (_caret_active and _caret_on) else " "
	input.text = _input_text + caret

# ── Public API called by LeftTerminal ─────────────────────────────────────────

# Called every time the terminal's query buffer changes.
func set_input_text(t: String) -> void:
	_input_text = t
	_caret_on = true
	_caret_timer = 0.0
	_render_input()

func show_prompt() -> void:
	_caret_active = true
	_input_text = ""
	_append_raw(_color_tag(PHOSPHOR, "> ENTER QUERY:"))
	_render_input()

func show_invalid(keyword: String) -> void:
	_caret_active = true
	_input_text = ""
	_append_raw(_color_tag(ERROR, "> UNRECOGNIZED QUERY: ") + _color_tag(PHOSPHOR, keyword))
	_render_input()

func show_already_dispensed(keyword: String, cart_label: String) -> void:
	_caret_active = true
	_input_text = ""
	_append_raw(
		_color_tag(WARN, "> RECORD ALREADY RELEASED") +
		_color_tag(PHOSPHOR_DIM, "  — SEE SHELF (") +
		_color_tag(PHOSPHOR, cart_label) +
		_color_tag(PHOSPHOR_DIM, ") / query: ") +
		_color_tag(PHOSPHOR_DIM, keyword)
	)
	_render_input()

func show_dispensing(keyword: String, cart_label: String) -> void:
	_caret_active = false
	_input_text = ""
	_append_raw(_color_tag(ACCEPTED, "> QUERY ACCEPTED: ") + _color_tag(PHOSPHOR, keyword))
	_append_raw(_color_tag(ACCEPTED, "> DISPENSING ") + _color_tag(PHOSPHOR, cart_label) + _color_tag(ACCEPTED, "…"))
	_render_input()

func show_offline() -> void:
	_caret_active = false
	_input_text = ""
	_append_raw(_color_tag(PHOSPHOR_DIM, "> STANDBY."))
	_render_input()
