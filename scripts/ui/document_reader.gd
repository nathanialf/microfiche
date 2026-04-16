extends Control

signal back_pressed

const AMBER        := Color(0.96, 0.72, 0.12)
const AMBER_DIM    := Color(0.58, 0.43, 0.08)
const AMBER_BRIGHT := Color(1.0,  0.88, 0.30)
const KEYWORD_NEW  := Color(0.70, 0.95, 0.40)   # green-gold — unseen keyword
const KEYWORD_SEEN := Color(0.50, 0.78, 0.30)   # muted — already discovered
const DIVIDER_COL  := Color(0.30, 0.22, 0.05)

@onready var header_label: RichTextLabel    = $Layout/Header
@onready var class_label: Label             = $Layout/ClassificationBar/ClassLabel
@onready var page_label: Label              = $Layout/ClassificationBar/PageNum
@onready var content_scroll: ScrollContainer= $Layout/MainArea/ContentScroll
@onready var content_label: RichTextLabel   = $Layout/MainArea/ContentScroll/Content
@onready var section_index: VBoxContainer   = $Layout/MainArea/SidePanel/SectionIndex
@onready var tags_bar: HBoxContainer        = $Layout/TagsBar
@onready var back_button: Button            = $Layout/FooterBar/BackBtn
@onready var scroll_hint: Label             = $Layout/FooterBar/ScrollHint

var _current_doc: Dictionary = {}
var _cartridge_id: String = ""

func _ready() -> void:
	back_button.pressed.connect(func(): back_pressed.emit())

func display_document(cartridge_id: String, doc: Dictionary) -> void:
	_cartridge_id = cartridge_id
	_current_doc = doc

	_render_header(doc)
	_render_classification(doc)
	_render_content(doc)
	_rebuild_section_index(doc)
	_render_tags(doc)

	content_scroll.scroll_vertical = 0
	scroll_hint.text = "↑↓ or wheel to scroll"

func _render_header(doc: Dictionary) -> void:
	header_label.clear()
	if doc.get("placeholder", false):
		header_label.push_color(Color(1.0, 0.38, 0.08))
		header_label.append_text("▓  PLACEHOLDER — CONTENT NOT FINAL  ▓\n")
		header_label.pop()
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

		# Body — split on keyword boundaries and colorize
		_append_body_with_keywords(sec.get("body", ""))

		content_label.append_text("\n")
		content_label.pop()

		if i < sections.size() - 1:
			content_label.push_color(DIVIDER_COL)
			content_label.append_text("\n────────────────────────────────\n\n")
			content_label.pop()

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

func _scroll_to_section(idx: int, total: int) -> void:
	if total == 0:
		return
	var bar := content_scroll.get_v_scroll_bar()
	content_scroll.scroll_vertical = int(bar.max_value * float(idx) / float(total))

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event.is_action_pressed("scroll_up"):
		content_scroll.scroll_vertical = maxi(0, content_scroll.scroll_vertical - 90)
		AudioManager.sound_page_scroll()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("scroll_down"):
		content_scroll.scroll_vertical += 90
		AudioManager.sound_page_scroll()
		get_viewport().set_input_as_handled()
