extends Node

# Loads and caches all cartridge JSON data from disk

const CARTRIDGE_DIR := "res://data/cartridges/"
const KEYWORD_FILE := "res://data/keywords.json"

var _cartridges: Dictionary = {}   # id -> cartridge dict
var _keyword_data: Dictionary = {}

func _ready() -> void:
	_load_all_cartridges()
	_load_keyword_data()

func _load_all_cartridges() -> void:
	var cartridge_ids: Array[String] = [
		"threshold", "omicron", "mox", "sable",
		"vex", "caul", "choir", "litany",
		"expanse", "kaya", "watcher", "blade",
		"classified",
	]
	for cid: String in cartridge_ids:
		var path: String = CARTRIDGE_DIR + cid + ".json"
		var file := FileAccess.open(path, FileAccess.READ)
		if not file:
			push_warning("CartridgeDatabase: could not open " + path)
			continue
		var text := file.get_as_text()
		file.close()
		var parsed = JSON.parse_string(text)
		if parsed == null:
			push_warning("CartridgeDatabase: failed to parse " + path)
			continue
		_cartridges[cid] = parsed

func _load_keyword_data() -> void:
	var file := FileAccess.open(KEYWORD_FILE, FileAccess.READ)
	if not file:
		push_warning("CartridgeDatabase: could not open keywords.json")
		return
	var text := file.get_as_text()
	file.close()
	var parsed = JSON.parse_string(text)
	if parsed != null:
		_keyword_data = parsed

func get_cartridge(cartridge_id: String) -> Dictionary:
	return _cartridges.get(cartridge_id, {})

func get_all_cartridge_ids() -> Array:
	return _cartridges.keys()

func get_keyword_data() -> Dictionary:
	return _keyword_data

func get_cartridge_label(cartridge_id: String) -> String:
	var c := get_cartridge(cartridge_id)
	return c.get("label", cartridge_id.to_upper())

func get_handwritten_label(cartridge_id: String) -> String:
	var c := get_cartridge(cartridge_id)
	return c.get("handwritten_label", "")

func get_cartridge_color(cartridge_id: String) -> Color:
	var c := get_cartridge(cartridge_id)
	var hex: String = c.get("color", "#888888")
	return Color(hex)

func is_access_denied(cartridge_id: String) -> bool:
	var c := get_cartridge(cartridge_id)
	return c.get("access_denied", false)

func is_grimoire_void(cartridge_id: String) -> bool:
	var c := get_cartridge(cartridge_id)
	return c.get("grimoire_void", false)

func get_void_fragments(cartridge_id: String) -> Array:
	var c := get_cartridge(cartridge_id)
	return c.get("void_fragments", [])

func get_escalating_fragments(cartridge_id: String, insert_count: int) -> Array:
	var c := get_cartridge(cartridge_id)
	var stages: Array = c.get("escalating_fragments", [])
	if stages.is_empty():
		return get_void_fragments(cartridge_id)
	var idx := clampi(insert_count - 1, 0, stages.size() - 1)
	return stages[idx]

func get_documents(cartridge_id: String) -> Array:
	var c := get_cartridge(cartridge_id)
	return c.get("documents", [])

func scan_for_keywords(text: String) -> Array[String]:
	var keyword_map: Dictionary = _keyword_data.get("keyword_to_cartridge", {})
	var found: Array[String] = []
	var text_lower := text.to_lower()
	for keyword: String in keyword_map.keys():
		if text_lower.contains(keyword.to_lower()):
			found.append(keyword)
	return found
