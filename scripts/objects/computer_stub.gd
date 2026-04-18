extends Interactable

# Placeholder for the future "notes & keyword search" computer.
# Sits on the left arc of the desk. Not yet functional — pressing E just
# shows a SYSTEM OFFLINE prompt so the player knows the object exists.

func get_interact_prompt(_player: Node) -> String:
	return "[E] Access  —  SYSTEM OFFLINE"

func interact(_player: Node) -> bool:
	AudioManager.sound_access_denied()
	return false
