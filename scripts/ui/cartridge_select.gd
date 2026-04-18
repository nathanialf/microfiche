extends Control

signal cartridge_selected(cartridge_id: String)

const AMBER     := Color(0.96, 0.72, 0.12)
const AMBER_DIM := Color(0.48, 0.36, 0.07)
const VOID_RED  := Color(0.35, 0.08, 0.08)

@onready var grid: GridContainer = $Layout/ScrollArea/CartridgeGrid
@onready var title_label: Label  = $Layout/Header/Title
@onready var hint_label: Label   = $Layout/Footer/Hint
@onready var cancel_button: Button = $Layout/Footer/CancelBtn

func _ready() -> void:
	title_label.text = "■  SELECT CARTRIDGE"
	hint_label.text  = "[ESC] Cancel   [E / Click] Insert"
	cancel_button.pressed.connect(_on_cancel)

func populate(available_ids: Array) -> void:
	for c in grid.get_children():
		c.queue_free()
	for cid: String in available_ids:
		_add_cartridge_entry(cid)

func _add_cartridge_entry(cartridge_id: String) -> void:
	var denied   := CartridgeDatabase.is_access_denied(cartridge_id)
	var is_new   := cartridge_id in GameState.unlocked_cartridges
	var body_col := CartridgeDatabase.get_cartridge_color(cartridge_id)
	var label_printed := CartridgeDatabase.get_cartridge_label(cartridge_id)
	var label_written := CartridgeDatabase.get_handwritten_label(cartridge_id)

	var panel := PanelContainer.new()
	var vbox  := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 2)

	var bg := StyleBoxFlat.new()
	if denied:
		bg.bg_color     = Color(0.04, 0.02, 0.03)
		bg.border_color = VOID_RED
	else:
		bg.bg_color     = body_col.darkened(0.62)
		bg.border_color = body_col.darkened(0.15)
	bg.set_border_width_all(2)
	bg.set_corner_radius_all(2)
	bg.set_content_margin_all(8)
	panel.add_theme_stylebox_override("panel", bg)

	# Printed label
	var lbl := Button.new()
	lbl.text = label_printed
	lbl.flat = true
	lbl.alignment = HORIZONTAL_ALIGNMENT_LEFT
	lbl.add_theme_color_override("font_color",
		VOID_RED.lightened(0.2) if denied else body_col.lightened(0.35))
	lbl.pressed.connect(func(): cartridge_selected.emit(cartridge_id))

	# Handwritten label (italic, paper tone)
	var written_lbl := Label.new()
	written_lbl.text = label_written if not label_written.is_empty() else "—"
	written_lbl.add_theme_color_override("font_color",
		VOID_RED.darkened(0.2) if denied else Color(0.80, 0.74, 0.58))

	vbox.add_child(lbl)
	vbox.add_child(written_lbl)

	if is_new and not denied:
		var badge := Label.new()
		badge.text = "★ NEW"
		badge.add_theme_color_override("font_color", Color(0.88, 1.0, 0.38))
		vbox.add_child(badge)

	panel.add_child(vbox)
	grid.add_child(panel)

func _on_cancel() -> void:
	var ui := get_tree().get_first_node_in_group("microfiche_ui")
	if ui:
		ui.show_idle_screen()
		ui.close_and_return()
