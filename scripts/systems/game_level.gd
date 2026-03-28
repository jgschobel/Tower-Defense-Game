class_name GameLevel
extends Node2D

## Main game level controller. Each level scene should have this as root script.

@export var level_id: int = 1

@onready var enemy_path: Path2D = $EnemyPath
@onready var wave_manager: WaveManager = $WaveManager
@onready var tower_placement: TowerPlacement = $TowerPlacement
@onready var hud: CanvasLayer = $HUD
@onready var game_over_screen: Control = $GameOverScreen
@onready var pause_menu: Control = $PauseMenu

var wave_definitions: Array = []


func _ready() -> void:
	# Safety init for standalone testing (F5 in editor)
	if CurrencyManager.gold == 0:
		GameManager.start_level(level_id)

	MusicManager.play_music()

	wave_manager.enemy_path = enemy_path
	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.wave_completed.connect(_on_wave_completed)
	wave_manager.all_waves_completed.connect(_on_all_waves_completed)

	hud.tower_selected_for_placement.connect(_on_tower_selected)
	hud.placement_cancelled.connect(_on_placement_cancelled)
	hud.next_wave_requested.connect(_on_next_wave_requested)
	hud.pause_requested.connect(_on_pause_requested)
	hud.auto_wave_toggled.connect(_on_auto_wave_toggled)

	tower_placement.tower_placed.connect(_on_tower_placed)

	GameManager.game_over.connect(_on_game_over)

	game_over_screen.visible = false
	pause_menu.visible = false

	_load_wave_data()
	wave_manager.setup_waves(wave_definitions)
	hud.show_next_wave_button(true)
	hud.update_wave_info(0, wave_manager.total_waves)


func _load_wave_data() -> void:
	var path := "res://resources/level_data/level_%d.tres" % level_id
	if ResourceLoader.exists(path):
		var level_res = load(path)
		wave_definitions = level_res.waves
	elif wave_definitions.is_empty():
		wave_definitions = _default_waves()


func _default_waves() -> Array:
	return [
		{"groups": [{"enemy_id": "basic", "count": 5, "spawn_delay": 1.0}]},
		{"groups": [{"enemy_id": "basic", "count": 8, "spawn_delay": 0.8}]},
		{"groups": [{"enemy_id": "basic", "count": 6, "spawn_delay": 0.8}, {"enemy_id": "fast", "count": 3, "spawn_delay": 0.5}]},
		{"groups": [{"enemy_id": "tank", "count": 3, "spawn_delay": 1.5}, {"enemy_id": "basic", "count": 5, "spawn_delay": 0.7}]},
		{"groups": [{"enemy_id": "fast", "count": 8, "spawn_delay": 0.4}, {"enemy_id": "tank", "count": 2, "spawn_delay": 1.2}]},
	]


func _on_wave_started(wave_num: int, total: int) -> void:
	hud.update_wave_info(wave_num, total)
	hud.show_next_wave_button(false)


func _on_wave_completed(_wave_num: int) -> void:
	if not wave_manager.all_done:
		hud.show_next_wave_button(true)


func _on_all_waves_completed() -> void:
	GameManager.complete_level()
	var stars: int = GameManager.level_stars.get(level_id, 1)
	game_over_screen.show_victory(stars)


func _on_game_over(won: bool) -> void:
	if not won:
		game_over_screen.show_defeat()


func _on_tower_selected(tower_data: Resource) -> void:
	tower_placement.start_placement(tower_data)


func _on_placement_cancelled() -> void:
	tower_placement.cancel_placement()
	hud.set_placing(false)


func _on_tower_placed(_tower: Node2D) -> void:
	hud.set_placing(false)


func _on_next_wave_requested() -> void:
	wave_manager.start_next_wave()


func _on_pause_requested() -> void:
	pause_menu.show_pause()


func _on_auto_wave_toggled(enabled: bool) -> void:
	wave_manager.auto_start_waves = enabled
	wave_manager.time_between_waves = 3.0
	# If enabling and no wave is active, start immediately
	if enabled and not wave_manager.wave_in_progress and not wave_manager.all_done:
		wave_manager.start_next_wave()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.is_pressed():
		_check_tower_tap(event.position)
	elif event is InputEventMouseButton and event.is_pressed():
		_check_tower_tap((event as InputEventMouseButton).position)


func _check_tower_tap(screen_pos: Vector2) -> void:
	if tower_placement.is_placing:
		return
	var world_pos := get_canvas_transform().affine_inverse() * screen_pos

	# Check if tapped on a placed tower
	for tower_node in get_tree().get_nodes_in_group("towers"):
		var tower := tower_node as BaseTower
		if tower and tower.global_position.distance_to(world_pos) < 50.0:
			hud.show_tower_info(tower)
			return

	# Tapped empty space — deselect
	hud.hide_tower_info()
