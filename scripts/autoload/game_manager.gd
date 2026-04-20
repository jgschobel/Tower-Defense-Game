extends Node

## Global game state manager (Autoload Singleton)
## Handles level progression, lives, game state, and save/load.

enum GameState { MENU, PLAYING, PAUSED, WON, LOST }

signal lives_changed(new_lives: int)
signal game_over(won: bool)
signal level_completed(level_id: int)
signal game_state_changed(new_state: int)

const SAVE_PATH := "user://save_data.json"
const MAX_LEVELS := 7

var current_state: int = GameState.MENU
var current_level: int = 1
var max_lives: int = 20
var lives: int = 20
var levels_unlocked: int = 1
var total_stars: int = 0
var level_stars: Dictionary = {}

var friend_photos: Dictionary = {}

# Audio settings — 0.0 = muted, 1.0 = full volume. Persisted in save file.
var music_volume: float = 0.7
var sfx_volume: float = 0.8

# Kill counters. total_kills persists across sessions (save file); level_kills
# resets at start_level and gets surfaced on the game over / victory screen.
var total_kills: int = 0
var level_kills: int = 0


func _ready() -> void:
	load_game()
	# Warm up enemy and tower textures so Level 1's first wave doesn't
	# hitch to 1 FPS loading them from disk (issue #46). Runs once at
	# game start while the menu is showing.
	call_deferred("_warmup_textures")


func _warmup_textures() -> void:
	# Auto-discover every texture referenced by tower_data + enemy_data
	# .tres files rather than maintaining a hand-edited path list.
	# Agent-audit DRIFT #27 — the old list missed swarm + newer enemies
	# and stayed glued to the L1-L3 lineup even after L4-L7 shipped.
	# Cheap one-time cost at game start.
	var dirs := ["res://resources/tower_data", "res://resources/enemy_data"]
	for dir_path in dirs:
		var dir := DirAccess.open(dir_path)
		if dir == null:
			continue
		dir.list_dir_begin()
		var fn := dir.get_next()
		while fn != "":
			if fn.ends_with(".tres"):
				var res_path := "%s/%s" % [dir_path, fn]
				var res = load(res_path)
				if res and "custom_texture" in res and res.custom_texture:
					# Touch the texture to ensure GPU upload
					res.custom_texture.get_size()
			fn = dir.get_next()
		dir.list_dir_end()
	# Projectile + UI textures are a tiny fixed set that don't live in .tres
	for p in [
		"res://assets/textures/projectiles/banana.png",
		"res://assets/textures/projectiles/tongue.png",
		"res://assets/textures/ui/money.png",
	]:
		if ResourceLoader.exists(p):
			load(p)


func set_music_volume(v: float) -> void:
	music_volume = clampf(v, 0.0, 1.0)
	save_game()


func set_sfx_volume(v: float) -> void:
	sfx_volume = clampf(v, 0.0, 1.0)
	save_game()


func start_level(level_id: int) -> void:
	current_level = level_id
	# Load level data for starting gold/lives
	var data_path := "res://resources/level_data/level_%d.tres" % level_id
	if ResourceLoader.exists(data_path):
		var level_data = load(data_path)
		max_lives = level_data.starting_lives
		CurrencyManager.gold = level_data.starting_gold
		CurrencyManager.gold_changed.emit(CurrencyManager.gold)
	else:
		max_lives = 20
		CurrencyManager.reset_for_level(level_id)
	lives = max_lives
	level_kills = 0
	set_state(GameState.PLAYING)


func record_kill() -> void:
	level_kills += 1
	total_kills += 1


func set_state(new_state: int) -> void:
	current_state = new_state
	game_state_changed.emit(new_state)


func lose_life(amount: int = 1) -> void:
	lives = max(0, lives - amount)
	lives_changed.emit(lives)
	if lives <= 0:
		set_state(GameState.LOST)
		game_over.emit(false)


func complete_level() -> void:
	var stars := _calculate_stars()
	# JSON round-trips coerce int keys to strings, so after save+reload
	# `level_stars[current_level]` (int key) misses. Check both forms.
	# Audit P0 #3: without this, total_stars inflated on every replay.
	var prev_stars: int = int(level_stars.get(current_level, level_stars.get(str(current_level), 0)))
	if stars > prev_stars:
		total_stars += stars - prev_stars
		level_stars[current_level] = stars
		# Also drop the string-keyed stale entry (if any) so future reads
		# are consistent.
		if level_stars.has(str(current_level)):
			level_stars.erase(str(current_level))

	if current_level >= levels_unlocked and current_level < MAX_LEVELS:
		levels_unlocked = current_level + 1

	# Aminos yield (ROADMAP #48). Scales with level_id + stars so later
	# levels + perfect clears reward more. Awarded every clear, but the
	# same level never double-dips within a run.
	if AminosManager and AminosManager.has_method("award_for_level_clear"):
		AminosManager.award_for_level_clear(current_level, stars)

	set_state(GameState.WON)
	level_completed.emit(current_level)
	save_game()


func _calculate_stars() -> int:
	var life_pct := float(lives) / float(max_lives)
	if life_pct >= 0.9:
		return 3
	elif life_pct >= 0.5:
		return 2
	else:
		return 1


func toggle_pause() -> void:
	if current_state == GameState.PLAYING:
		set_state(GameState.PAUSED)
		get_tree().paused = true
	elif current_state == GameState.PAUSED:
		set_state(GameState.PLAYING)
		get_tree().paused = false


# -- Save / Load --

func save_game() -> void:
	var save_data := {
		"levels_unlocked": levels_unlocked,
		"level_stars": level_stars,
		"total_stars": total_stars,
		"currency_total": CurrencyManager.total_gold_earned,
		"friend_photos": friend_photos,
		"music_volume": music_volume,
		"sfx_volume": sfx_volume,
		"total_kills": total_kills,
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(save_data, "\t"))


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK:
		var save_data: Dictionary = json.data
		levels_unlocked = save_data.get("levels_unlocked", 1)
		level_stars = save_data.get("level_stars", {})
		# Normalize string keys back to int on load so subsequent dict
		# lookups by level_id (int) hit consistently. Audit P0 #3.
		var normalized := {}
		for k in level_stars.keys():
			if typeof(k) == TYPE_STRING and k.is_valid_int():
				normalized[int(k)] = int(level_stars[k])
			else:
				normalized[k] = int(level_stars[k])
		level_stars = normalized
		# Recompute total_stars from the authoritative per-level dict
		# rather than trusting a possibly-drifted persisted int (audit P2 #20).
		var recomputed := 0
		for v in level_stars.values():
			recomputed += int(v)
		total_stars = recomputed
		friend_photos = save_data.get("friend_photos", {})
		music_volume = save_data.get("music_volume", 0.7)
		sfx_volume = save_data.get("sfx_volume", 0.8)
		total_kills = save_data.get("total_kills", 0)


func assign_friend_photo(character_id: String, texture_path: String) -> void:
	friend_photos[character_id] = texture_path
	save_game()


func get_friend_photo(character_id: String) -> Texture2D:
	var path: String = friend_photos.get(character_id, "")
	if path != "" and FileAccess.file_exists(path):
		var image := Image.load_from_file(path)
		if image:
			return ImageTexture.create_from_image(image)
	return null
