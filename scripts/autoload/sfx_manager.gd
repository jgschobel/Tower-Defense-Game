extends Node

## Sound effects manager. Prefers baked audio files (Kenney packs,
## AI-generated .ogg) declared in resources/audio_config.tres. Falls
## back to procedural synthesis when no baked entry exists or the
## referenced file is missing. This lets us migrate to real audio
## incrementally — ROADMAP #25 / #35.

const AUDIO_CONFIG_PATH := "res://resources/audio_config.tres"

var _sample_rate: float = 44100.0  # bumped from 22050 — eliminates resample artifacts
                                    # ("rips") on 44.1k/48k device output. Doubles WAV
                                    # buffer size but at <0.1s per SFX it's negligible.
var _config: AudioConfig = null
var _stream_cache: Dictionary = {}  # path -> AudioStream
# Per-id cooldown to stop high-frequency SFX from being annoying.
# At 5 towers × 2 shots/s = 10 hit sounds/s without cooldown — felt
# "machine-gun" and unpleasant. 60ms gap keeps rhythm without spam.
var _last_play_ms: Dictionary = {}
const _COOLDOWNS_MS := {
	"hit": 55,
	"enemy_hit": 55,
	"death": 80,
	"shoot": 35,
	"soft_pluck": 40,
}


func _can_play(id: String) -> bool:
	var cd: int = _COOLDOWNS_MS.get(id, 0)
	if cd == 0:
		return true
	var now: int = Time.get_ticks_msec()
	var last: int = _last_play_ms.get(id, 0)
	if now - last < cd:
		return false
	_last_play_ms[id] = now
	return true


func _ready() -> void:
	_load_config()


func _load_config() -> void:
	if ResourceLoader.exists(AUDIO_CONFIG_PATH):
		var res: Resource = load(AUDIO_CONFIG_PATH)
		if res is AudioConfig:
			_config = res


func _try_play_baked(id: String, volume_db: float = -6.0) -> bool:
	# Returns true if a baked audio file for `id` was found and played.
	if _config == null:
		return false
	var path: String = _config.get_sfx(id)
	if path == "" or not ResourceLoader.exists(path):
		return false
	var stream: AudioStream = _stream_cache.get(path, null)
	if stream == null:
		stream = load(path)
		if stream == null:
			return false
		_stream_cache[path] = stream
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = _db_with_user_volume(volume_db)
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
	return true


func play_shoot(tower_id: String = "", tier: int = 0) -> void:
	# Per-tower + per-tier shoot voice (ROADMAP #24). Each friend gets a
	# distinct timbre; tiers bump pitch + add a bit of bite. Falls back
	# to a generic warm pluck if tower_id is unknown.
	if not _can_play("shoot"):
		return
	var t: int = clampi(tier, 0, 3)
	if _try_play_baked("tower.%s.shoot.t%d" % [tower_id, t]):
		return
	if _try_play_baked("tower.%s.shoot" % tower_id):
		return
	match tower_id:
		"basic":
			# Lemurius — bio-banana soft thump. Low warm body, quick mute.
			_play_sweep(260.0 + t * 30.0, 180.0 + t * 20.0, 0.05, 0.24)
		"sniper":
			# Kühne — pollen whoosh + subtle chime layer per tier
			_play_sweep(620.0 + t * 80.0, 360.0, 0.07, 0.20)
		"splash":
			# JoJo — glass clink / fizz, sharper at higher tiers
			_play_tone(780.0 + t * 120.0, 0.045 + t * 0.01, 0.22)
		"cordula":
			# Cordula — volleyball pop, rubbery
			_play_sweep(360.0, 180.0 + t * 40.0, 0.06, 0.28)
		"slow":
			# Amösius — sticky tongue schleck; lower + slower per tier
			_play_sweep(500.0 - t * 60.0, 120.0, 0.08 + t * 0.01, 0.22)
		_:
			_play_tone(440.0, 0.05, 0.22)


func play_hit() -> void:
	# Soft body-hit — warm 340Hz damped sine, short. Used as generic
	# fallback when per-enemy hit SFX is unavailable.
	if not _can_play("hit"):
		return
	if _try_play_baked("hit"):
		return
	_play_tone(340.0, 0.05, 0.18)


func play_enemy_hit(enemy_id: String = "") -> void:
	# Per-enemy hit/death variation (ROADMAP #27) — short pop tinted by
	# the enemy's material.
	if not _can_play("enemy_hit"):
		return
	if _try_play_baked("enemy.%s.hit" % enemy_id):
		return
	match enemy_id:
		"basic":   # Brötli — dry bread crunch
			_play_tone(360.0, 0.03, 0.18, true)
		"fast":    # Toblerone — wrapper crinkle
			_play_tone(920.0, 0.03, 0.14, true)
		"tank":    # Cervelat — meat slap
			_play_sweep(220.0, 90.0, 0.06, 0.25)
		"healer":  # Dr.Rivella — bottle clink
			_play_tone(1400.0, 0.035, 0.18)
		"flying":  # Fondue — wet splat
			_play_tone(220.0, 0.045, 0.2, true)
		"swarm":   # Tofu — tiny squeak
			_play_tone(1650.0, 0.02, 0.12)
		"boss":    # M-Tüüfel — deep hit (partial, real roar on death)
			_play_sweep(180.0, 60.0, 0.07, 0.45)
		_:
			_play_tone(440.0, 0.04, 0.2)


