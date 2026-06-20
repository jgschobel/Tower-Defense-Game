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
var _wave_receipt: WaveReceipt = null
var _combo_bubble: ComboMilestoneBubble = null
# Selbschtskan-Schiff copycat tracking. WaveManager reads these via
# get_meta to skin newly spawned copycat enemies. "" means no tower
# placed yet — copycat falls back to a generic dark silhouette.
var most_recent_tower_id: String = ""
var most_recent_tower_texture: Texture2D = null


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
	_spawn_level_vignette()
	_smooth_path_overlay()
	_spawn_atmosphere_particles()
	wave_manager.setup_waves(wave_definitions)
	hud.show_next_wave_button(true)
	hud.update_wave_info(0, wave_manager.total_waves)
	_spawn_path_direction_arrows()
	_combo_bubble = ComboMilestoneBubble.new()
	hud.add_child(_combo_bubble)


func _soften_background() -> void:
	# The maps_v3 AI art contains a faded "M" watermark baked into the
	# texture. The old nuclear approach (modulate 0.35 + 55% grey wash)
	# hid the watermark but murdered the art — every level read as dark
	# mud in playtests. New balance: keep most of the painting's life
	# (modulate 0.72) and use a light desaturating wash (alpha 0.22)
	# that takes the edge off the watermark without burying the map.
	# Gameplay readability comes from the path overlay + enemy contrast,
	# not from blacking out the floor.
	var bg := get_node_or_null("Background")
	if bg is Sprite2D:
		bg.modulate = Color(0.72, 0.72, 0.74, 1.0)
		var overlay := ColorRect.new()
		overlay.name = "FloorWash"
		overlay.color = Color(0.42, 0.40, 0.38, 0.22)
		overlay.size = Vector2(1280, 720)
		overlay.position = Vector2.ZERO
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		overlay.z_index = -90
		add_child(overlay)


func _spawn_level_vignette() -> void:
	# Cinematic radial vignette over the play field. Darkens the corners
	# while keeping the path / tower area bright, giving the AI-generated
	# map art the polish of a deliberately framed scene. Sits above the
	# FloorWash (z=-90) but below all gameplay sprites.
	var vignette := ColorRect.new()
	vignette.name = "LevelVignette"
	vignette.size = Vector2(1280, 720)
	vignette.position = Vector2.ZERO
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vignette.z_index = -88
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://assets/shaders/level_vignette.gdshader")
	mat.set_shader_parameter("strength", 0.55)
	mat.set_shader_parameter("inner_radius", 0.42)
	mat.set_shader_parameter("outer_radius", 0.86)
	# Per-level tint pull: cool levels (L2/L9) get a bluer vignette,
	# warm levels (L3 bakery, L5 kasse) get a warmer one. Default is
	# near-black for neutral levels.
	var tint: Color = Color(0.03, 0.02, 0.0, 1.0)
	match level_id:
		2: tint = Color(0.02, 0.04, 0.08, 1.0)  # freezer cold
		3: tint = Color(0.08, 0.04, 0.02, 1.0)  # bakery warm
		5: tint = Color(0.10, 0.05, 0.01, 1.0)  # boss kasse gold
		7: tint = Color(0.05, 0.02, 0.08, 1.0)  # rooftop dusk
		9: tint = Color(0.03, 0.0, 0.06, 1.0)   # cumulus glitch
		10: tint = Color(0.10, 0.02, 0.02, 1.0) # finale crimson
	mat.set_shader_parameter("tint", tint)
	vignette.material = mat
	add_child(vignette)


func _smooth_path_overlay() -> void:
	# The per-level PathBorder/PathDraw Line2D nodes were authored with
	# the curve's raw CONTROL POINTS as straight segments — a hard-angled
	# zigzag that doesn't even match where enemies actually walk (the
	# Path2D curve has bezier in/out handles). Replace both with the
	# curve's baked points so the drawn walkway is smooth and hugs the
	# true route on every level, then restyle as a subtle trodden-floor
	# band instead of a loud solid stripe.
	if not enemy_path or not enemy_path.curve:
		return
	var baked: PackedVector2Array = enemy_path.curve.get_baked_points()
	if baked.size() < 2:
		return
	# Per-level contrast tuning. On dark levels (L2 freezer shelves, L8
	# coop blue-tile, L9 cumulus neon, L10 finale dark) the warm trodden
	# overlay disappears into the floor pattern — players had to guess
	# where enemies walk. Bright levels (L1 crates, L3 bakery) keep the
	# subtle trodden look so the painted floor reads. Dark levels get a
	# warm gold line that pops against cool/dark backgrounds.
	var dark_level_ids: Array = [2, 4, 8, 9, 10]
	var is_dark: bool = level_id in dark_level_ids
	var border_color: Color
	var draw_color: Color
	if is_dark:
		border_color = Color(0.05, 0.03, 0.0, 0.55)
		draw_color = Color(1.0, 0.82, 0.40, 0.34)
	else:
		border_color = Color(0.12, 0.08, 0.05, 0.35)
		draw_color = Color(0.88, 0.80, 0.55, 0.22)
	var border := get_node_or_null("PathBorder")
	if border is Line2D:
		border.points = baked
		border.width = 54.0 if is_dark else 52.0
		border.default_color = border_color
		border.joint_mode = Line2D.LINE_JOINT_ROUND
		border.begin_cap_mode = Line2D.LINE_CAP_ROUND
		border.end_cap_mode = Line2D.LINE_CAP_ROUND
	var draw := get_node_or_null("PathDraw")
	if draw is Line2D:
		draw.points = baked
		draw.width = 42.0 if is_dark else 38.0
		draw.default_color = draw_color
		draw.joint_mode = Line2D.LINE_JOINT_ROUND
		draw.begin_cap_mode = Line2D.LINE_CAP_ROUND
		draw.end_cap_mode = Line2D.LINE_CAP_ROUND


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
	_dismiss_wave_receipt()
	CurrencyManager.reset_wave_gold()
	for tower in get_tree().get_nodes_in_group("towers"):
		if tower.has_method("reset_wave_stats"):
			tower.reset_wave_stats()
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


