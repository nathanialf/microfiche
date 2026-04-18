extends Control

const AMBER        := Color(0.20, 0.95, 0.28)   # phosphor green — main text
const AMBER_DIM    := Color(0.08, 0.52, 0.14)   # dim green
const AMBER_BRIGHT := Color(0.65, 1.00, 0.72)   # bright green highlight
const KEYWORD_NEW  := Color(1.00, 1.00, 0.25)   # yellow — unseen keyword stands out
const KEYWORD_SEEN := Color(0.55, 1.00, 0.60)   # lighter green — already discovered
const DIVIDER_COL  := Color(0.08, 0.38, 0.12)   # dark green divider

@onready var header_label: RichTextLabel    = $Layout/Header
@onready var class_label: Label             = $Layout/ClassificationBar/ClassLabel
@onready var page_label: Label              = $Layout/ClassificationBar/PageNum
@onready var content_label: RichTextLabel   = $Layout/MainArea/Content
@onready var section_index: VBoxContainer   = $Layout/MainArea/SectionIndex
@onready var tags_bar: HBoxContainer        = $Layout/TagsBar
@onready var scroll_hint: Label             = $Layout/FooterBar/ScrollHint
@onready var ticker: PanelContainer         = $Layout/PlaceholderTicker
@onready var ticker_bg: ColorRect           = $Layout/PlaceholderTicker/Bg
@onready var ticker_label: Label            = $Layout/PlaceholderTicker/TickerLabel

const TICKER_SPEED_PX := 55.0  # pixels per second
const TICKER_SEGMENT  := "▓  PLACEHOLDER — CONTENT NOT FINAL  ▓    "
const TICKER_REPEATS  := 24  # enough repeats that the wrap point is always far off-screen

var _current_doc: Dictionary = {}
var _cartridge_id: String = ""
var _ticker_offset: float = 0.0
var _ticker_segment_width: float = 0.0

func _ready() -> void:
	ticker.resized.connect(_layout_ticker_bg)
	ticker_label.resized.connect(_recompute_ticker_segment)

func display_document(cartridge_id: String, doc: Dictionary) -> void:
	_cartridge_id = cartridge_id
	_current_doc = doc

	_render_header(doc)
	_render_classification(doc)
	_render_content(doc)
	_rebuild_section_index(doc)
	_render_tags(doc)
	_render_ticker(doc)

	_reset_scroll()
	scroll_hint.text = "↑↓ or wheel to scroll"
	call_deferred("_debug_log_content_size")

func _debug_log_content_size() -> void:
	print("[doc_reader] content size: ", content_label.size,
		" autowrap=", content_label.autowrap_mode,
		" min_x=", content_label.custom_minimum_size.x)

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
			_append_body_with_keywords(sec.get("body", ""))
			content_label.append_text("\n")

		content_label.pop()

		if i < sections.size() - 1:
			content_label.push_color(DIVIDER_COL)
			content_label.append_text("\n────────────────────────────────\n\n")
			content_label.pop()

func _render_block(block: Dictionary) -> void:
	match block.get("type", "paragraph"):
		"paragraph":
			_append_body_with_keywords(block.get("text", ""))
			content_label.append_text("\n\n")
		"table":
			_render_table_block(block)
		"list":
			_render_list_block(block)
		_:
			_append_body_with_keywords(str(block.get("text", "")))
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
	# Data rows
	for row: Array in rows:
		for col_idx in n:
			content_label.push_cell()
			var cell_text: String = str(row[col_idx]) if col_idx < row.size() else ""
			_append_body_with_keywords(cell_text)
			content_label.pop()
	content_label.pop()
	content_label.append_text("\n")

func _render_list_block(block: Dictionary) -> void:
	var items: Array = block.get("items", [])
	var ordered: bool = block.get("ordered", false)
	for i in items.size():
		var prefix := "%d. " % (i + 1) if ordered else "•  "
		content_label.append_text(prefix)
		_append_body_with_keywords(str(items[i]))
		content_label.append_text("\n")
	content_label.append_text("\n")

