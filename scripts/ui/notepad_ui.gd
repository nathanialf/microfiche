extends Control

# PDA-style notepad — Marathon 2026 aesthetic
# Chunky header, ruled paper lines, typewriter-style text input
# Auto-saves to GameState

@onready var text_edit: TextEdit = $PDAFrame/NotepadArea/TextEdit
@onready var char_count: Label = $PDAFrame/StatusBar/CharCount
@onready var save_indicator: Label = $PDAFrame/StatusBar/SaveStatus
@onready var header_label: Label = $PDAFrame/Header/TitleLabel
@onready var timestamp_label: Label = $PDAFrame/Header/Timestamp
@onready var close_button: Button = $PDAFrame/Header/CloseBtn

const MAX_CHARS := 8000
const SAVE_DELAY := 1.5  # seconds of idle before auto-save

var _save_timer: float = 0.0
var _dirty: bool = false
var _last_saved_content: String = ""

func _ready() -> void:
	header_label.text = "FIELD NOTES"
	close_button.pressed.connect(queue_close)
	text_edit.text_changed.connect(_on_text_changed)
	_style_text_edit()

func _style_text_edit() -> void:
	# Monospace font, amber on dark
	text_edit.add_theme_color_override("font_color", Color(0.92, 0.78, 0.22))
	text_edit.add_theme_color_override("background_color", Color(0.04, 0.03, 0.02))
	text_edit.add_theme_color_override("caret_color", Color(1.0, 0.88, 0.3))
	text_edit.add_theme_color_override("selection_color", Color(0.3, 0.25, 0.05, 0.6))
	text_edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	text_edit.scroll_smooth = true
	text_edit.draw_tabs = true
	text_edit.draw_spaces = true

func load_notes(content: String) -> void:
	_last_saved_content = content
	text_edit.text = content
	text_edit.set_caret_line(text_edit.get_line_count())
	text_edit.set_caret_column(text_edit.get_line(text_edit.get_line_count() - 1).length())
	_update_char_count()
	_set_save_status("LOADED")

func _on_text_changed() -> void:
	if text_edit.text.length() > MAX_CHARS:
		text_edit.text = text_edit.text.substr(0, MAX_CHARS)
		text_edit.set_caret_line(text_edit.get_line_count())
	_update_char_count()
	AudioManager.sound_typewriter_key()
	_dirty = true
	_save_timer = SAVE_DELAY
	_set_save_status("...")

func _update_char_count() -> void:
	var count := text_edit.text.length()
	char_count.text = "%d / %d" % [count, MAX_CHARS]
	if count > MAX_CHARS * 0.9:
		char_count.modulate = Color(1.0, 0.4, 0.2)
	elif count > MAX_CHARS * 0.75:
		char_count.modulate = Color(1.0, 0.8, 0.3)
	else:
		char_count.modulate = Color(0.6, 0.6, 0.5)

func _process(delta: float) -> void:
	if not visible:
		return
	timestamp_label.text = _get_timestamp()
	if _dirty and _save_timer > 0.0:
		_save_timer -= delta
		if _save_timer <= 0.0:
			_auto_save()

func _auto_save() -> void:
	var content := text_edit.text
	if content == _last_saved_content:
		_dirty = false
		return
	GameState.update_notes(content)
	_last_saved_content = content
	_dirty = false
	_set_save_status("SAVED")

func _set_save_status(status: String) -> void:
	save_indicator.text = status
	match status:
		"SAVED":
			save_indicator.modulate = Color(0.5, 0.9, 0.5)
		"...":
			save_indicator.modulate = Color(0.7, 0.7, 0.3)
		"LOADED":
			save_indicator.modulate = Color(0.5, 0.7, 0.9)

func _get_timestamp() -> String:
	var t := Time.get_datetime_dict_from_system()
	return "CYCLE %d — %02d:%02d" % [GameState.current_cycle, t.hour, t.minute]

func queue_close() -> void:
	if _dirty:
		_auto_save()
	var ui := get_tree().get_first_node_in_group("microfiche_ui")
	if ui and ui.has_method("toggle_notepad"):
		ui.toggle_notepad()