func _on_wave_completed(wave_num: int) -> void:
	GameManager.earn_cumulus(1)
	# Check current_wave < total_waves (not all_done) because all_done is set
	# AFTER this signal fires — using all_done here would always be false on the
	# final wave, showing the "next wave" button right before the victory screen.
	if wave_manager.current_wave < wave_manager.total_waves:
		hud.show_next_wave_button(true)
		# Mid-game celebration — visible reward at every wave end (not just
		# the level-end victory screen). Skip on the final wave since
		# show_victory() already plays.
		if hud.has_method("show_wave_clear_celebration"):
			hud.show_wave_clear_celebration()
		# Defer receipt creation by one frame so the wave-end signal burst
		# (enemy deaths, tweens, pool releases) settles before UI layout runs.
		# The receipt shows imperceptibly later but avoids the physics catch-up
		# spiral that caused min-FPS 2.0 spikes at wave boundaries (#975 #982).
		call_deferred("_show_wave_receipt", wave_num)


func _show_wave_receipt(wave_num: int) -> void:
	# Guard against a call_deferred arriving after the level has already ended
	# (e.g. wave_completed fires → call_deferred queued → all_waves_completed
	# fires in the same logic step → _dismiss_wave_receipt called → deferred
	# runs next frame adding a new receipt with no dismisser).
	if wave_manager == null or not is_instance_valid(wave_manager):
		return
	if wave_manager.all_done:
		return
	_dismiss_wave_receipt()
	var enemies_defeated: int = 0
	var towers: Array = get_tree().get_nodes_in_group("towers")
	for tower in towers:
		if "wave_kill_count" in tower:
			enemies_defeated += tower.wave_kill_count
	var raw_preview: Array = wave_manager.get_next_wave_preview() if wave_manager else []
	var next_preview: Array = []
	for entry in raw_preview:
		var eid: String = str(entry.get("enemy_id", ""))
		var cnt: int = int(entry.get("count", 1))
		var dname: String = eid.replace("_", " ").capitalize()
		if wave_manager._enemy_data_cache.has(eid):
			var edata = wave_manager._enemy_data_cache[eid]
			if edata and "display_name" in edata and edata.display_name != "":
				dname = edata.display_name
		next_preview.append({"display_name": dname, "count": cnt})
	var receipt := WaveReceipt.new()
	receipt.configure(
		wave_num,
		towers,
		CurrencyManager.wave_gold_earned,
		1,
		GameManager.lives,
		enemies_defeated,
		next_preview
	)
	_wave_receipt = receipt
	hud.add_child(receipt)


func _dismiss_wave_receipt() -> void:
	if _wave_receipt != null and is_instance_valid(_wave_receipt):
		# Immediate removal — wave is starting, no dismiss animation overlap (#934).
		_wave_receipt.dismiss(true)
	_wave_receipt = null


func _on_all_waves_completed() -> void:
	# Dismiss any visible wave receipt immediately — without this, a receipt
	# created via call_deferred in _on_wave_completed (which runs before
	# wave_started fires for the same frame) can remain on screen through the
	# victory sequence and into the next scenario (#1009).
	_dismiss_wave_receipt()
	GameManager.complete_level()
	hud.hide_tower_info()
	var stars: int = GameManager.level_stars.get(level_id, 1)
	# 0.5 s grace so dying-animation enemies finish before the victory screen
	# overlaps them (#955: WON fires with 1 enemy still visually alive).
	await get_tree().create_timer(0.5).timeout
	game_over_screen.show_victory(stars)


func _exit_tree() -> void:
	# Defensive cleanup on scene unload — ensures no receipt node lingers if
	# the scene is replaced before the normal dismiss path fires (#1009).
	_dismiss_wave_receipt()


func _on_game_over(won: bool) -> void:
	_dismiss_wave_receipt()
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
	# Selbschtskan-Schiff: remember the last tower placed so copycat
	# enemies (L8+) can be skinned with its silhouette and become
	# immune to its damage.
	if _tower and "data" in _tower and _tower.data != null:
		most_recent_tower_id = String(_tower.data.id)
		var sprite_node: Node = _tower.get_node_or_null("Sprite2D")
		if sprite_node and sprite_node is Sprite2D and (sprite_node as Sprite2D).texture:
			most_recent_tower_texture = (sprite_node as Sprite2D).texture
	_ensure_adjacency_viz()
	if _adjacency_viz:
		_adjacency_viz.refresh()
	call_deferred("_refresh_all_synergies")


func _on_tower_removed(_tower: Node2D) -> void:
	if _adjacency_viz:
		_adjacency_viz.refresh()
	call_deferred("_refresh_all_synergies")


func _refresh_all_synergies() -> void:
	for t in get_tree().get_nodes_in_group("towers"):
		if t.has_method("_refresh_synergies"):
			t._refresh_synergies()


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
			tower.on_tapped()
			hud.show_tower_info(tower)
			return

	# Tapped empty space — deselect
	hud.hide_tower_info()
