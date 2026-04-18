extends Node

## Background music manager. Plays procedurally generated chiptune music.
## Since we can't ship audio files without a composer, we generate bleepy
## melodies at runtime using AudioStreamGenerator.

var _player: AudioStreamPlayer
var _playback: AudioStreamGeneratorPlayback
var _sample_rate: float = 22050.0
var _time: float = 0.0
var _bpm: float = 140.0
var _beat_duration: float
var _current_note_index: int = 0
var _note_time: float = 0.0
var _is_playing: bool = false
var _volume: float = 0.3

# Funny upbeat melody in C major pentatonic (frequencies in Hz)
# This plays a goofy supermarket-chase-scene vibe
var _melody: Array = [
	523.25, 587.33, 659.25, 783.99, 880.0, 783.99, 659.25, 587.33,  # C5 D5 E5 G5 A5 G5 E5 D5
	523.25, 659.25, 783.99, 880.0, 1046.5, 880.0, 783.99, 659.25,  # going up
	523.25, 0, 659.25, 0, 783.99, 783.99, 659.25, 523.25,          # rhythmic (0 = rest)
	880.0, 783.99, 659.25, 587.33, 523.25, 587.33, 659.25, 523.25, # coming down
]

# Bass line (lower octave)
var _bass: Array = [
	130.81, 130.81, 146.83, 146.83, 164.81, 164.81, 146.83, 146.83,  # C3 C3 D3 D3 E3 E3 D3 D3
	130.81, 130.81, 164.81, 164.81, 196.0, 196.0, 164.81, 164.81,
	130.81, 0, 164.81, 0, 196.0, 196.0, 164.81, 130.81,
	220.0, 196.0, 164.81, 146.83, 130.81, 146.83, 164.81, 130.81,
]


func _ready() -> void:
	_beat_duration = 60.0 / _bpm / 2.0  # eighth notes

	var stream := AudioStreamGenerator.new()
	stream.mix_rate = _sample_rate
	stream.buffer_length = 0.1

	_player = AudioStreamPlayer.new()
	_player.stream = stream
	_player.bus = "Master"
	add_child(_player)
	_apply_user_volume()

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
	## Called by the options menu after the user moves the music slider.
	_apply_user_volume()


func _on_game_state_changed(_state: int) -> void:
	_apply_user_volume()


func play_music() -> void:
	if _is_playing:
		return
	_is_playing = true
	_player.play()
	_playback = _player.get_stream_playback()
	_time = 0.0
	_current_note_index = 0
	_note_time = 0.0


func stop_music() -> void:
	_is_playing = false
	_player.stop()


func pause_music() -> void:
	_player.stream_paused = true


func resume_music() -> void:
	_player.stream_paused = false


func set_volume(vol: float) -> void:
	_volume = vol
	_player.volume_db = linear_to_db(vol)


func _process(_delta: float) -> void:
	if not _is_playing or _playback == null:
		return
	_fill_buffer()


func _fill_buffer() -> void:
	var frames_available := _playback.get_frames_available()
	if frames_available <= 0:
		return

	for i in frames_available:
		var dt := 1.0 / _sample_rate
		_time += dt
		_note_time += dt

		# Advance to next note
		if _note_time >= _beat_duration:
			_note_time -= _beat_duration
			_current_note_index = (_current_note_index + 1) % _melody.size()

		var idx := _current_note_index
		var melody_freq: float = _melody[idx]
		var bass_freq: float = _bass[idx % _bass.size()]

		var sample := 0.0

		# Melody: square wave (chiptune sound)
		if melody_freq > 0:
			var melody_phase := fmod(_time * melody_freq, 1.0)
			var melody_val := 0.3 if melody_phase < 0.5 else -0.3
			# Simple envelope (fade in/out per note)
			var env := 1.0 - (_note_time / _beat_duration) * 0.5
			sample += melody_val * env

		# Bass: triangle wave
		if bass_freq > 0:
			var bass_phase := fmod(_time * bass_freq, 1.0)
			var bass_val := (absf(bass_phase * 4.0 - 2.0) - 1.0) * 0.2
			sample += bass_val

		sample = clampf(sample, -1.0, 1.0)
		_playback.push_frame(Vector2(sample, sample))