func play_death(enemy_health: float = 100.0) -> void:
	# Soft downward sweep with pitch modulated by enemy size.
	# Small enemies (low health) = higher pitch "pop", big enemies =
	# deep "thump". Adds rhythm as waves progress from tofu to boss.
	if not _can_play("death"):
		return
	if _try_play_baked("death"):
		return
	var size_factor: float = clampf(enemy_health / 100.0, 0.4, 3.0)
	var base_freq: float = 220.0 / sqrt(size_factor)  # bigger → lower
	var end_freq: float = base_freq * 0.4
	_play_sweep(base_freq, end_freq, 0.08, 0.15)


func play_wave_start() -> void:
	# Warm rising announcement — starts on a low horn, ascends a perfect
	# fifth. Two-note stack (fundamental + fifth) replaces the previous
	# bright 880Hz chirp which hurt on speakers.
	if _try_play_baked("wave_start"):
		return
	_play_sweep(220.0, 330.0, 0.28, 0.42)


func play_upgrade() -> void:
	# Gentle ascending chime, octave leap from A3 to A4. Previous version
	# shot up to 1047Hz which was shrill; this stays in the warm-body
	# register and layers a soft fifth for harmonic sweetness.
	if _try_play_baked("upgrade"):
		return
	_play_sweep(220.0, 440.0, 0.32, 0.38)
	_play_tone(330.0, 0.22, 0.20)


func play_click() -> void:
	# Soft felt-pluck — warm 180 Hz body + quick falloff, ~40ms, very quiet.
	# Tried full silence, user wanted a subtle tone back but absolutely not
	# anything bright or percussive. Low fundamental + long ramp-in + short
	# decay removes the "bite" entirely.
	if _try_play_baked("ui.click", -10.0):
		return
	_play_soft_pluck()


func play_soft_pluck() -> void:
	_play_soft_pluck()


func _play_soft_pluck() -> void:
	# 16-bit so quantization noise doesn't dominate at low volumes — the
	# 8-bit version had only 256 levels which made soft sines sound like
	# scratchy radio. User report: "click sound horrendous, pains ears".
	var duration: float = 0.035
	var samples := int(_sample_rate * duration)
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = int(_sample_rate)
	audio.stereo = false
	var data := PackedByteArray()
	var freq: float = 160.0  # even warmer than before
	var attack_samples: float = float(_sample_rate) * 0.008  # 8ms ramp-in
	for i in samples:
		var t := float(i) / _sample_rate
		var attack: float = clamp(float(i) / attack_samples, 0.0, 1.0)
		var tail: float = pow(1.0 - (t / duration), 2.8)
		var env: float = attack * tail
		var body: float = sin(t * freq * TAU)
		var sample: float = body * env * 0.20  # 16-bit headroom; raw amplitude
		var s16: int = int(clamp(sample, -1.0, 1.0) * 32767.0)
		data.append(s16 & 0xFF)
		data.append((s16 >> 8) & 0xFF)
	audio.data = data
	var player := AudioStreamPlayer.new()
	player.stream = audio
	# Lower base from -12 to -18 dB on top of the 16-bit cleanup.
	player.volume_db = _db_with_user_volume(-18.0)
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)


func play_combo_milestone(tier: int) -> void:
	# Pitch-ramped celebration sweep. tier 0 = threshold 10, tier 5 = threshold 150.
	# Higher tier → higher base pitch + longer sustain.
	var base: float = 330.0 + float(tier) * 60.0  # 330 Hz → 630 Hz
	var top: float = base * 1.5                    # perfect fifth
	var dur: float = 0.20 + float(tier) * 0.04    # 0.20 s → 0.40 s
	_play_sweep(base, top, dur, 0.36)
	if tier >= 3:
		# Big milestones (≥75) layer a resonant overtone above the sweep.
		_play_tone(top * 1.25, dur * 0.8, 0.28)


func play_sell() -> void:
	# Coin-drop — descending warm tone, not the previous chirpy 660Hz.
	if _try_play_baked("sell"):
		return
	_play_sweep(440.0, 220.0, 0.18, 0.32)


func play_place() -> void:
	# Placement confirmation — low "thunk" that rises into the body
	# register. Pairs with the drop tween; must feel grounded, not bouncy.
	if _try_play_baked("place"):
		return
	_play_sweep(140.0, 240.0, 0.14, 0.38)


