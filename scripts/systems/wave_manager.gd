class_name WaveManager
extends Node

## Manages enemy waves for a level. Spawns enemies along the path.

signal wave_started(wave_number: int, total_waves: int)
signal wave_completed(wave_number: int)
signal all_waves_completed
signal enemies_remaining_changed(count: int)
signal wave_progress_changed(pct: float)  # ROADMAP #8: sub-wave progress
# First time each enemy type shows up in this level — HUD builds an intro
signal enemy_introduced(enemy_id: String, enemy_data: Resource)

# Track which types have been seen this level
var _seen_enemy_ids: Array[String] = []

@export var enemy_path: Path2D
@export var auto_start_waves: bool = false
@export var time_between_waves: float = 5.0

var current_wave: int = 0
var total_waves: int = 0
var enemies_alive: int = 0
var is_spawning: bool = false
var wave_in_progress: bool = false
var all_done: bool = false

var _wave_data: Array = []
var _spawn_queue: Array = []
var _wave_total_enemies: int = 0
var _wave_defeated_enemies: int = 0
var _spawn_timer: float = 0.0
var _base_enemy_scene: PackedScene


func _ready() -> void:
	_base_enemy_scene = preload("res://scenes/enemies/base_enemy.tscn")
	# Register in group so HUD can find us reliably during scene reloads
	add_to_group("wave_manager")


func setup_waves(waves: Array) -> void:
	_wave_data = waves
	total_waves = waves.size()
	current_wave = 0
	call_deferred("_preload_enemy_resources", waves)


func get_next_wave_preview() -> Array:
	# Returns enemy groups in the NEXT wave (not current), as an Array of
	# {enemy_id: String, count: int}. Used by HUD to show what's coming
	# before the player taps "Nächsti Welle schicke". Empty if no more.
	if current_wave >= total_waves:
		return []
	var wave: Dictionary = _wave_data[current_wave]  # next = current_wave index (0-based)
	var groups: Array = wave.get("groups", [])
	var out: Array = []
	for g in groups:
		var gd: Dictionary = g
		out.append({
			"enemy_id": gd.get("enemy_id", "basic"),
			"count": gd.get("count", 1),
		})
	return out


func _preload_enemy_resources(waves: Array) -> void:
	# Warm the ResourceLoader cache for every enemy type before any wave
	# starts. Without this, the first `load()` call per enemy type in
	# _spawn_enemy() hits the disk mid-frame and causes a visible hitch
	# (reported as 1 FPS spike on L1 wave-1 start, issue #73 / #78).
	var seen: Dictionary = {}
	for wave in waves:
		var wave_dict: Dictionary = wave
		for group in wave_dict.get("groups", []):
			var group_dict: Dictionary = group
			var enemy_id: String = group_dict.get("enemy_id", "basic")
			if enemy_id in seen:
				continue
			seen[enemy_id] = true
			var data_path := "res://resources/enemy_data/%s.tres" % enemy_id
			if ResourceLoader.exists(data_path):
				var enemy_data = ResourceLoader.load(data_path)
				# Touch the custom_texture + spawns_on_death chain so their
				# pngs + linked resources are also cached. Without this,
				# the first spawn of an enemy with a new texture still
				# stalls on image decode. Fixes playtest-feedback #78.
				if enemy_data and "custom_texture" in enemy_data and enemy_data.custom_texture:
					var _tex = enemy_data.custom_texture  # deref → ensures decode
					_tex.get_size()  # force texture materialization on GPU
				if enemy_data and "spawns_on_death" in enemy_data and enemy_data.spawns_on_death != "":
					var child_path := "res://resources/enemy_data/%s.tres" % enemy_data.spawns_on_death
					if ResourceLoader.exists(child_path) and not (enemy_data.spawns_on_death in seen):
						seen[enemy_data.spawns_on_death] = true
						ResourceLoader.load(child_path)


func start_next_wave() -> void:
	if current_wave >= total_waves:
		return

	current_wave += 1
	wave_in_progress = true
	is_spawning = true

	var wave: Dictionary = _wave_data[current_wave - 1]
	_build_spawn_queue(wave)
	_wave_total_enemies = _spawn_queue.size()
	_wave_defeated_enemies = 0
	wave_progress_changed.emit(0.0)

	wave_started.emit(current_wave, total_waves)


