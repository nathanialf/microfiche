extends Control

signal document_selected(cartridge_id: String, doc: Dictionary)

const AMBER     := Color(0.96, 0.72, 0.12)
const AMBER_DIM := Color(0.48, 0.36, 0.07)
const READ_COL  := Color(0.45, 0.40, 0.30)

@onready var list: VBoxContainer = $Layout/ScrollArea/List
@onready var title_label: Label  = $Layout/Header/Title
@onready var back_btn: Button    = $Layout/Footer/BackBtn

var _cartridge_id: String = ""

func _ready() -> void:
	back_btn.pressed.connect(_on_back)

func populate(cartridge_id: String, docs: Array) -> void:
	_cartridge_id = cartridge_id
	for c in list.get_children():
		c.queue_free()

	title_label.text = "■  %s  —  SELECT DOCUMENT" % CartridgeDatabase.get_cartridge_label(cartridge_id)

	for doc: Dictionary in docs:
		var container := VBoxContainer.new()
		container.add_theme_constant_override("separation", 1)

		var btn := Button.new()
		var title: String = doc.get("title", "UNTITLED")
		var cls: String   = doc.get("classification", "")
		var page: String  = doc.get("page", "---")
		var is_read: bool = doc.get("id", "") in GameState.read_documents

		btn.text = "PAGE %s  —  %s" % [page, title]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.flat = false
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_color_override("font_color", READ_COL if is_read else AMBER)

		var cls_lbl := Label.new()
		cls_lbl.text = "             [%s]%s" % [cls, "  (READ)" if is_read else ""]
		cls_lbl.add_theme_color_override("font_color", AMBER_DIM)

		btn.pressed.connect(func(): document_selected.emit(_cartridge_id, doc))
		container.add_child(btn)
		container.add_child(cls_lbl)
		list.add_child(container)

		var sep := HSeparator.new()
		list.add_child(sep)

func _on_back() -> void:
	var ui := get_tree().get_first_node_in_group("terminal_ui")
	if ui:
		ui.show_idle_screen()
		ui.close_and_return()