func play_boss_roar() -> void:
	# Deep falling rumble for boss reveal / death. Pitch descends from
	# sub-bass into the floor, amplitude ~0.5 for punch.
	if _try_play_baked("boss_roar"):
		return
	_play_sweep(95.0, 42.0, 0.8, 0.55)


func play_life_lost() -> void:
	# Heartbeat thump + dip — low double-tap to mark a life drain.
	# Pairs with the red screen flash. Short so it doesn't overwhelm.
	if _try_play_baked("life_lost"):
		return
	_play_sweep(180.0, 70.0, 0.18, 0.45)


func _play_tone(freq: float, duration: float, volume: float, noise: bool = false) -> void:
	# Warm tone generator (ROADMAP #25). 16-bit signed @ 44.1kHz.
	# Smooth cosine attack (10ms) + cosine release (15ms) + quadratic
	# decay body. Eliminates the start/end clicks that caused "rips".
	# Per-sound volume × 0.5 (was × 0.6) so polyphonic stacks (e.g. 4
	# towers shooting + 1 enemy dying simultaneously) don't sum to clip.
	var samples := int(_sample_rate * duration)
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = int(_sample_rate)
	audio.stereo = false

	var data := PackedByteArray()
	var attack_samples: float = float(_sample_rate) * 0.010   # 10ms attack
	var release_samples: float = float(_sample_rate) * 0.015  # 15ms release
	var release_start: float = float(samples) - release_samples
	var noise_avg: float = 0.0
	for i in samples:
		var t := float(i) / _sample_rate
		var progress: float = t / duration
		# Cosine-shaped attack: smoother than linear, no pop on start.
		var attack: float
		if i < attack_samples:
			attack = 0.5 - 0.5 * cos(PI * float(i) / attack_samples)
		else:
			attack = 1.0
		# Cosine-shaped release: smoother than linear cutoff, no pop on stop.
		var release: float
		if float(i) > release_start:
			release = 0.5 + 0.5 * cos(PI * (float(i) - release_start) / release_samples)
		else:
			release = 1.0
		var tail: float = pow(1.0 - progress, 2.0)
		var env: float = attack * release * tail
		var sample: float
		if noise:
			var raw: float = randf() * 2.0 - 1.0
			noise_avg = noise_avg * 0.6 + raw * 0.4
			sample = noise_avg * env * volume
		else:
			var body: float = sin(t * freq * TAU)
			var harm: float = sin(t * freq * 2.0 * TAU) * 0.33
			sample = (body + harm) * env * volume * 0.5
		var s16: int = int(clamp(sample, -1.0, 1.0) * 32767.0)
		data.append(s16 & 0xFF)
		data.append((s16 >> 8) & 0xFF)

	audio.data = data

	var player := AudioStreamPlayer.new()
	player.stream = audio
	player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	player.volume_db = _db_with_user_volume(-10.0)
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
	# Warm sweep generator. 16-bit @ 44.1kHz with cosine attack+release
	# envelopes (no clicks). Per-sound volume × 0.5 so polyphonic stacks
	# don't clip the master bus.
	var samples := int(_sample_rate * duration)
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = int(_sample_rate)
	audio.stereo = false

	var data := PackedByteArray()
	var attack_samples: float = float(_sample_rate) * 0.010
	var release_samples: float = float(_sample_rate) * 0.015
	var release_start: float = float(samples) - release_samples
	var phase: float = 0.0
	var dt: float = 1.0 / _sample_rate
	for i in samples:
		var progress_pct: float = float(i) / float(samples)
		var freq: float = freq_start + (freq_end - freq_start) * progress_pct
		phase += freq * dt
		var attack: float
		if i < attack_samples:
			attack = 0.5 - 0.5 * cos(PI * float(i) / attack_samples)
		else:
			attack = 1.0
		var release: float
		if float(i) > release_start:
			release = 0.5 + 0.5 * cos(PI * (float(i) - release_start) / release_samples)
		else:
			release = 1.0
		var tail: float = pow(1.0 - progress_pct, 2.0)
		var env: float = attack * release * tail
		var body: float = sin(phase * TAU)
		var harm: float = sin(phase * 2.0 * TAU) * 0.28
		var sample: float = (body + harm) * env * volume * 0.5
		var s16: int = int(clamp(sample, -1.0, 1.0) * 32767.0)
		data.append(s16 & 0xFF)
		data.append((s16 >> 8) & 0xFF)

	audio.data = data

	var player := AudioStreamPlayer.new()
	player.stream = audio
	player.bus = "SFX" if AudioServer.get_bus_index("SFX") >= 0 else "Master"
	player.volume_db = _db_with_user_volume(-10.0)
	add_child(player)
	player.play()
	player.finished.connect(player.queue_free)
