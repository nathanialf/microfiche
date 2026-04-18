class_name Interactable
extends Node3D

# Typed base for anything the player can point at and press E on.
#
# Contract:
#   get_interact_prompt(player) -> String
#       Return the hint text (e.g. "[E] Insert — ALPHA"). Empty string means
#       "no valid action here" — the player will hide the prompt and NOT
#       fire interact() even if E is pressed.
#
#   interact(player) -> bool
#       Perform the action. Return true if the interaction takes the player
#       out of FREE_LOOK (view mode, dialog, UI takeover); false for inline
#       actions that don't lock the camera.

func get_interact_prompt(_player: Node) -> String:
	return ""

func interact(_player: Node) -> bool:
	return false
