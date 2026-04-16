extends Control

# Master UI controller for the terminal screen
# Manages: boot screen, idle, cartridge select, document list, document reader, access denied, notepad

signal interaction_ended

enum TerminalState {
	BOOT,
	IDLE,
	CARTRIDGE_SELECT,
	DOCUMENT_LIST,
	DOCUMENT_READING,
	ACCESS_DENIED,
	NOTEPAD,
}

@onready var boot_screen: Control = $Screens/BootScreen
@onready var idle_screen: Control = $Screens/IdleScreen
@onready var cartridge_select: Control = $Screens/CartridgeSelect
@onready var document_list: Control = $Screens/DocumentList
@onready var document_reader: Control = $Screens/DocumentReader
@onready var access_denied_screen: Control = $Screens/AccessDenied
@onready var notepad_screen: Control = $Screens/Notepad
@onready var scanline_overlay: ColorRect = $ScanlineOverlay
@onready var notification_bar: Control = $NotificationBar

var _all_screens: Array[Control]
var _current_state: TerminalState = TerminalState.BOOT
var _current_cartridge_id: String = ""
var _previous_state: TerminalState = TerminalState.IDLE

func _ready() -> void:
	_all_screens = [
		boot_screen, idle_screen, cartridge_select,
		document_list, document_reader, access_denied_screen, notepad_screen
	]
	_hide_all()
	add_to_group("terminal_ui")
	GameState.cartridge_unlocked.connect(_on_cartridge_unlocked)
	GameState.keyword_discovered.connect(_on_keyword_discovered)
	_setup_crt_effects()
	_connect_child_signals()

func _connect_child_signals() -> void:
	cartridge_select.cartridge_selected.connect(_on_cartridge_selected_from_ui)
	document_list.document_selected.connect(_on_document_selected)
	document_reader.back_pressed.connect(_on_reader_back)

func _setup_crt_effects() -> void:
	if scanline_overlay.material:
		scanline_overlay.material.set_shader_parameter("speed", 30.0)
		scanline_overlay.material.set_shader_parameter("intensity", 0.04)

func _hide_all() -> void:
	for screen in _all_screens:
		screen.visible = false

func _show_screen(screen: Control, state: TerminalState) -> void:
	_hide_all()
	screen.visible = true
	_current_state = state
	_flash_transition()

func _flash_transition() -> void:
	var flash := ColorRect.new()
	flash.color = Color(0.9, 0.95, 0.8, 0.0)
	flash.anchors_preset = Control.PRESET_FULL_RECT
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(flash)
	var tween := create_tween()
	tween.tween_property(flash, "color:a", 0.12, 0.03)
	tween.tween_property(flash, "color:a", 0.0, 0.1)
	tween.tween_callback(flash.queue_free)

# --- Public screen transitions ---

func show_boot_screen() -> void:
	_show_screen(boot_screen, TerminalState.BOOT)
	boot_screen.play_boot_sequence()

func show_idle_screen() -> void:
	_show_screen(idle_screen, TerminalState.IDLE)

func show_cartridge_select() -> void:
	_show_screen(cartridge_select, TerminalState.CARTRIDGE_SELECT)
	cartridge_select.populate(GameState.available_cartridges)

func show_document_reader(cartridge_id: String) -> void:
	_current_cartridge_id = cartridge_id
	var docs := CartridgeDatabase.get_documents(cartridge_id)
	if docs.is_empty():
		return
	if docs.size() > 1:
		_show_screen(document_list, TerminalState.DOCUMENT_LIST)
		document_list.populate(cartridge_id, docs)
	else:
		_open_document(cartridge_id, docs[0])

func show_access_denied(_cartridge_id: String) -> void:
	_show_screen(access_denied_screen, TerminalState.ACCESS_DENIED)
	access_denied_screen.display("")
	AudioManager.sound_access_denied()

func toggle_notepad() -> void:
	if _current_state == TerminalState.NOTEPAD:
		_restore_previous_state()
	else:
		_previous_state = _current_state
		_show_screen(notepad_screen, TerminalState.NOTEPAD)
		notepad_screen.load_notes(GameState.get_notes())
		AudioManager.sound_notepad_open()

# --- Internal ---

func _on_cartridge_selected_from_ui(cartridge_id: String) -> void:
	var reader := get_tree().get_first_node_in_group("microfiche_reader")
	if reader:
		reader.insert_cartridge(cartridge_id)

func _on_document_selected(cartridge_id: String, doc: Dictionary) -> void:
	_open_document(cartridge_id, doc)

func _on_reader_back() -> void:
	var docs := CartridgeDatabase.get_documents(_current_cartridge_id)
	if docs.size() > 1:
		_show_screen(document_list, TerminalState.DOCUMENT_LIST)
		document_list.populate(_current_cartridge_id, docs)
	else:
		show_idle_screen()
		close_and_return()

func _open_document(cartridge_id: String, doc: Dictionary) -> void:
	_show_screen(document_reader, TerminalState.DOCUMENT_READING)
	document_reader.display_document(cartridge_id, doc)
	GameState.mark_document_read(doc.get("id", ""))
	_scan_document_keywords_deferred(doc)

func _scan_document_keywords_deferred(doc: Dictionary) -> void:
	# Wait a moment before scanning — reward for actually reading
	await get_tree().create_timer(3.0).timeout
	if _current_state == TerminalState.DOCUMENT_READING:
		var full_text := _flatten_document_text(doc)
		var found := CartridgeDatabase.scan_for_keywords(full_text)
		for keyword in found:
			if keyword not in GameState.discovered_keywords:
				GameState.discover_keyword(keyword)

func _flatten_document_text(doc: Dictionary) -> String:
	var text: String = str(doc.get("title", "")) + " " + str(doc.get("subtitle", "")) + " "
	for section: Dictionary in doc.get("sections", []):
		text += section.get("heading", "") + " " + section.get("body", "") + " "
	for kw in doc.get("keywords", []):
		text += kw + " "
	return text

func _restore_previous_state() -> void:
	match _previous_state:
		TerminalState.DOCUMENT_READING:
			show_document_reader(_current_cartridge_id)
		TerminalState.DOCUMENT_LIST:
			show_document_reader(_current_cartridge_id)
		_:
			show_idle_screen()

func _on_cartridge_unlocked(cartridge_id: String) -> void:
	notification_bar.show_notification(
		"NEW CARTRIDGE LOCATED: %s" % CartridgeDatabase.get_cartridge_label(cartridge_id),
		Color(0.6, 1.0, 0.6)
	)
	AudioManager.sound_keyword_discovered()

func _on_keyword_discovered(keyword: String, _unlocked: String) -> void:
	notification_bar.show_notification(
		"KEYWORD INDEXED: %s" % keyword.to_upper(),
		Color(0.8, 0.9, 0.6)
	)

func close_and_return() -> void:
	emit_signal("interaction_ended")

func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("ui_cancel"):
		match _current_state:
			TerminalState.DOCUMENT_READING:
				_on_reader_back()
			TerminalState.DOCUMENT_LIST:
				show_idle_screen()
				close_and_return()
			TerminalState.CARTRIDGE_SELECT:
				show_idle_screen()
				close_and_return()
			TerminalState.ACCESS_DENIED:
				show_idle_screen()
				close_and_return()
			TerminalState.NOTEPAD:
				toggle_notepad()
	if event.is_action_pressed("open_notepad"):
		toggle_notepad()
