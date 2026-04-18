extends Control

# Master UI controller for the microfiche screen.
# Manages: boot screen, idle, document reader, access denied.
#
# This UI does NOT drive the player's camera — that's owned by Player (view mode).

enum UIState {
	BOOT,
	IDLE,
	DOCUMENT_READING,
	ACCESS_DENIED,
}

@onready var boot_screen: Control = $Screens/BootScreen
@onready var idle_screen: Control = $Screens/IdleScreen
@onready var document_reader: Control = $Screens/DocumentReader
@onready var access_denied_screen: Control = $Screens/AccessDenied
@onready var scanline_overlay: ColorRect = $ScanlineOverlay
@onready var notification_bar: Control = $NotificationBar

var _all_screens: Array[Control]
var _current_state: UIState = UIState.BOOT
var _current_cartridge_id: String = ""

func _ready() -> void:
	_all_screens = [boot_screen, idle_screen, document_reader, access_denied_screen]
	_hide_all()
	add_to_group("microfiche_ui")
	GameState.cartridge_unlocked.connect(_on_cartridge_unlocked)
	GameState.keyword_discovered.connect(_on_keyword_discovered)
	_setup_crt_effects()
	print("[microfiche_ui] _ready; screens=", _all_screens.size(), " size=", size)

func _setup_crt_effects() -> void:
	if scanline_overlay.material:
		scanline_overlay.material.set_shader_parameter("speed", 30.0)
		scanline_overlay.material.set_shader_parameter("intensity", 0.04)

func _hide_all() -> void:
	for screen in _all_screens:
		screen.visible = false

func _show_screen(screen: Control, state: UIState) -> void:
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
	_show_screen(boot_screen, UIState.BOOT)
	boot_screen.play_boot_sequence()

func show_idle_screen() -> void:
	_show_screen(idle_screen, UIState.IDLE)

func show_document_reader(cartridge_id: String) -> void:
	_current_cartridge_id = cartridge_id
	var docs := CartridgeDatabase.get_documents(cartridge_id)
	print("[microfiche_ui] show_document_reader: ", cartridge_id, " docs=", docs.size())
	if docs.is_empty():
		return
	_open_document(cartridge_id, docs[0])

func show_access_denied(_cartridge_id: String) -> void:
	_show_screen(access_denied_screen, UIState.ACCESS_DENIED)
	access_denied_screen.display("")
	AudioManager.sound_access_denied()

# --- Internal ---

func _open_document(cartridge_id: String, doc: Dictionary) -> void:
	_show_screen(document_reader, UIState.DOCUMENT_READING)
	document_reader.display_document(cartridge_id, doc)
	GameState.mark_document_read(doc.get("id", ""))
	_scan_document_keywords_deferred(doc)

func _scan_document_keywords_deferred(doc: Dictionary) -> void:
	# Wait a moment before scanning — reward for actually reading
	await get_tree().create_timer(3.0).timeout
	if _current_state == UIState.DOCUMENT_READING:
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

# Kept for UI components that previously dismissed via close_and_return.
# In the new model the player owns camera/view-mode; UI just navigates within
# itself (caller expects it to return us to a sensible default screen).
func close_and_return() -> void:
	if _current_state not in [UIState.IDLE, UIState.BOOT]:
		show_idle_screen()

# ESC no longer dismisses the document reader — the cart is still physically in
# the slot and the player must eject it to return to idle. Left as a stub so
# other systems can still poll _current_state without any behaviour change here.