func _build_spawn_queue(wave: Dictionary) -> void:
	_spawn_queue.clear()
	var groups: Array = wave.get("groups", [])

	# Enforce a minimum spawn delay floor to prevent visual stacking.
	# Previously: if spawn_delay was set to 0.1s with move_speed 80 px/s,
	# consecutive enemies entered the path only 8px apart and visually
	# piled up at the spawn point. Floor at 0.35s guarantees at least
	# ~28px gap at base speed — enough to read as a conga line.
	const MIN_DELAY: float = 0.35

	for group in groups:
		var group_dict: Dictionary = group
		var enemy_id: String = group_dict.get("enemy_id", "basic")
		var count: int = maxi(1, roundi(group_dict.get("count", 1) * (GameManager.difficulty_count_mult() if GameManager else 1.0)))
		var raw_delay: float = group_dict.get("spawn_delay", 1.0)
		var delay: float = maxf(raw_delay, MIN_DELAY)

		for i in count:
			_spawn_queue.append({
				"enemy_id": enemy_id,
				"delay": delay,
			})

	_spawn_timer = 0.5


func _process(delta: float) -> void:
	if not is_spawning or _spawn_queue.is_empty():
		return

	_spawn_timer -= delta
	if _spawn_timer <= 0.0:
		var entry: Dictionary = _spawn_queue.pop_front()
		_spawn_enemy(entry.enemy_id)
		if not _spawn_queue.is_empty():
			_spawn_timer = _spawn_queue[0].delay
		else:
			is_spawning = false


func _spawn_enemy(enemy_id: String) -> void:
	if not enemy_path:
		push_error("WaveManager: No enemy_path assigned!")
		return

	var data_path := "res://resources/enemy_data/%s.tres" % enemy_id
	var enemy_data = null
	if ResourceLoader.exists(data_path):
		enemy_data = load(data_path)
	else:
		push_warning("WaveManager: Enemy data '%s' not found, using basic" % enemy_id)
		var fallback := "res://resources/enemy_data/basic.tres"
		if ResourceLoader.exists(fallback):
			enemy_data = load(fallback)

	# Prefer the pool to avoid instantiate/queue_free churn at scale.
	# Falls back to instantiate if pool loads late.
	var enemy_instance: Node = null
	if EnemyPool and EnemyPool.has_method("acquire"):
		enemy_instance = EnemyPool.acquire(enemy_data, enemy_path)
	if enemy_instance == null:
		enemy_instance = _base_enemy_scene.instantiate()
		enemy_instance.data = enemy_data
		enemy_path.add_child(enemy_instance)

	enemy_instance.add_to_group("enemies")
	# Connect signals only once per instance to avoid dupe fires when
	# the same pooled enemy is reused across waves
	if not enemy_instance.enemy_died.is_connected(_on_enemy_died):
		enemy_instance.enemy_died.connect(_on_enemy_died)
	if not enemy_instance.enemy_reached_end.is_connected(_on_enemy_reached_end):
		enemy_instance.enemy_reached_end.connect(_on_enemy_reached_end)

	# First-appearance: fire signal for HUD to show a big intro
	if enemy_id not in _seen_enemy_ids:
		_seen_enemy_ids.append(enemy_id)
		enemy_introduced.emit(enemy_id, enemy_data)

	enemies_alive += 1
	enemies_remaining_changed.emit(enemies_alive)


func _on_enemy_died(_enemy: Node) -> void:
	_decrement_enemies()


func _on_enemy_reached_end(_enemy: Node) -> void:
	_decrement_enemies()


func _decrement_enemies() -> void:
	enemies_alive -= 1
	enemies_remaining_changed.emit(enemies_alive)
	_wave_defeated_enemies += 1
	if _wave_total_enemies > 0:
		wave_progress_changed.emit(clampf(float(_wave_defeated_enemies) / float(_wave_total_enemies), 0.0, 1.0))

	if enemies_alive <= 0 and not is_spawning:
		wave_in_progress = false
		wave_completed.emit(current_wave)

		if current_wave >= total_waves:
			all_done = true
			all_waves_completed.emit()
		elif auto_start_waves:
			var timer := get_tree().create_timer(time_between_waves)
			timer.timeout.connect(start_next_wave)
