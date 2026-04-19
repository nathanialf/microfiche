extends Interactable

# Interaction zone covering the cartridge slot opening on the microfiche body.
# Delegates state to the parent MicroficheReader and transport to the Player.

@onready var reader: Node = get_parent().get_parent()  # Zone → TerminalBody → MicroficheReader

func get_interact_prompt(player: Node) -> String:
	if reader == null:
		return ""
	var loaded: String = reader.get_loaded_cartridge()
	if loaded.is_empty():
		if player and player.has_held_cartridge():
			var held: Cartridge = player.get_held_cartridge()
			return "[E] Insert — " + CartridgeDatabase.get_cartridge_full_name(held.cartridge_id)
		return ""
	return "[E] Eject — " + CartridgeDatabase.get_cartridge_full_name(loaded)

func interact(player: Node) -> bool:
	if reader == null:
		return false
	var loaded: String = reader.get_loaded_cartridge()
	if loaded.is_empty():
		if not player.has_held_cartridge():
			return false
		# Delegate the full insert flow (transport + insert) to the player.
		player.insert_held_into_reader(reader, reader.cartridge_slot)
	else:
		reader.eject_cartridge()
	return false  # inline action — no camera lock
