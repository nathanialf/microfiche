extends Node

func _ready() -> void:
	# The room scene handles everything
	# This script handles top-level game events
	pass

func _input(event: InputEvent) -> void:
	# Global escape to toggle mouse capture
	if event.is_action_pressed("ui_cancel"):
		if Input.get_mouse_mode() == Input.MOUSE_MODE_CAPTURED:
			# Let UI handle it first — if no UI consumed it, release mouse
			pass
