extends Node

## Procedural sound effects manager. Generates short beeps/pops at runtime.

var _sample_rate: float = 22050.0


func play_shoot() -> void:
	_play_tone(880.0, 0.06, 0.3)


func play_hit() -> void:
	_play_tone(440.0, 0.04, 0.2)


func play_death(enemy_health: float = 100.0) -> void:
	# Soft downward sweep with pitch modulated by enemy size.
	# Small enemies (low health) = higher pitch "pop", big enemies =
	# deep "thump". Adds rhythm as waves progress from tofu to boss.
	var size_factor: float = clampf(enemy_health / 100.0, 0.4, 3.0)
	var base_freq: float = 220.0 / sqrt(size_factor)  # bigger → lower
	var end_freq: float = base_freq * 0.4
	_play_sweep(base_freq, end_freq, 0.08, 0.15)


func play_wave_start() -> void:
	# Rising tone
	_play_sweep(440.0, 880.0, 0.2, 0.5)


func play_upgrade() -> void:
	# Ascending chime
	_play_sweep(523.0, 1047.0, 0.3, 0.4)


func play_click() -> void:
	# Minecraft-style wooden "tick" — short noise burst with a quick
	# decay, softer than any pitched tone. User complained the previous
	# sweep was annoying; this is genuinely neutral.
	_play_tick()


func _play_tick() -> void:
	# Softer "tock" — warm damped sine (~240 Hz body) mixed with a tiny
	# low-passed noise whisper, ~55ms. Previous version was a 25ms
	# noise burst with an instant attack which felt piercing; the ramp
	# in the first 4ms plus the low-frequency body removes the bite.
	var duration: float = 0.055
	var samples := int(_sample_rate * duration)
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_8_BITS
	audio.mix_rate = int(_sample_rate)
	audio.stereo = false
	var data := PackedByteArray()
	var freq: float = 240.0
	var noise_avg: float = 0.0
	var attack_samples: float = float(_sample_rate) * 0.004  # 4ms ramp in
	for i in samples:
		var t := float(i) / _sample_rate
		# Attack ramp then exponential decay — no sharp transient
		var attack: float = clamp(float(i) / attack_samples, 0.0, 1.0)
		var tail: float = pow(1.0 - (t / duration), 3.0)
		var env: float = attack * tail
		# Warm body — damped sine at 240 Hz
		var body: float = sin(t * freq * TAU) * 0.55
		# Noise whisper, lightly low-pass filtered via rolling average,
		# ducked well below the body so it reads as "texture" not "shh"
		var raw_noise: float = randf() * 2.0 - 1.0
		noise_avg = noise_avg * 0.7 + raw_noise * 0.3
		var noise: float = noise_avg * 0.18
		var sample: float = (body + noise) * env * 0.08
		data.append(int(clamp(sample * 0.5 + 0.5, 0.0, 1.0) * 255))
	audio.data = data
	var player := AudioStreamPlayer.new()
	player.stream = audio
	player.volume_db = _db_with_user_volume(-6.0)
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


func play_sell() -> void:
	_play_sweep(660.0, 330.0, 0.15, 0.3)


func play_place() -> void:
	# Placement confirmation — short "thunk" that rises then settles.
	# Gives tactile feedback on successful drop.
	_play_sweep(220.0, 440.0, 0.12, 0.35)


func play_boss_roar() -> void:
	# Deep falling rumble for boss reveal / death. Pitch descends from
	# sub-bass into the floor, amplitude ~0.5 for punch.
	_play_sweep(95.0, 42.0, 0.8, 0.55)


func play_life_lost() -> void:
	# Heartbeat thump + dip — low double-tap to mark a life drain.
	# Pairs with the red screen flash. Short so it doesn't overwhelm.
	_play_sweep(180.0, 70.0, 0.18, 0.45)


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
	player.volume_db = _db_with_user_volume(-6.0)
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


func _db_with_user_volume(base_db: float) -> float:
	# Scale base_db by the user's SFX volume setting (0.0 = muted, 1.0 = full).
	var vol: float = 1.0
	if Engine.has_singleton("GameManager") or GameManager:
		vol = GameManager.sfx_volume
	if vol <= 0.0001:
		return -80.0
	return base_db + linear_to_db(vol)


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
	player.volume_db = _db_with_user_volume(-6.0)
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
