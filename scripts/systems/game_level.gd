class_name GameLevel
extends Node2D

## Main game level controller. Each level scene should have this as root script.

@export var level_id: int = 1

@onready var enemy_path: Path2D = $EnemyPath
@onready var wave_manager: WaveManager = $WaveManager
@onready var tower_placement: TowerPlacement = $TowerPlacement
@onready var hud: CanvasLayer = $HUD
@onready var game_over_screen: Node = $GameOverScreen/Overlay
@onready var pause_menu: Control = $PauseMenu

var wave_definitions: Array = []
var _adjacency_viz: Node2D = null


func _ready() -> void:
	# Always use the level from GameManager (set by level select)
	level_id = GameManager.current_level

	# Safety init for standalone testing (F5 in editor)
	if CurrencyManager.gold == 0:
		GameManager.start_level(level_id)

	Engine.time_scale = 1.0
	if MusicManager.has_method("set_level_track"):
		MusicManager.set_level_track(level_id)
	else:
		MusicManager.play_music()

	wave_manager.enemy_path = enemy_path
	wave_manager.wave_started.connect(_on_wave_started)
	wave_manager.wave_completed.connect(_on_wave_completed)
	wave_manager.all_waves_completed.connect(_on_all_waves_completed)
	wave_manager.enemies_remaining_changed.connect(_on_enemies_remaining_changed)
	if wave_manager.has_signal("wave_progress_changed"):
		wave_manager.wave_progress_changed.connect(_on_wave_progress_changed)
	# HUD shows big reveal the first time each enemy type spawns
	wave_manager.enemy_introduced.connect(_on_enemy_introduced)

	hud.tower_selected_for_placement.connect(_on_tower_selected)
	hud.placement_cancelled.connect(_on_placement_cancelled)
	hud.next_wave_requested.connect(_on_next_wave_requested)
	hud.pause_requested.connect(_on_pause_requested)
	hud.auto_wave_toggled.connect(_on_auto_wave_toggled)

	tower_placement.tower_placed.connect(_on_tower_placed)
	tower_placement.tower_removed.connect(_on_tower_removed)
	tower_placement.placement_invalid.connect(_on_placement_invalid)
	tower_placement.placement_cancelled.connect(_on_tower_placement_cancelled)

	GameManager.game_over.connect(_on_game_over)

	game_over_screen.visible = false
	pause_menu.visible = false

	_load_wave_data()
	wave_manager.setup_waves(wave_definitions)
	hud.show_next_wave_button(true)
	hud.update_wave_info(0, wave_manager.total_waves)
	_spawn_path_direction_arrows()


func _spawn_path_direction_arrows() -> void:
	# Add small chevrons along the enemy path pointing in the direction
	# of travel. Makes the path's orientation obvious — on winding paths
	# the player can otherwise lose track of which side the spawn is on.
	if not enemy_path or not enemy_path.curve:
		return
	# Avoid re-populating on scene reload / re-ready
	if enemy_path.get_node_or_null("DirectionArrows") != null:
		return
	var arrows_container := Node2D.new()
	arrows_container.name = "DirectionArrows"
	arrows_container.z_index = -1  # sit below enemies but above path
	enemy_path.add_child(arrows_container)
	var curve := enemy_path.curve
	var length: float = curve.get_baked_length()
	var step: float = 140.0  # one chevron every ~140px
	var dist: float = step * 0.5  # start a bit past the spawn
	var chevron_color := Color(0.1, 0.05, 0.02, 0.45)
	while dist < length - step * 0.3:
		var pos: Vector2 = curve.sample_baked(dist)
		var ahead: Vector2 = curve.sample_baked(minf(dist + 20.0, length))
		var dir: Vector2 = (ahead - pos).normalized()
		if dir.length() < 0.01:
			dist += step
			continue
		var perp: Vector2 = Vector2(-dir.y, dir.x)
		var tip: Vector2 = pos + dir * 12.0
		var back_left: Vector2 = pos - dir * 6.0 + perp * 10.0
		var back_right: Vector2 = pos - dir * 6.0 - perp * 10.0
		var poly := Polygon2D.new()
		poly.polygon = PackedVector2Array([tip, back_left, back_right])
		poly.color = chevron_color
		poly.position = Vector2.ZERO
		arrows_container.add_child(poly)
		dist += step


