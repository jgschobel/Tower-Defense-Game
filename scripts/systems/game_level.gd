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
	_apply_level_tint()
	_soften_background()
	_spawn_atmosphere_particles()
	wave_manager.setup_waves(wave_definitions)
	hud.show_next_wave_button(true)
	hud.update_wave_info(0, wave_manager.total_waves)
	_spawn_path_direction_arrows()


func _soften_background() -> void:
	# The maps_v3 AI art contains a giant faded "M" / Migros watermark
	# baked into the texture. Modulate dim + translucent overlay weren't
	# enough — the M shape still dominated. Going nuclear: dim to 0.30
	# and add a more opaque overlay (alpha 0.55) so the watermark is
	# essentially invisible. Fruit crates / path are still readable
	# because their bright colors saturate through.
	var bg := get_node_or_null("Background")
	if bg is Sprite2D:
		bg.modulate = Color(0.35, 0.35, 0.38, 1.0)
		var overlay := ColorRect.new()
		overlay.name = "FloorWash"
		overlay.color = Color(0.42, 0.40, 0.38, 0.55)
		overlay.size = Vector2(1280, 720)
		overlay.position = Vector2.ZERO
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.z_index = -90
		add_child(overlay)


func _apply_level_tint() -> void:
	# D18: CanvasModulate tint per level using background_color from level_data.
	# Gives each level a distinct atmospheric colour cast without needing
	# per-level scene files. Skipped for levels with no .tres or neutral white.
	var path := "res://resources/level_data/level_%d.tres" % level_id
	if not ResourceLoader.exists(path):
		return
	var res = load(path)
	if res == null or not ("background_color" in res):
		return
	var bg: Color = res.background_color
	# Only apply if non-trivially different from white (neutral level)
	if bg.is_equal_approx(Color.WHITE):
		return
	# Blend toward white so the tint is atmospheric, not overwhelming.
	# 70% white + 30% level colour keeps sprites readable.
	var tint := bg.lerp(Color.WHITE, 0.7)
	var cm := CanvasModulate.new()
	cm.name = "LevelTint"
	cm.color = tint
	add_child(cm)
	# D19: light flicker for fluorescent (L1) and neon (L6) atmospheres.
	# Tiny colour oscillation on the CanvasModulate — just enough to feel
	# alive without being distracting. Not applied to other levels.
	if level_id == 1 or level_id == 6:
		var flicker_speed: float = 0.9 if level_id == 1 else 0.45
		var flicker_depth: float = 0.06 if level_id == 1 else 0.10
		var dim := tint.darkened(flicker_depth)
		var flicker := cm.create_tween().set_loops()
		flicker.tween_property(cm, "color", dim, flicker_speed).set_trans(Tween.TRANS_SINE)
		flicker.tween_property(cm, "color", tint, flicker_speed * 0.7).set_trans(Tween.TRANS_SINE)
		# Occasional deeper dip (simulates ballast buzz on fluorescents)
		if level_id == 1:
			flicker.tween_property(cm, "color", tint.darkened(flicker_depth * 2.5), 0.05)
			flicker.tween_property(cm, "color", tint, 0.08)


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
		# Subtle pulse — staggered by chevron index so adjacent ones don't
		# blink in lockstep. Reads as "flow direction" without being noisy.
		var phase: float = (dist / step) * 0.3
		var pulse := poly.create_tween().set_loops()
		pulse.tween_interval(phase)
		pulse.tween_property(poly, "modulate:a", 0.85, 0.55).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(poly, "modulate:a", 0.45, 0.85).set_trans(Tween.TRANS_SINE)
		dist += step


func _spawn_atmosphere_particles() -> void:
	# D17: per-level CPUParticles2D overlay. Particles float across the
	# viewport giving each level atmospheric life without new art assets.
	# Spawned here so every level gets them automatically.
	var cfg: Dictionary = {}
	match level_id:
		2: cfg = {"color": Color(0.75, 0.9, 1.0, 0.55), "gravity": Vector2(10, 60), "count": 35, "speed": 30.0, "size": 3.5, "spread": 180.0}  # frost
		3: cfg = {"color": Color(0.98, 0.96, 0.9, 0.4), "gravity": Vector2(-5, 25), "count": 28, "speed": 20.0, "size": 5.0, "spread": 160.0}  # flour
		4: cfg = {"color": Color(0.3, 0.9, 0.2, 0.45), "gravity": Vector2(0, -35), "count": 22, "speed": 25.0, "size": 4.0, "spread": 60.0}    # acid bubbles
		5: cfg = {"color": Color(1.0, 0.8, 0.2, 0.5), "gravity": Vector2(20, -10), "count": 30, "speed": 40.0, "size": 3.0, "spread": 140.0}   # confetti
		6: cfg = {"color": Color(0.55, 0.7, 1.0, 0.4), "gravity": Vector2(15, 90), "count": 45, "speed": 80.0, "size": 2.0, "spread": 20.0}    # rain
		7: cfg = {"color": Color(0.6, 0.5, 0.25, 0.5), "gravity": Vector2(60, 15), "count": 25, "speed": 55.0, "size": 4.5, "spread": 40.0}    # wind leaves
		8: cfg = {"color": Color(0.4, 0.65, 1.0, 0.4), "gravity": Vector2(5, 45), "count": 20, "speed": 30.0, "size": 2.5, "spread": 120.0}   # shopping sparks
		9: cfg = {"color": Color(0.7, 0.3, 1.0, 0.5), "gravity": Vector2(-8, 30), "count": 40, "speed": 45.0, "size": 2.0, "spread": 180.0}   # data glitch
		10: cfg = {"color": Color(1.0, 0.45, 0.1, 0.55), "gravity": Vector2(-5, -50), "count": 30, "speed": 40.0, "size": 4.0, "spread": 80.0} # embers
	if cfg.is_empty():
		return
	var particles := CPUParticles2D.new()
	particles.name = "AtmosphereParticles"
	particles.emitting = true
	particles.amount = cfg["count"]
	particles.lifetime = 6.0
	particles.one_shot = false
	particles.explosiveness = 0.0
	particles.randomness = 1.0
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_rect_extents = Vector2(640, 360)
	particles.position = Vector2(640, 360)
	particles.gravity = cfg["gravity"]
	particles.initial_velocity_min = cfg["speed"] * 0.5
	particles.initial_velocity_max = cfg["speed"]
	particles.spread = cfg["spread"]
	particles.color = cfg["color"]
	particles.scale_amount_min = cfg["size"] * 0.6
	particles.scale_amount_max = cfg["size"]
	particles.z_index = 10
	add_child(particles)


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
		# Mid-game celebration — visible reward at every wave end (not just
		# the level-end victory screen). Skip on the final wave since
		# show_victory() already plays.
		if hud.has_method("show_wave_clear_celebration"):
			hud.show_wave_clear_celebration()


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
	if hud.has_method("on_enemy_count_changed"):
		hud.on_enemy_count_changed()


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
