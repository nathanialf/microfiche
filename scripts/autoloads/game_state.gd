extends Node

# Central game state — in-memory only. Persistence was removed during dev so
# every launch starts fresh. Re-introduce save/load when gameplay stabilises.

signal keyword_discovered(keyword: String, unlocked_cartridge: String)
signal cartridge_unlocked(cartridge_id: String)
signal notes_updated(content: String)
signal document_read(document_id: String)
signal cartridge_touched(cartridge_id: String)

var discovered_keywords: Dictionary = {}
var unlocked_cartridges: Array = []
var available_cartridges: Array = []
var dispensed_cartridges: Array = []
var notes_content: String = ""
var current_cycle: int = 1
var read_documents: Array = []
var touched_cartridges: Array = []
var classified_insert_count: int = 0

func _ready() -> void:
	_init_new_game()

func _init_new_game() -> void:
	var keyword_data := CartridgeDatabase.get_keyword_data()
	available_cartridges = keyword_data.get("starting_cartridges", []).duplicate()
	# Starting carts are pre-placed in the tower — treat them as already dispensed
	# so the terminal reports "ALREADY RELEASED" if their keywords are queried.
	dispensed_cartridges = available_cartridges.duplicate()
	unlocked_cartridges = []
	discovered_keywords = {}
	notes_content = ""
	current_cycle = 1
	read_documents = []
	touched_cartridges = []
	classified_insert_count = 0

func increment_classified_inserts() -> int:
	classified_insert_count += 1
	return classified_insert_count

func discover_keyword(keyword: String) -> void:
	if keyword in discovered_keywords:
		return
	discovered_keywords[keyword] = current_cycle
	emit_signal("keyword_discovered", keyword, "")

func get_dispense_target(keyword: String) -> String:
	var keyword_map: Dictionary = CartridgeDatabase.get_keyword_data().get("keyword_to_cartridge", {})
	var query := keyword.strip_edges().to_lower()
	for k in keyword_map.keys():
		if (k as String).to_lower() == query:
			return keyword_map[k]
	return ""

# Returns "ok", "invalid", or "already_dispensed".
func try_dispense_by_keyword(keyword: String) -> String:
	var cid := get_dispense_target(keyword)
	if cid.is_empty():
		return "invalid"
	if cid in dispensed_cartridges:
		return "already_dispensed"
	dispensed_cartridges.append(cid)
	if cid not in available_cartridges:
		available_cartridges.append(cid)
	if cid not in unlocked_cartridges:
		unlocked_cartridges.append(cid)
	emit_signal("cartridge_unlocked", cid)
	return "ok"

func is_keyword_seen(keyword: String) -> bool:
	# A keyword is "seen" once the player has discovered ANY alias that points to
	# the same cart. Discovery happens via the doc scanner in microfiche_ui after
	# the read-reward delay, so this naturally requires the player to have read
	# (not just opened) a document that surfaced the cart's name.
	var target_cid := get_dispense_target(keyword)
	if target_cid.is_empty():
		return false
	for k in discovered_keywords.keys():
		if get_dispense_target(k) == target_cid:
			return true
	return false

func mark_document_read(document_id: String) -> void:
	if document_id.is_empty() or document_id in read_documents:
		return
	read_documents.append(document_id)
	emit_signal("document_read", document_id)

func mark_cartridge_touched(cartridge_id: String) -> void:
	if cartridge_id.is_empty() or cartridge_id in touched_cartridges:
		return
	touched_cartridges.append(cartridge_id)
	emit_signal("cartridge_touched", cartridge_id)

func update_notes(content: String) -> void:
	notes_content = content
	emit_signal("notes_updated", content)

func get_notes() -> String:
	return notes_content

func has_cartridge(cartridge_id: String) -> bool:
	return cartridge_id in available_cartridges
