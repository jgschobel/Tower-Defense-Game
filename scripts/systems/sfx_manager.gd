extends Node

## Procedural sound effects manager. Generates short beeps/pops at runtime.

var _sample_rate: float = 22050.0


func play_shoot() -> void:
	_play_tone(880.0, 0.06, 0.3)


func play_hit() -> void:
	_play_tone(440.0, 0.04, 0.2)


func play_death() -> void:
	_play_tone(220.0, 0.12, 0.4, true)


func play_wave_start() -> void:
	# Rising tone
	_play_sweep(440.0, 880.0, 0.2, 0.5)


func play_upgrade() -> void:
	# Ascending chime
	_play_sweep(523.0, 1047.0, 0.3, 0.4)


func play_click() -> void:
	_play_tone(660.0, 0.03, 0.2)


func play_sell() -> void:
	_play_sweep(660.0, 330.0, 0.15, 0.3)


func _play_tone(freq: float, duration: float, volume: float, noise: bool = false) -> void:
	var samples := int(_sample_rate * duration)
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_8_BITS
	audio.mix_rate = int(_sample_rate)
	audio.stereo = false

	var data := PackedByteArray()
	for i in samples:
		var t := float(i) / _sample_rate
		var env := 1.0 - (t / duration)  # linear decay
		var sample: float
		if noise:
			sample = (randf() * 2.0 - 1.0) * env * volume
		else:
			var phase := fmod(t * freq, 1.0)
			sample = (1.0 if phase < 0.5 else -1.0) * env * volume
		data.append(int((sample * 0.5 + 0.5) * 255))

	audio.data = data

	var player := AudioStreamPlayer.new()
	player.stream = audio
	player.volume_db = -6.0
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


func _play_sweep(freq_start: float, freq_end: float, duration: float, volume: float) -> void:
	var samples := int(_sample_rate * duration)
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_8_BITS
	audio.mix_rate = int(_sample_rate)
	audio.stereo = false

	var data := PackedByteArray()
	for i in samples:
		var t := float(i) / _sample_rate
		var progress_pct := t / duration
		var freq := freq_start + (freq_end - freq_start) * progress_pct
		var env := 1.0 - progress_pct
		var phase := fmod(t * freq, 1.0)
		var sample := (1.0 if phase < 0.5 else -1.0) * env * volume
		data.append(int((sample * 0.5 + 0.5) * 255))

	audio.data = data

	var player := AudioStreamPlayer.new()
	player.stream = audio
	player.volume_db = -6.0
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
