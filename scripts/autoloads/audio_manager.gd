extends Node

# Handles ambient audio, UI sounds, and mechanical hand sounds
# All sounds are generated procedurally via AudioStreamGenerator
# since we have no assets yet — stubs for future sound design

const BUS_MASTER := "Master"
const BUS_AMBIENT := "Ambient"
const BUS_SFX := "SFX"

var _ambient_player: AudioStreamPlayer
var _sfx_players: Array[AudioStreamPlayer] = []
var _sfx_pool_size := 8

func _ready() -> void:
	_setup_audio_buses()
	_setup_ambient_player()
	_setup_sfx_pool()

func _setup_audio_buses() -> void:
	# Ensure buses exist (they should in a default Godot project)
	pass

func _setup_ambient_player() -> void:
	_ambient_player = AudioStreamPlayer.new()
	_ambient_player.bus = "Master"
	add_child(_ambient_player)

func _setup_sfx_pool() -> void:
	for i in _sfx_pool_size:
		var p := AudioStreamPlayer.new()
		p.bus = "Master"
		add_child(p)
		_sfx_players.append(p)

func play_sfx(stream: AudioStream, volume_db: float = 0.0) -> void:
	for player in _sfx_players:
		if not player.playing:
			player.stream = stream
			player.volume_db = volume_db
			player.play()
			return

func play_ambient(stream: AudioStream, volume_db: float = -6.0) -> void:
	_ambient_player.stream = stream
	_ambient_player.volume_db = volume_db
	_ambient_player.play()

func stop_ambient() -> void:
	_ambient_player.stop()

# --- Named sound stubs (wire up actual AudioStream assets later) ---

func sound_cartridge_insert() -> void:
	# A satisfying mechanical clunk
	pass

func sound_cartridge_eject() -> void:
	# A spring-loaded click-thunk
	pass

func sound_terminal_boot() -> void:
	# CRT flicker hiss + boot sequence beep
	pass

func sound_access_denied() -> void:
	# Sharp buzzer
	pass

func sound_keyword_discovered() -> void:
	# Soft chime — reward without being intrusive
	pass

func sound_page_scroll() -> void:
	# Quiet mechanical click
	pass

func sound_hands_reach() -> void:
	# Subtle servo whir
	pass

func sound_hands_grasp() -> void:
	# Metallic click
	pass

func sound_notepad_open() -> void:
	# Paper-mechanical hybrid sound
	pass

func sound_typewriter_key() -> void:
	# Single key strike
	pass

func sound_query_accepted() -> void:
	# Satisfying key-thunk + confirmation chirp
	pass

func sound_query_invalid() -> void:
	# Short error buzz
	pass

func sound_query_rejected() -> void:
	# Muted "nope" tone — record already released
	pass

func sound_hatch_open() -> void:
	# Mechanical servo whir + latch click
	pass

func sound_hatch_close() -> void:
	# Reverse servo + soft clunk
	pass

func sound_cart_pop() -> void:
	# Cassette-eject spring
	pass
