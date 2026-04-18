extends Node

# Central game state — persistent across scenes

signal keyword_discovered(keyword: String, unlocked_cartridge: String)
signal cartridge_unlocked(cartridge_id: String)
signal notes_updated(content: String)
signal document_read(document_id: String)
signal cartridge_touched(cartridge_id: String)

const SAVE_PATH := "user://microfiche_save.json"

var discovered_keywords: Dictionary = {}
var unlocked_cartridges: Array = []
var available_cartridges: Array = []
var notes_content: String = ""
var current_cycle: int = 1
var read_documents: Array = []
var touched_cartridges: Array = []
var classified_insert_count: int = 0

func _ready() -> void:
	load_game()
	if available_cartridges.is_empty() or _save_has_unknown_cartridges():
		_init_new_game()

func _save_has_unknown_cartridges() -> bool:
	# Guard against ID schema changes (e.g. cartridge split): if the save holds
	# IDs the current database doesn't know about, the game can't use them.
	var known := CartridgeDatabase.get_all_cartridge_ids()
	for cid in available_cartridges:
		if cid not in known:
			return true
	return false

func _init_new_game() -> void:
	var keyword_data := CartridgeDatabase.get_keyword_data()
	available_cartridges = keyword_data.get("starting_cartridges", []).duplicate()
	unlocked_cartridges = []
	discovered_keywords = {}
	notes_content = ""
	current_cycle = 1
	read_documents = []
	touched_cartridges = []
	classified_insert_count = 0
	save_game()

func increment_classified_inserts() -> int:
	classified_insert_count += 1
	save_game()
	return classified_insert_count

func discover_keyword(keyword: String) -> void:
	if keyword in discovered_keywords:
		return
	discovered_keywords[keyword] = current_cycle
	var keyword_map: Dictionary = CartridgeDatabase.get_keyword_data().get("keyword_to_cartridge", {})
	if keyword in keyword_map:
		_unlock_cartridge(keyword_map[keyword])
	emit_signal("keyword_discovered", keyword, "")
	save_game()

func _unlock_cartridge(cartridge_id: String) -> void:
	if cartridge_id in available_cartridges:
		return
	available_cartridges.append(cartridge_id)
	unlocked_cartridges.append(cartridge_id)
	emit_signal("cartridge_unlocked", cartridge_id)

func mark_document_read(document_id: String) -> void:
	if document_id.is_empty() or document_id in read_documents:
		return
	read_documents.append(document_id)
	emit_signal("document_read", document_id)
	save_game()

func mark_cartridge_touched(cartridge_id: String) -> void:
	if cartridge_id.is_empty() or cartridge_id in touched_cartridges:
		return
	touched_cartridges.append(cartridge_id)
	emit_signal("cartridge_touched", cartridge_id)
	save_game()

func update_notes(content: String) -> void:
	notes_content = content
	emit_signal("notes_updated", content)
	save_game()

func get_notes() -> String:
	return notes_content

func has_cartridge(cartridge_id: String) -> bool:
	return cartridge_id in available_cartridges

func save_game() -> void:
	var data := {
		"discovered_keywords": discovered_keywords,
		"available_cartridges": available_cartridges,
		"unlocked_cartridges": unlocked_cartridges,
		"notes_content": notes_content,
		"current_cycle": current_cycle,
		"read_documents": read_documents,
		"touched_cartridges": touched_cartridges,
		"classified_insert_count": classified_insert_count,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var text := file.get_as_text()
	file.close()
	var result = JSON.parse_string(text)
	if result == null or not result is Dictionary:
		return
	var data: Dictionary = result
	discovered_keywords = data.get("discovered_keywords", {})
	available_cartridges = data.get("available_cartridges", [])
	unlocked_cartridges = data.get("unlocked_cartridges", [])
	notes_content = data.get("notes_content", "")
	current_cycle = data.get("current_cycle", 1)
	read_documents = data.get("read_documents", [])
	touched_cartridges = data.get("touched_cartridges", [])
	classified_insert_count = data.get("classified_insert_count", 0)

func reset_game() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(SAVE_PATH)
	_init_new_game()
