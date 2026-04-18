extends Node

## Background music manager. Plays procedurally generated chiptune music
## continuously from game start. Two track banks:
##   - "menu"  — mellow, slow (main menu + level select + story screens)
##   - "game"  — energetic, faster (inside gameplay levels)
## Switches automatically based on GameManager.current_state transitions.

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _sample_rate: float = 22050.0
var _time: float = 0.0
var _beat_duration: float = 0.21
var _current_note_index: int = 0
var _note_time: float = 0.0
var _is_playing: bool = false
var _volume: float = 0.22  # softer default (was 0.3 — user said it was cheap)
var _current_track: String = ""

# --- MENU TRACK: slow, mellow, welcoming (C major pentatonic, 100 BPM) ---
var _menu_melody: Array = [
	523.25, 0,      659.25, 0,      783.99, 0,      659.25, 587.33,
	523.25, 587.33, 659.25, 783.99, 659.25, 587.33, 523.25, 0,
	659.25, 0,      783.99, 0,      880.00, 0,      783.99, 659.25,
	587.33, 523.25, 587.33, 659.25, 523.25, 0,      0,      0,
]
var _menu_bass: Array = [
	130.81, 130.81, 130.81, 130.81, 164.81, 164.81, 164.81, 164.81,
	130.81, 130.81, 130.81, 130.81, 196.00, 196.00, 196.00, 196.00,
	164.81, 164.81, 164.81, 164.81, 220.00, 220.00, 220.00, 220.00,
	146.83, 146.83, 146.83, 146.83, 130.81, 130.81, 130.81, 130.81,
]

# --- GAME TRACK: upbeat supermarket-chase (C major pentatonic, 130 BPM) ---
var _game_melody: Array = [
	523.25, 587.33, 659.25, 783.99, 880.0, 783.99, 659.25, 587.33,
	523.25, 659.25, 783.99, 880.0, 1046.5, 880.0, 783.99, 659.25,
	523.25, 0,      659.25, 0,      783.99, 783.99, 659.25, 523.25,
	880.0,  783.99, 659.25, 587.33, 523.25, 587.33, 659.25, 523.25,
]
var _game_bass: Array = [
	130.81, 130.81, 146.83, 146.83, 164.81, 164.81, 146.83, 146.83,
	130.81, 130.81, 164.81, 164.81, 196.0,  196.0,  164.81, 164.81,
	130.81, 0,      164.81, 0,      196.0,  196.0,  164.81, 130.81,
	220.0,  196.0,  164.81, 146.83, 130.81, 146.83, 164.81, 130.81,
]


func _ready() -> void:
	var stream := AudioStreamGenerator.new()
	stream.mix_rate = _sample_rate
	stream.buffer_length = 0.1

	_player = AudioStreamPlayer.new()
	_player.stream = stream
	_player.bus = "Master"
	add_child(_player)
	_apply_user_volume()

	# Auto-start the menu track. Persists across scene changes because
	# MusicManager is an autoload singleton.
	set_track("menu")
	play_music()

	if GameManager:
		GameManager.game_state_changed.connect(_on_game_state_changed)


func _apply_user_volume() -> void:
	if not _player:
		return
	var user_vol: float = 1.0
	if GameManager:
		user_vol = GameManager.music_volume
	var effective := _volume * user_vol
	if effective <= 0.0001:
		_player.volume_db = -80.0
	else:
		_player.volume_db = linear_to_db(effective)


func refresh_volume() -> void:
	_apply_user_volume()


func _on_game_state_changed(state: int) -> void:
	_apply_user_volume()
	if GameManager == null:
		return
	if state == GameManager.GameState.PLAYING:
		set_track("game")
	elif state == GameManager.GameState.MENU:
		set_track("menu")


func set_track(name: String) -> void:
	if _current_track == name:
		return
	_current_track = name
	if name == "game":
		_beat_duration = 60.0 / 130.0 / 2.0  # 130 BPM eighth notes
	else:
		_beat_duration = 60.0 / 100.0 / 2.0  # 100 BPM eighth notes — mellower
	_current_note_index = 0
	_note_time = 0.0


func play_music() -> void:
	if _is_playing:
		return
	_is_playing = true
	_player.play()
	_playback = _player.get_stream_playback()
	_time = 0.0


func stop_music() -> void:
	_is_playing = false
	_player.stop()


func pause_music() -> void:
	_player.stream_paused = true


func resume_music() -> void:
	_player.stream_paused = false


func set_volume(vol: float) -> void:
	_volume = vol
	_apply_user_volume()


func _process(_delta: float) -> void:
	if not _is_playing or _playback == null:
		return
	_fill_buffer()


func _active_melody() -> Array:
	return _game_melody if _current_track == "game" else _menu_melody


func _active_bass() -> Array:
	return _game_bass if _current_track == "game" else _menu_bass


func _fill_buffer() -> void:
	var frames_available := _playback.get_frames_available()
	if frames_available <= 0:
		return
	var melody: Array = _active_melody()
	var bass: Array = _active_bass()
	for i in frames_available:
		var dt := 1.0 / _sample_rate
		_time += dt
		_note_time += dt

		if _note_time >= _beat_duration:
			_note_time -= _beat_duration
			_current_note_index = (_current_note_index + 1) % melody.size()

		var idx := _current_note_index
		var melody_freq: float = melody[idx]
		var bass_freq: float = bass[idx % bass.size()]

		var sample := 0.0

		# Melody: triangle wave (softer than square — reduces "cheap"
		# chiptune harshness the user called out)
		if melody_freq > 0:
			var phase := fmod(_time * melody_freq, 1.0)
			var tri := absf(phase * 4.0 - 2.0) - 1.0
			# Gentle attack/release envelope within each note
			var beat_pos := _note_time / _beat_duration
			var env := 1.0
			if beat_pos < 0.1:
				env = beat_pos / 0.1  # attack
			elif beat_pos > 0.8:
				env = (1.0 - beat_pos) / 0.2  # release
			sample += tri * 0.22 * env

		# Bass: sine-like (triangle scaled) for a warm bottom
		if bass_freq > 0:
			var bass_phase := fmod(_time * bass_freq, 1.0)
			var bass_val := (absf(bass_phase * 4.0 - 2.0) - 1.0) * 0.18
			sample += bass_val

		sample = clampf(sample, -1.0, 1.0)
		_playback.push_frame(Vector2(sample, sample))
