extends Control

# Boot screen — plays once when the terminal powers on
# Simulates a cold boot of a vintage system

@onready var boot_label: RichTextLabel = $BootLabel

const BOOT_LINES := [
	"MICROFICHE SYSTEMS v4.1",
	"SECTOR 9 CLASSIFIED ARCHIVE TERMINAL",
	"",
	"RAM CHECK.................. 512K OK",
	"STORAGE ARRAY.............. MOUNTED",
	"CARTRIDGE READER........... READY",
	"ENCRYPTION MODULE.......... ACTIVE",
	"",
	"THRESHOLD ACCORDS — ARTICLE 1",
	"All sessions are logged.",
	"All access attempts are logged.",
	"Unauthorized disclosure is a breach.",
	"",
	"READY.",
	"",
	"Insert cartridge to begin.",
]

var _line_index: int = 0

func play_boot_sequence() -> void:
	boot_label.clear()
	boot_label.push_color(Color(0.98, 0.72, 0.12))
	_line_index = 0
	_print_next_line()

func _print_next_line() -> void:
	if _line_index >= BOOT_LINES.size():
		return

	var line: String = BOOT_LINES[_line_index]
	_line_index += 1

	boot_label.append_text(line + "\n")

	var delay := 0.08
	if line.is_empty():
		delay = 0.04
	elif line.begins_with("READY"):
		delay = 0.3
	elif line.contains("..."):
		delay = 0.12

	await get_tree().create_timer(delay).timeout
	_print_next_line()
