extends Control

const AMBER        := Color(0.20, 0.95, 0.28)   # phosphor green — main text
const AMBER_DIM    := Color(0.08, 0.52, 0.14)   # dim green
const AMBER_BRIGHT := Color(0.65, 1.00, 0.72)   # bright green highlight
const DIVIDER_COL  := Color(0.08, 0.38, 0.12)   # dark green divider

@onready var header_label: RichTextLabel        = $Layout/HeaderMargin/Header
@onready var class_label: Label                 = $Layout/ClassificationMargin/ClassificationBar/ClassLabel
@onready var page_label: Label                  = $Layout/ClassificationMargin/ClassificationBar/PageNum
@onready var main_area: MarginContainer         = $Layout/MainArea
@onready var content_label: RichTextLabel       = $Layout/MainArea/Content
@onready var tags_bar: HBoxContainer            = $Layout/TagsMargin/TagsBar
@onready var scroll_hint: Label                 = $Layout/FooterMargin/FooterBar/ScrollHint
@onready var ticker_top: Control                = $Layout/PlaceholderTicker
@onready var ticker_top_bg: ColorRect           = $Layout/PlaceholderTicker/Bg
@onready var ticker_top_label: Label            = $Layout/PlaceholderTicker/TickerLabel
@onready var ticker_bottom: Control             = $Layout/PlaceholderTickerBottom
@onready var ticker_bottom_bg: ColorRect        = $Layout/PlaceholderTickerBottom/Bg
@onready var ticker_bottom_label: Label         = $Layout/PlaceholderTickerBottom/TickerLabel

const TICKER_SPEED_PX := 55.0  # pixels per second
const TICKER_SEGMENT  := "▓  PLACEHOLDER — CONTENT NOT FINAL  ▓    "
const TICKER_REPEATS  := 24  # enough repeats that the wrap point is always far off-screen

const REVEAL_CPS := 900.0  # characters per second for the boot-style doc reveal
const REVEAL_MAX_SECONDS := 2.5

var _current_doc: Dictionary = {}
var _cartridge_id: String = ""
var _ticker_offset: float = 0.0
var _ticker_segment_width: float = 0.0
var _reveal_tween: Tween = null

func _ready() -> void:
	# Keep autowrap on as a safety net for table cells, which compute column
	# widths at render time and can't be pre-wrapped from GDScript. For plain
	# paragraphs we pre-wrap manually (see _wrap_text) because Godot 4 autowrap
	# has been unreliable inside a SubViewport-hosted RTL in this project.
	content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ticker_top.resized.connect(_layout_ticker_bg)
	ticker_bottom.resized.connect(_layout_ticker_bg)
	ticker_top_label.resized.connect(_recompute_ticker_segment)

func display_document(cartridge_id: String, doc: Dictionary) -> void:
	_cartridge_id = cartridge_id
	_current_doc = doc

	_render_header(doc)
	_render_classification(doc)
	_render_tags(doc)
	_render_ticker(doc)

	# Wait one frame so main_area has a real width before we measure wrap.
	await get_tree().process_frame
	_render_content(doc)

	_reset_scroll()
	scroll_hint.text = "↑↓ or wheel to scroll"
	_debug_log_content_size()
	_start_content_reveal()

func _debug_log_content_size() -> void:
	print("[doc_reader] main_area=", main_area.size,
		" content=", content_label.size,
		" wrap_px=", _wrap_width_px())

func _wrap_width_px() -> float:
	var margin_l: int = main_area.get_theme_constant("margin_left")
	var margin_r: int = main_area.get_theme_constant("margin_right")
	return maxf(0.0, main_area.size.x - margin_l - margin_r)

func _reset_scroll() -> void:
	var bar := content_label.get_v_scroll_bar()
	if bar:
		bar.value = 0

func _render_header(doc: Dictionary) -> void:
	header_label.clear()
	header_label.push_color(AMBER_BRIGHT)
	header_label.push_bold()
	header_label.append_text("■  " + doc.get("title", "UNTITLED") + "\n")
	header_label.pop()
	var sub: String = doc.get("subtitle", "")
	if not sub.is_empty():
		header_label.push_color(AMBER_DIM)
		header_label.append_text(sub + "\n")
		header_label.pop()
	header_label.pop()

func _render_classification(doc: Dictionary) -> void:
	var cls: String = doc.get("classification", "UNCLASSIFIED")
	class_label.text = "◈  " + cls + "  ◈"
	page_label.text  = "PAGE " + doc.get("page", "---")
	match cls:
		"OMEGA LEVEL":      class_label.modulate = Color(1.0, 0.25, 0.20)
		"RESTRICTED":       class_label.modulate = Color(1.0, 0.65, 0.18)
		"INTERNAL USE ONLY":class_label.modulate = Color(0.65, 0.88, 0.55)
		_:                  class_label.modulate = AMBER_DIM

