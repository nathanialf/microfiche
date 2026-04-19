extends Interactable

# Interaction zone covering the screen of the left-desk query terminal.
# E → enter view mode; the terminal forwards keyboard input to its SubViewport
# so the player can type a keyword. ESC exits the view.

var _in_view: bool = false

@onready var _terminal: Node = _find_terminal()

func _find_terminal() -> Node:
	var n: Node = get_parent()
	while n != null:
		if n.has_method("notify_view_entered") and n.has_method("notify_view_exited"):
			return n
		n = n.get_parent()
	return null

func get_interact_prompt(_player: Node) -> String:
	return "[E] Use terminal"

func interact(player: Node) -> bool:
	if player.has_method("enter_view_mode"):
		player.enter_view_mode(self)
	_in_view = true
	if _terminal and _terminal.has_method("notify_view_entered"):
		_terminal.notify_view_entered()
	if player.has_signal("view_mode_exited") \
			and not player.view_mode_exited.is_connected(_on_view_mode_exited):
		player.view_mode_exited.connect(_on_view_mode_exited, CONNECT_ONE_SHOT)
	# Consume the E keypress that triggered this interact so it doesn't propagate
	# into the terminal's SubViewport and get typed into the LineEdit as "e".
	var vp := get_viewport()
	if vp:
		vp.set_input_as_handled()
	return true

# Read by player.gd to suppress the global KEY_E-exits-view behaviour while
# the terminal's LineEdit owns keyboard input.
func consumes_view_input() -> bool:
	return _in_view

func _on_view_mode_exited() -> void:
	_in_view = false
	if _terminal and _terminal.has_method("notify_view_exited"):
		_terminal.notify_view_exited()