func _load_wave_data() -> void:
	var path := "res://resources/level_data/level_%d.tres" % level_id
	if ResourceLoader.exists(path):
		var level_res = load(path)
		# Defensive: corrupt .tres or missing `waves` field would otherwise
		# crash wave_manager.setup_waves(null) on .size(). Audit P1 #11.
		if level_res and level_res.has_method("get") and level_res.waves and level_res.waves is Array:
			wave_definitions = level_res.waves
		else:
			push_warning("level_%d.tres missing/empty waves field — using defaults" % level_id)
			wave_definitions = _default_waves()
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
	SfxManager.play_wave_start()
	_pay_farm_towers()


func _pay_farm_towers() -> void:
	# Farm towers (ROADMAP #38) produce gold at the start of every wave.
	# Yield = gold_per_round + sum of tier bonuses from upgrade_damage_bonus
	# (repurposed as "gold bonus per tier" for farms).
	for tower in get_tree().get_nodes_in_group("towers"):
		if tower is BaseTower and tower.data and tower.data.gold_per_round > 0:
			var yield_amount: int = tower.data.gold_per_round
			# Branching: each path tier adds its damage_bonus as gold
			if tower.data.has_branching_upgrades():
				for i in tower.path_a_tier:
					if i < tower.data.path_a_damage_bonus.size():
						yield_amount += int(tower.data.path_a_damage_bonus[i])
				for i in tower.path_b_tier:
					if i < tower.data.path_b_damage_bonus.size():
						yield_amount += int(tower.data.path_b_damage_bonus[i])
			else:
				for i in tower.upgrade_level:
					if i < tower.data.upgrade_damage_bonus.size():
						yield_amount += int(tower.data.upgrade_damage_bonus[i])
			CurrencyManager.add_gold(yield_amount)
			if tower.has_method("flash_earn"):
				tower.flash_earn(yield_amount)


func _on_wave_completed(_wave_num: int) -> void:
	if not wave_manager.all_done:
		hud.show_next_wave_button(true)


func _on_all_waves_completed() -> void:
	GameManager.complete_level()
	hud.hide_tower_info()
	var stars: int = GameManager.level_stars.get(level_id, 1)
	game_over_screen.show_victory(stars)


func _on_game_over(won: bool) -> void:
	hud.hide_tower_info()
	if not won:
		game_over_screen.show_defeat()


func _on_tower_selected(tower_data: Resource) -> void:
	tower_placement.start_placement(tower_data)


func _on_placement_cancelled() -> void:
	tower_placement.cancel_placement()
	hud.set_placing(false)


func _on_tower_placed(_tower: Node2D) -> void:
	hud.set_placing(false)
	_ensure_adjacency_viz()
	if _adjacency_viz:
		_adjacency_viz.refresh()


func _on_tower_removed(_tower: Node2D) -> void:
	if _adjacency_viz:
		_adjacency_viz.refresh()


func _ensure_adjacency_viz() -> void:
	# Lazily spawn the AdjacencyVisualizer the first time a tower is
	# placed. Lives at the level root so it draws in world coordinates.
	if _adjacency_viz != null and is_instance_valid(_adjacency_viz):
		return
	var script: Script = load("res://scripts/systems/adjacency_visualizer.gd")
	if script == null:
		return
	_adjacency_viz = Node2D.new()
	_adjacency_viz.set_script(script)
	_adjacency_viz.name = "AdjacencyVisualizer"
	add_child(_adjacency_viz)


func _on_placement_invalid(reason: String) -> void:
	hud.show_toast(reason)


func _on_tower_placement_cancelled() -> void:
	# Placement cancelled (from HUD button, invalid drop, focus-out, or
	# re-entry). Clear any error toast so it doesn't linger past the
	# context that produced it. Playtest-feedback #104.
	hud.clear_toast()


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


func _on_enemies_remaining_changed(count: int) -> void:
	hud.update_enemy_count(count)


func _on_wave_progress_changed(pct: float) -> void:
	if hud.has_method("update_wave_progress"):
		hud.update_wave_progress(pct)


func _on_enemy_introduced(enemy_id: String, enemy_data: Resource) -> void:
	if hud and hud.has_method("show_enemy_intro"):
		hud.show_enemy_intro(enemy_id, enemy_data)


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