func _render_content(doc: Dictionary) -> void:
	content_label.clear()
	var sections: Array = doc.get("sections", [])

	for i in sections.size():
		var sec: Dictionary = sections[i]

		# Section heading
		content_label.push_color(AMBER_BRIGHT)
		content_label.push_bold()
		content_label.append_text("▸  " + sec.get("heading", "") + "\n")
		content_label.pop()
		content_label.pop()
		content_label.push_color(AMBER)

		# Section body: prefer typed blocks if present, otherwise fall back to
		# the flat body string (legacy).
		var blocks: Array = sec.get("blocks", [])
		if not blocks.is_empty():
			for block: Dictionary in blocks:
				_render_block(block)
		else:
			_append_wrapped(sec.get("body", ""))
			content_label.append_text("\n")

		content_label.pop()

		if i < sections.size() - 1:
			content_label.push_color(DIVIDER_COL)
			content_label.append_text("\n────────────────────────────────\n\n")
			content_label.pop()

func _render_block(block: Dictionary) -> void:
	match block.get("type", "paragraph"):
		"paragraph":
			_append_wrapped(block.get("text", ""))
			content_label.append_text("\n\n")
		"table":
			_render_table_block(block)
		"list":
			_render_list_block(block)
		_:
			_append_wrapped(str(block.get("text", "")))
			content_label.append_text("\n\n")

func _render_table_block(block: Dictionary) -> void:
	var columns: Array = block.get("columns", [])
	var rows: Array = block.get("rows", [])
	if columns.is_empty() or rows.is_empty():
		return
	var n := columns.size()
	# Optional per-column expand ratios. Default: all 1 (equal share).
	var ratios: Array = block.get("column_ratios", [])
	content_label.append_text("\n")
	content_label.push_table(n)
	# Tell the table to share the available width across columns so long cells
	# wrap inside their column instead of blowing the table past the viewport.
	for col_idx in n:
		var ratio: int = int(ratios[col_idx]) if col_idx < ratios.size() else 1
		content_label.set_table_column_expand(col_idx, true, ratio)
	# Header row
	for col in columns:
		content_label.push_cell()
		content_label.push_color(AMBER_BRIGHT)
		content_label.push_bold()
		content_label.append_text(str(col))
		content_label.pop()
		content_label.pop()
		content_label.pop()
	# Data rows (table cells rely on Godot's built-in autowrap — pre-wrap would
	# need the column's final width which isn't known until render time).
	for row: Array in rows:
		for col_idx in n:
			content_label.push_cell()
			var cell_text: String = str(row[col_idx]) if col_idx < row.size() else ""
			content_label.append_text(cell_text)
			content_label.pop()
	content_label.pop()
	content_label.append_text("\n")

func _render_list_block(block: Dictionary) -> void:
	var items: Array = block.get("items", [])
	var ordered: bool = block.get("ordered", false)
	for i in items.size():
		var prefix := "%d. " % (i + 1) if ordered else "•  "
		_append_wrapped(prefix + str(items[i]))
		content_label.append_text("\n")
	content_label.append_text("\n")

# Manual pre-wrap. Godot 4 RichTextLabel autowrap has been unreliable in this
# project (three scene/config attempts failed). Measuring the font and
# inserting \n at word boundaries is the guaranteed-correct fallback.
func _append_wrapped(text: String) -> void:
	content_label.append_text(_wrap_text(text))

func _wrap_text(text: String) -> String:
	var width := _wrap_width_px()
	if width <= 0.0 or text.is_empty():
		return text
	var font := content_label.get_theme_font("normal_font", "RichTextLabel")
	var fsize: int = content_label.get_theme_font_size("normal_font_size", "RichTextLabel")
	if font == null or fsize <= 0:
		return text

	var out: PackedStringArray = PackedStringArray()
	for paragraph in text.split("\n", true):
		out.append(_wrap_paragraph(paragraph, font, fsize, width))
	return "\n".join(out)