func _append_body_with_keywords(text: String) -> void:
	var keyword_map: Dictionary = CartridgeDatabase.get_keyword_data().get("keyword_to_cartridge", {})

	# Build sorted list of (start_idx, end_idx, keyword) for all matches
	var spans: Array = []
	var text_lower := text.to_lower()

	for keyword: String in keyword_map.keys():
		var kw_lower := keyword.to_lower()
		var search_from := 0
		while true:
			var idx := text_lower.find(kw_lower, search_from)
			if idx == -1:
				break
			spans.append([idx, idx + keyword.length(), keyword])
			search_from = idx + 1

	if spans.is_empty():
		content_label.append_text(text)
		return

	# Sort by start position, resolve overlaps (take longest match)
	spans.sort_custom(func(a, b): return a[0] < b[0])
	var merged: Array = []
	for span in spans:
		if not merged.is_empty() and span[0] < merged[-1][1]:
			# Overlap — keep whichever ends later
			if span[1] > merged[-1][1]:
				merged[-1] = span
		else:
			merged.append(span.duplicate())

	# Emit text segments with colorized keywords interleaved
	var cursor := 0
	for span in merged:
		var start: int = span[0]
		var end: int   = span[1]
		var kw: String = span[2]

		if cursor < start:
			content_label.append_text(text.substr(cursor, start - cursor))

		var seen := kw in GameState.discovered_keywords
		content_label.push_color(KEYWORD_SEEN if seen else KEYWORD_NEW)
		content_label.push_bold()
		content_label.append_text(text.substr(start, end - start))
		content_label.pop()
		content_label.pop()

		cursor = end

	if cursor < text.length():
		content_label.append_text(text.substr(cursor))

func _rebuild_section_index(doc: Dictionary) -> void:
	for c in section_index.get_children():
		c.queue_free()
	var sections: Array = doc.get("sections", [])
	for i in sections.size():
		var btn := Button.new()
		btn.text = sections[i].get("heading", "")
		btn.flat = true
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_color_override("font_color", AMBER_DIM)
		btn.add_theme_color_override("font_hover_color", AMBER)
		btn.pressed.connect(_scroll_to_section.bind(i, sections.size()))
		section_index.add_child(btn)

func _render_tags(doc: Dictionary) -> void:
	for c in tags_bar.get_children():
		c.queue_free()
	for tag: String in doc.get("tags", []):
		var lbl := Label.new()
		lbl.text = " " + tag + " "
		lbl.add_theme_color_override("font_color", AMBER_DIM)
		tags_bar.add_child(lbl)

func _render_ticker(doc: Dictionary) -> void:
	ticker.visible = doc.get("placeholder", false)
	if ticker.visible:
		# Fill the label with many back-to-back copies so the seam at wrap time
		# is always far off-screen — the player sees one continuous stream.
		ticker_label.text = TICKER_SEGMENT.repeat(TICKER_REPEATS)
		_ticker_offset = 0.0
		_layout_ticker_bg()
		_recompute_ticker_segment()

func _layout_ticker_bg() -> void:
	ticker_bg.position = Vector2.ZERO
	ticker_bg.size = ticker.size

func _recompute_ticker_segment() -> void:
	# One copy's width. When the offset has scrolled past this we snap back by
	# the same amount — the next segment is already under the cursor, so the
	# snap is invisible and the stream appears continuous.
	_ticker_segment_width = ticker_label.size.x / float(TICKER_REPEATS)

func _process(delta: float) -> void:
	if not ticker.visible or _ticker_segment_width <= 0.0:
		return
	_ticker_offset -= TICKER_SPEED_PX * delta
	if _ticker_offset <= -_ticker_segment_width:
		_ticker_offset += _ticker_segment_width
	ticker_label.position.x = _ticker_offset

func _scroll_to_section(idx: int, total: int) -> void:
	if total == 0:
		return
	var bar := content_label.get_v_scroll_bar()
	if bar:
		bar.value = bar.max_value * float(idx) / float(total)

const SCROLL_STEP := 90

func _input(event: InputEvent) -> void:
	if not visible:
		return
	# Mouse wheel via action map.
	if event.is_action_pressed("scroll_up", true):
		_scroll_by(-SCROLL_STEP)
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("scroll_down", true):
		_scroll_by(SCROLL_STEP)
		get_viewport().set_input_as_handled()
	# Keyboard: match by physical keycode directly so this works even if the
	# scroll_up/scroll_down action bindings are out of date.
	elif event is InputEventKey and event.pressed:
		match event.physical_keycode:
			KEY_UP:
				_scroll_by(-SCROLL_STEP)
				get_viewport().set_input_as_handled()
			KEY_DOWN:
				_scroll_by(SCROLL_STEP)
				get_viewport().set_input_as_handled()
			KEY_PAGEUP:
				_scroll_by(-SCROLL_STEP * 4)
				get_viewport().set_input_as_handled()
			KEY_PAGEDOWN:
				_scroll_by(SCROLL_STEP * 4)
				get_viewport().set_input_as_handled()

func _scroll_by(delta: int) -> void:
	var bar := content_label.get_v_scroll_bar()
	if bar:
		bar.value = clampf(bar.value + delta, 0.0, bar.max_value)
	AudioManager.sound_page_scroll()
