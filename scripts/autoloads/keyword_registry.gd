extends Node

# Handles keyword highlighting and discovery UI feedback
# When a keyword is found in displayed text, flashes it and logs the discovery

# Keywords that have been seen on screen this session (to avoid re-notifying)
var _session_seen: Dictionary = {}

func process_displayed_text(full_text: String, _document_id: String) -> void:
	var keywords := CartridgeDatabase.scan_for_keywords(full_text)
	for keyword in keywords:
		if keyword not in GameState.discovered_keywords:
			GameState.discover_keyword(keyword)
			if keyword not in _session_seen:
				_session_seen[keyword] = true
				# Notification handled by GameState signal → UI

func reset_session() -> void:
	_session_seen.clear()