func _wrap_paragraph(paragraph: String, font: Font, fsize: int, width: float) -> String:
	if paragraph.is_empty():
		return paragraph
	var words := paragraph.split(" ", true)
	var lines: PackedStringArray = PackedStringArray()
	var current := ""
	for word: String in words:
		var candidate := word if current.is_empty() else current + " " + word
		var w := font.get_string_size(candidate, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		if w <= width or current.is_empty():
			current = candidate
		else:
			lines.append(current)
			current = word
	if not current.is_empty():
		lines.append(current)
	return "\n".join(lines)

func _render_tags(doc: Dictionary) -> void:
	for c in tags_bar.get_children():
		c.queue_free()
	for tag: String in doc.get("tags", []):
		var lbl := Label.new()
		lbl.text = " " + tag + " "
		lbl.add_theme_color_override("font_color", AMBER_DIM)
		tags_bar.add_child(lbl)

func _render_ticker(doc: Dictionary) -> void:
	var is_placeholder: bool = doc.get("placeholder", false)
	ticker_top.visible = is_placeholder
	ticker_bottom.visible = is_placeholder
	if is_placeholder:
		# Fill the label with many back-to-back copies so the seam at wrap time
		# is always far off-screen — the player sees one continuous stream.
		# The ticker roots are plain Controls, not Containers, so we manually
		# snap each label's size to its content (reset_size) and pin its origin.
		var filled := TICKER_SEGMENT.repeat(TICKER_REPEATS)
		ticker_top_label.text = filled
		ticker_bottom_label.text = filled
		ticker_top_label.position = Vector2.ZERO
		ticker_bottom_label.position = Vector2.ZERO
		ticker_top_label.reset_size()
		ticker_bottom_label.reset_size()
		_ticker_offset = 0.0
		_layout_ticker_bg()
		_recompute_ticker_segment()

func _layout_ticker_bg() -> void:
	ticker_top_bg.position = Vector2.ZERO
	ticker_top_bg.size = ticker_top.size
	ticker_bottom_bg.position = Vector2.ZERO
	ticker_bottom_bg.size = ticker_bottom.size

func _recompute_ticker_segment() -> void:
	# One copy's width. When the offset has scrolled past this we snap back by
	# the same amount — the next segment is already under the cursor, so the
	# snap is invisible and the stream appears continuous.
	_ticker_segment_width = ticker_top_label.size.x / float(TICKER_REPEATS)

func _process(delta: float) -> void:
	if not ticker_top.visible or _ticker_segment_width <= 0.0:
		return
	_ticker_offset -= TICKER_SPEED_PX * delta
	if _ticker_offset <= -_ticker_segment_width:
		_ticker_offset += _ticker_segment_width
	ticker_top_label.position.x = _ticker_offset
	ticker_bottom_label.position.x = _ticker_offset

func _start_content_reveal() -> void:
	# Boot-style reveal: tween the RichTextLabel's visible_ratio from 0 to 1
	# so characters stream in.
	if _reveal_tween and _reveal_tween.is_valid():
		_reveal_tween.kill()
	var total := content_label.get_total_character_count()
	if total <= 0:
		content_label.visible_ratio = 1.0
		return
	content_label.visible_ratio = 0.0
	var duration := clampf(float(total) / REVEAL_CPS, 0.4, REVEAL_MAX_SECONDS)
	_reveal_tween = create_tween()
	_reveal_tween.tween_property(content_label, "visible_ratio", 1.0, duration)

func _line_step() -> int:
	var fs: int = content_label.get_theme_font_size("normal_font_size", "RichTextLabel")
	if fs <= 0:
		fs = 10
	var sep: int = content_label.get_theme_constant("line_separation", "RichTextLabel")
	return maxi(fs + sep, 8)

func _input(event: InputEvent) -> void:
	if not visible:
		return
	var line := _line_step()
	# Mouse wheel via action map.
	if event.is_action_pressed("scroll_up", true):
		_scroll_by(-line)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("scroll_down", true):
		_scroll_by(line)
		get_viewport().set_input_as_handled()
	# Keyboard: match by physical keycode directly so this works even if the
	# scroll_up/scroll_down action bindings are out of date.
	elif event is InputEventKey and event.pressed:
		match event.physical_keycode:
			KEY_UP:
				_scroll_by(-line)
				get_viewport().set_input_as_handled()
			KEY_DOWN:
				_scroll_by(line)
				get_viewport().set_input_as_handled()
			KEY_PAGEUP:
				_scroll_by(-line * _page_lines())
				get_viewport().set_input_as_handled()
			KEY_PAGEDOWN:
				_scroll_by(line * _page_lines())
				get_viewport().set_input_as_handled()

func _page_lines() -> int:
	# Approximate a screenful: content viewport height / line height, minus one
	# so the player keeps a line of context when paging.
	var line := _line_step()
	if line <= 0:
		return 10
	return maxi(1, int(content_label.size.y / float(line)) - 1)

func _scroll_by(delta: int) -> void:
	var bar := content_label.get_v_scroll_bar()
	if bar:
		bar.value = clampf(bar.value + delta, 0.0, bar.max_value)
	AudioManager.sound_page_scroll()
