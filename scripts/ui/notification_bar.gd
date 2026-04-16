extends Control

# Persistent notification bar at top of screen
# Shows keyword discoveries and new cartridge alerts
# Queue-based so they don't overlap

@onready var label: RichTextLabel = $NotifPanel/Label

var _queue: Array[Dictionary] = []
var _showing: bool = false

func show_notification(text: String, color: Color = Color.WHITE, duration: float = 3.5) -> void:
	_queue.append({"text": text, "color": color, "duration": duration})
	if not _showing:
		_show_next()

func _show_next() -> void:
	if _queue.is_empty():
		_showing = false
		return

	_showing = true
	var notif: Dictionary = _queue.pop_front()

	label.clear()
	label.push_color(notif["color"])
	label.append_text("◆ " + notif["text"])
	label.pop()

	modulate.a = 0.0
	visible = true

	var tween := create_tween()
	tween.tween_property(self, "modulate:a", 1.0, 0.15)
	tween.tween_interval(notif["duration"])
	tween.tween_property(self, "modulate:a", 0.0, 0.3)
	tween.tween_callback(func():
		visible = false
		_show_next()
	)
