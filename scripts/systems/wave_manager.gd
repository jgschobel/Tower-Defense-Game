class_name WaveManager
extends Node

## Manages enemy waves for a level. Spawns enemies along the path.

signal wave_started(wave_number: int, total_waves: int)
signal wave_completed(wave_number: int)
signal all_waves_completed
signal enemies_remaining_changed(count: int)

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
var _spawn_timer: float = 0.0
var _base_enemy_scene: PackedScene


func _ready() -> void:
	_base_enemy_scene = preload("res://scenes/enemies/base_enemy.tscn")


func setup_waves(waves: Array) -> void:
	_wave_data = waves
	total_waves = waves.size()
	current_wave = 0


func start_next_wave() -> void:
	if current_wave >= total_waves:
		return

	current_wave += 1
	wave_in_progress = true
	is_spawning = true

	var wave: Dictionary = _wave_data[current_wave - 1]
	_build_spawn_queue(wave)

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
		var count: int = group_dict.get("count", 1)
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

	enemies_alive += 1
	enemies_remaining_changed.emit(enemies_alive)


func _on_enemy_died(_enemy: Node) -> void:
	_decrement_enemies()


func _on_enemy_reached_end(_enemy: Node) -> void:
	_decrement_enemies()


func _decrement_enemies() -> void:
	enemies_alive -= 1
	enemies_remaining_changed.emit(enemies_alive)

	if enemies_alive <= 0 and not is_spawning:
		wave_in_progress = false
		wave_completed.emit(current_wave)

		if current_wave >= total_waves:
			all_done = true
			all_waves_completed.emit()
		elif auto_start_waves:
			var timer := get_tree().create_timer(time_between_waves)
			timer.timeout.connect(start_next_wave)
