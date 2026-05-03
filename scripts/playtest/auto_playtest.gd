extends Node

## Autonomous playtester v3.2. Activated when Godot is launched with --playtest.
## Runs 6 scenarios across all 3 levels, upgrade flow, stress test, bug hunt.
## Captures regular screenshots plus dense "anim_*" frames for GIF stitching.
## Writes per-scenario metrics to summary.md.
##
## Output: user://playtest/*.png, anim_*.png (GIF source), summary.md, fps.log
## Picked up by .github/workflows/playtest.yml and passed to the vision agent.

const SHOT_DIR := "user://playtest/"
const SUMMARY_FILE := "user://playtest/summary.md"
const FPS_LOG := "user://playtest/fps.log"
const SHOT_INTERVAL := 2.5
const ANIM_INTERVAL := 0.12     # ~8 FPS for GIF
const MAX_SHOTS_PER_SCENARIO := 6
const ANIM_FRAMES := 24          # ~3s animation clip
const STRESS_ENEMY_COUNT := 80

var _active: bool = false
var _shot_count: int = 0
var _anim_count: int = 0
var _scenario_name: String = ""
var _fps_samples: Array[float] = []
var _scenario_summaries: Array[Dictionary] = []
var _start_ms: int = 0


func _ready() -> void:
	var args := OS.get_cmdline_args()
	if "--playtest" in args or "--headless-playtest" in args:
		_active = true
		_start_ms = Time.get_ticks_msec()
		print("[playtest v4] bot activated — full coverage (all 7 levels + UI + new towers)")
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
		call_deferred("_run_all")


func _process(_delta: float) -> void:
	if _active:
		_fps_samples.append(Engine.get_frames_per_second())


func _run_all() -> void:
	await get_tree().create_timer(0.5).timeout
	_snapshot("00_menu")

	# UI tour: capture the menu surfaces before any gameplay.
	await _run_ui_tour()

	# All 7 levels get a healthy run — previously only L1-L3 were covered
	# so L4-L7 regressions shipped undetected. Each level rotates its
	# placement comp to exercise different towers (including the new
	# joe/justus/seve).
	for level_id in range(1, 8):
		await _run_healthy_level(level_id)

	await _run_upgrade_flow()
	await _run_new_towers_showcase()
	await _run_stress_test()
	await _run_bug_hunt()

	_write_summary()
	print("[playtest v3] done — %d snapshots, %d anim frames in %.1fs" % [
		_shot_count, _anim_count, _elapsed()
	])
	await get_tree().create_timer(0.4).timeout
	get_tree().quit(0)


# --- Scenario 1-3: Healthy play at each level ---

func _run_healthy_level(level_id: int) -> void:
	_scenario_name = "L%d_healthy" % level_id
	_fps_samples.clear()
	var t0 := Time.get_ticks_msec()

	GameManager.current_level = level_id
	GameManager.start_level(level_id)
	get_tree().change_scene_to_file("res://scenes/game/level_%d.tscn" % level_id)
	await get_tree().create_timer(1.5).timeout
	_snapshot("%s_load" % _scenario_name)

	var game_root := get_tree().current_scene
	var placements := _placements_for_level(level_id)
	# Issue #330 fix: previous loop silently placed only 1 tower per scenario.
	# Root cause: a 0.15s await between placements let TowerPlacement state
	# interfere. New approach: re-set gold to 2000 BEFORE each placement (so
	# affordability never gates), use process_frame waits (not timers), and
	# count actual placements vs expected — log a degraded warning if <3.
	var saved_gold: int = CurrencyManager.gold
	var placed_count := 0
	print("[playtest] L%d placing %d towers" % [level_id, placements.size()])
	for entry in placements:
		var data_path := "res://resources/tower_data/%s.tres" % entry.id
		if not ResourceLoader.exists(data_path):
			print("[playtest] WARN missing tower data: %s" % data_path)
			continue
		var td = load(data_path)
		CurrencyManager.gold = 2000  # re-set per placement (defensive)
		var tower := _instantiate_tower(game_root, td, entry.pos)
		if tower == null:
			print("[playtest] WARN instantiate failed: %s @ %s" % [entry.id, entry.pos])
		else:
			placed_count += 1
		await get_tree().process_frame
		await get_tree().process_frame
	CurrencyManager.gold = saved_gold
	if placed_count < 3:
		push_warning("[playtest] L%d DEGRADED — placed only %d/%d towers" % [
			level_id, placed_count, placements.size()
		])
	print("[playtest] L%d placed %d/%d, gold=%d" % [
		level_id, placed_count, placements.size(), CurrencyManager.gold
	])

	await get_tree().create_timer(0.4).timeout
	_snapshot("%s_placed" % _scenario_name)

	var wm := game_root.get_node_or_null("WaveManager") as Node
	if wm and wm.has_method("start_next_wave"):
		wm.set("auto_start_waves", true)
		wm.set("time_between_waves", 2.0)  # speed through between-wave breaks
		wm.call("start_next_wave")

	# Time-scale boost so we actually reach WON state within reasonable
	# wall-clock. Issue #53: healthy scenarios previously timed out at
	# wave 1/10 because the 6-shot × 2.5s window = 15s only covered the
	# first wave. At 4× speed a full 10-wave level fits in ~75s.
	Engine.time_scale = 4.0

	await _capture_anim_clip("%s_wavestart" % _scenario_name)

	# Extended loop: keep sampling until WON/LOST or 60s elapsed at 4×.
	var sim_started := Time.get_ticks_msec()
	var shot_idx := 0
	while true:
		await get_tree().create_timer(SHOT_INTERVAL).timeout
		_snapshot("%s_t%02d" % [_scenario_name, shot_idx])
		shot_idx += 1
		if GameManager.current_state == GameManager.GameState.LOST \
		or GameManager.current_state == GameManager.GameState.WON:
			break
		var elapsed := float(Time.get_ticks_msec() - sim_started) / 1000.0
		# Issue #328 fix: was 24 ticks/scenario which exhausted the time budget
		# before reaching L4-L10. 12 ticks fits all 10 levels in the budget.
		if elapsed > 60.0 or shot_idx >= 12:
			break

	Engine.time_scale = 1.0
	_snapshot("%s_final" % _scenario_name)
	_record_scenario(t0)
	_cleanup_scene()
	await get_tree().create_timer(0.3).timeout


# --- UI tour: menus, level-select, options, story ---

func _run_ui_tour() -> void:
	_scenario_name = "ui_tour"
	_fps_samples.clear()
	var t0 := Time.get_ticks_msec()

	# Main menu already captured as 00_menu — walk into the other surfaces.
	var menu_scenes := [
		["level_select", "res://scenes/ui/level_select.tscn"],
		["options",      "res://scenes/ui/options_menu.tscn"],
		["story",        "res://scenes/ui/story_screen.tscn"],
	]
	for pair in menu_scenes:
		var label: String = pair[0]
		var scene_path: String = pair[1]
		if ResourceLoader.exists(scene_path):
			get_tree().change_scene_to_file(scene_path)
			await get_tree().create_timer(0.6).timeout
			_snapshot("ui_%s" % label)

	_record_scenario(t0)
	_cleanup_scene()
	await get_tree().create_timer(0.3).timeout


# --- New-tower showcase: one of each new tower placed + upgraded ---

func _run_new_towers_showcase() -> void:
	_scenario_name = "new_towers"
	_fps_samples.clear()
	var t0 := Time.get_ticks_msec()

	GameManager.current_level = 1
	GameManager.start_level(1)
	CurrencyManager.gold = 9999
	get_tree().change_scene_to_file("res://scenes/game/level_1.tscn")
	await get_tree().create_timer(1.5).timeout

	var game_root := get_tree().current_scene
	var path := game_root.get_node_or_null("EnemyPath") as Path2D if game_root else null
	var showcase_ids := ["joe", "justus", "seve"]
	var placements: Array = []
	if path and path.curve and path.curve.get_baked_length() > 100:
		placements = _sample_placements_along(path, showcase_ids)
	else:
		# spread-out fallback
		var base_pos := Vector2(400, 360)
		for i in showcase_ids.size():
			placements.append({"id": showcase_ids[i], "pos": base_pos + Vector2(i * 180, 0)})

	var placed_towers: Array = []
	for entry in placements:
		var data_path := "res://resources/tower_data/%s.tres" % entry.id
		if ResourceLoader.exists(data_path):
			var td = load(data_path)
			var t = _instantiate_tower(game_root, td, entry.pos)
			if t != null:
				placed_towers.append(t)
			await get_tree().create_timer(0.25).timeout
	_snapshot("new_towers_placed")

	# Walk each one to tier 2 path A so we see their upgraded look.
	for tower in placed_towers:
		if tower and is_instance_valid(tower) and tower.has_method("upgrade_path"):
			tower.upgrade_path("a")
			await get_tree().create_timer(0.3).timeout
			tower.upgrade_path("a")
			await get_tree().create_timer(0.3).timeout
	_snapshot("new_towers_upgraded")

	# Kick off a wave so we see them firing.
	var wm := game_root.get_node_or_null("WaveManager") as Node
	if wm and wm.has_method("start_next_wave"):
		wm.set("auto_start_waves", true)
		wm.call("start_next_wave")
	Engine.time_scale = 3.0
	for i in 5:
		await get_tree().create_timer(1.2).timeout
		_snapshot("new_towers_fight_t%d" % i)
	Engine.time_scale = 1.0
	_snapshot("new_towers_final")

	_record_scenario(t0)
	_cleanup_scene()
	await get_tree().create_timer(0.3).timeout


# --- Scenario 4: Upgrade flow (buy Lemurius, walk path A to tier 3) ---

func _run_upgrade_flow() -> void:
	_scenario_name = "upgrades"
	_fps_samples.clear()
	var t0 := Time.get_ticks_msec()

	GameManager.current_level = 1
	GameManager.start_level(1)
	CurrencyManager.gold = 5000  # Plenty for upgrades
	get_tree().change_scene_to_file("res://scenes/game/level_1.tscn")
	await get_tree().create_timer(1.5).timeout

	var game_root := get_tree().current_scene
	var td = load("res://resources/tower_data/basic.tres")
	var tower: BaseTower = _instantiate_tower(game_root, td, Vector2(640, 400))
	await get_tree().create_timer(0.5).timeout
	_snapshot("upgrades_tier_0_0")

	# Walk Path A: tiers 1 → 2 → 3
	for i in 3:
		if tower and is_instance_valid(tower):
			tower.upgrade_path("a")
			await get_tree().create_timer(0.4).timeout
			_snapshot("upgrades_tier_A%d" % (i + 1))

	# Then add path B tiers to test blend tint
	for i in 2:
		if tower and is_instance_valid(tower):
			tower.upgrade_path("b")
			await get_tree().create_timer(0.4).timeout
			_snapshot("upgrades_tier_A3_B%d" % (i + 1))

	_record_scenario(t0)
	_cleanup_scene()
	await get_tree().create_timer(0.3).timeout


# --- Scenario 5: Performance stress — spawn many enemies at once ---

func _run_stress_test() -> void:
	_scenario_name = "stress"
	_fps_samples.clear()
	var t0 := Time.get_ticks_msec()

	GameManager.current_level = 1
	GameManager.start_level(1)
	get_tree().change_scene_to_file("res://scenes/game/level_1.tscn")
	await get_tree().create_timer(1.5).timeout

	var game_root := get_tree().current_scene
	var wm := game_root.get_node_or_null("WaveManager") as Node
	var path := game_root.get_node_or_null("EnemyPath") as Path2D
	if wm and path:
		# Issue #79 fix: route stress spawn through EnemyPool.acquire so
		# enemies get the same lifecycle (process_mode, signal wiring,
		# is_dead accounting) as the real game. Previous direct-instantiate
		# path bypassed the pool and caused metric drift (80 spawned, 0
		# killed) because the pool's release path was never a participant
		# and enemies sat at progress=0 invisibly stacked.
		var enemy_data = load("res://resources/enemy_data/basic.tres")
		var curve_length: float = 0.0
		if path.curve:
			curve_length = path.curve.get_baked_length()
		for i in STRESS_ENEMY_COUNT:
			var e: Node = null
			if EnemyPool and EnemyPool.has_method("acquire"):
				e = EnemyPool.acquire(enemy_data, path)
			if e == null:
				var enemy_scene: PackedScene = load("res://scenes/enemies/base_enemy.tscn") as PackedScene
				e = enemy_scene.instantiate()
				e.data = enemy_data
				path.add_child(e)
			e.add_to_group("enemies")
			if e.has_signal("enemy_died") and not e.enemy_died.is_connected(Callable(wm, "_on_enemy_died")):
				e.connect("enemy_died", Callable(wm, "_on_enemy_died"))
			if e.has_signal("enemy_reached_end") and not e.enemy_reached_end.is_connected(Callable(wm, "_on_enemy_reached_end")):
				e.connect("enemy_reached_end", Callable(wm, "_on_enemy_reached_end"))
			# Stagger progress along the path so the 80 enemies visually
			# spread out instead of stacking at the start. v_offset is
			# overwritten by base_enemy._process every frame so isn't
			# useful for separation — progress is the real lever.
			if curve_length > 0.0:
				e.progress = fmod(float(i) * 25.0, curve_length - 40.0)

	# Force a frame flush so the renderer actually draws 80 sprites
	# BEFORE we screenshot (was snapping before the tree settled).
	await get_tree().process_frame
	await get_tree().process_frame
	_snapshot("stress_spawned")

	# Let them march for a bit, sampling FPS at realistic intervals
	for i in 6:
		await get_tree().create_timer(1.0).timeout
		_snapshot("stress_t%d" % i)

	_record_scenario(t0)
	_cleanup_scene()
	await get_tree().create_timer(0.3).timeout


# --- Scenario 6: Bug hunt — rapid tap in tower placement mode ---

func _run_bug_hunt() -> void:
	_scenario_name = "bughunt"
	_fps_samples.clear()
	var t0 := Time.get_ticks_msec()

	GameManager.current_level = 1
	GameManager.start_level(1)
	get_tree().change_scene_to_file("res://scenes/game/level_1.tscn")
	await get_tree().create_timer(1.5).timeout

	var game_root := get_tree().current_scene
	var placement := game_root.get_node_or_null("TowerPlacement")

	# Rapid-tap invalid placements — right on the path (should trigger toast)
	if placement and placement.has_method("start_placement"):
		var td = load("res://resources/tower_data/basic.tres")
		placement.start_placement(td)
		await get_tree().create_timer(0.3).timeout
		_snapshot("bughunt_placement_mode")
		# Synthesize 5 rapid clicks at path-center points
		var bad_positions := [
			Vector2(300, 300), Vector2(400, 320), Vector2(500, 340),
			Vector2(600, 320), Vector2(700, 300),
		]
		for p in bad_positions:
			if placement.has_method("_try_place"):
				placement.call("_try_place", p)
			await get_tree().create_timer(0.15).timeout
		_snapshot("bughunt_post_rapid_tap")

	# Also: cancel placement, should return cleanly
	if placement and placement.has_method("cancel_placement"):
		placement.cancel_placement()
		await get_tree().create_timer(0.2).timeout
	_snapshot("bughunt_after_cancel")

	_record_scenario(t0)
	_cleanup_scene()
	await get_tree().create_timer(0.3).timeout


# --- Helpers ---

func _placements_for_level(level_id: int) -> Array:
	# Auto-detect placements by sampling the level's Path2D curve.
	# We pick N points along the path then offset perpendicular by ~80px
	# to land beside the path (not on it). Falls back to hardcoded if
	# path can't be found.
	var game_root := get_tree().current_scene
	var path := game_root.get_node_or_null("EnemyPath") as Path2D if game_root else null
	if path and path.curve and path.curve.get_baked_length() > 100:
		var ids: Array
		# Cheap-first ordering so that if starting-gold runs out, we still
		# get a decent early comp. Playtest-feedback #74: L3 was leaking
		# wave-1 because the expensive splash/slow placements came first
		# and consumed the budget before basic/sniper could go down.
		match level_id:
			1: ids = ["basic", "basic", "sniper", "splash"]
			2: ids = ["basic", "sniper", "slow", "joe"]
			3: ids = ["basic", "sniper", "cordula", "justus", "splash"]
			4: ids = ["basic", "sniper", "slow", "seve", "splash", "joe"]
			5: ids = ["justus", "sniper", "cordula", "seve", "splash"]
			6: ids = ["joe", "slow", "basic", "justus", "cordula", "sniper"]
			7: ids = ["justus", "cordula", "seve", "splash", "joe", "slow", "sniper"]
			_: ids = ["basic", "sniper", "splash"]
		return _sample_placements_along(path, ids)
	# Fallback (path missing or degenerate)
	push_warning("[playtest] no path found for level %d — using hardcoded fallback" % level_id)
	return _hardcoded_placements(level_id)


func _sample_placements_along(path: Path2D, ids: Array) -> Array:
	var curve := path.curve
	var length := curve.get_baked_length()
	var placements: Array = []
	for i in ids.size():
		# Sample at evenly-spaced fractions of the path length, skipping
		# the very ends (0 and 1) which are spawn/exit areas.
		var t := float(i + 1) / float(ids.size() + 1)
		var dist := length * t
		var on_path: Vector2 = path.to_global(curve.sample_baked(dist))
		# Perpendicular offset: alternate sides for spread, 90px out
		var ahead: Vector2 = path.to_global(curve.sample_baked(min(dist + 10.0, length)))
		var tangent: Vector2 = (ahead - on_path).normalized() if (ahead - on_path).length() > 0.1 else Vector2(1, 0)
		var perp: Vector2 = Vector2(-tangent.y, tangent.x)
		var sign_alt: float = 1.0 if (i % 2 == 0) else -1.0
		var off: Vector2 = on_path + perp * 90.0 * sign_alt
		# Clamp into screen (1280x720 with margins for tower size)
		off.x = clampf(off.x, 80.0, 1200.0)
		off.y = clampf(off.y, 80.0, 640.0)
		placements.append({ "id": ids[i], "pos": off })
	return placements


func _hardcoded_placements(level_id: int) -> Array:
	match level_id:
		1: return [
			{ "id": "basic",   "pos": Vector2(320, 430) },
			{ "id": "basic",   "pos": Vector2(620, 260) },
			{ "id": "sniper",  "pos": Vector2(900, 430) },
			{ "id": "splash",  "pos": Vector2(460, 520) },
		]
		2: return [
			{ "id": "basic",   "pos": Vector2(380, 420) },
			{ "id": "slow",    "pos": Vector2(620, 300) },
			{ "id": "sniper",  "pos": Vector2(880, 420) },
			{ "id": "splash",  "pos": Vector2(520, 520) },
		]
		3: return [
			{ "id": "basic",   "pos": Vector2(340, 440) },
			{ "id": "cordula", "pos": Vector2(580, 280) },
			{ "id": "sniper",  "pos": Vector2(880, 440) },
			{ "id": "splash",  "pos": Vector2(500, 520) },
			{ "id": "slow",    "pos": Vector2(740, 380) },
		]
		_: return []


func _instantiate_tower(parent: Node, tower_data, pos: Vector2) -> BaseTower:
	var tower_scene: PackedScene = load("res://scenes/towers/base_tower.tscn") as PackedScene
	if tower_scene == null:
		return null
	var tower: BaseTower = tower_scene.instantiate()
	tower.data = tower_data
	tower.is_placed = true
	tower.global_position = pos
	parent.add_child(tower)
	CurrencyManager.spend_gold(tower_data.buy_cost)
	return tower


func _capture_anim_clip(tag: String) -> void:
	for i in ANIM_FRAMES:
		var img: Image = get_viewport().get_texture().get_image()
		if img:
			var filename := "%sanim_%s_%03d.png" % [SHOT_DIR, tag, i]
			img.save_png(filename)
			_anim_count += 1
		await get_tree().create_timer(ANIM_INTERVAL).timeout


func _snapshot(tag: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		return
	var filename := "%sshot_%03d_%s.png" % [SHOT_DIR, _shot_count, tag]
	var err := img.save_png(filename)
	if err != OK:
		print("[playtest] screenshot failed: %s (err=%d)" % [filename, err])
	else:
		print("[playtest] %s" % filename)
	_shot_count += 1


func _cleanup_scene() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	for t in get_tree().get_nodes_in_group("towers"):
		t.queue_free()
	GameManager.set_state(GameManager.GameState.MENU)


func _record_scenario(start_ms: int) -> void:
	var avg_fps: float = 0.0
	if _fps_samples.size() > 0:
		var sum := 0.0
		for v in _fps_samples:
			sum += v
		avg_fps = sum / _fps_samples.size()
	var min_fps: float = 9999.0
	for v in _fps_samples:
		if v > 0.0 and v < min_fps:
			min_fps = v
	_scenario_summaries.append({
		"name": _scenario_name,
		"elapsed_ms": Time.get_ticks_msec() - start_ms,
		"avg_fps": avg_fps,
		"min_fps": min_fps if min_fps < 9999.0 else 0.0,
		"final_lives": GameManager.lives,
		"final_gold": CurrencyManager.gold,
		"final_state": _state_name(GameManager.current_state),
		"enemies_remaining": get_tree().get_nodes_in_group("enemies").size(),
	})
	# Issue #328 fix: write summary INCREMENTALLY after each scenario so
	# partial runs (timeout, crash, OOM) still produce metrics. Previous
	# code only wrote at the very end of _run_all() which silently dropped
	# everything if the bot ran out of wall-clock time.
	_write_summary()
	_append_fps_log(avg_fps, min_fps)


func _write_summary() -> void:
	var f := FileAccess.open(SUMMARY_FILE, FileAccess.WRITE)
	if f == null:
		return
	f.store_string("# Playtest v3 Summary\n\n")
	f.store_string("Timestamp: %s\n" % Time.get_datetime_string_from_system(true))
	f.store_string("Total duration: %.1fs\n\n" % _elapsed())
	f.store_string("| Scenario | Duration (s) | Avg FPS | Min FPS | Final Lives | State | Enemies Remaining |\n")
	f.store_string("|---|---|---|---|---|---|---|\n")
	for s in _scenario_summaries:
		f.store_string("| %s | %.1f | %.1f | %.1f | %d | %s | %d |\n" % [
			s.name, float(s.elapsed_ms) / 1000.0,
			s.avg_fps, s.min_fps,
			s.final_lives, s.final_state, s.enemies_remaining,
		])
	f.store_string("\n## Interpretation hints\n\n")
	f.store_string("- **L1/L2/L3_healthy**: should end WON, lives > 0. LOST here means the scenario tower placements no longer counter the waves (rebalance or retune placements).\n")
	f.store_string("- **upgrades**: screenshots walk Lemurius from tier-0 through path-A then path-B. Tints should shift noticeably between states — if they look identical, the _apply_path_tint blend is broken.\n")
	f.store_string("- **stress**: 80 simultaneous enemies. Avg FPS < 30 = performance regression; projectile / pathfollow scaling needs attention (object pooling overdue).\n")
	f.store_string("- **bughunt**: rapid invalid placements. Expect placement toasts firing and no crashes. shot `bughunt_after_cancel` should show the normal HUD, no stuck ghost tower.\n")
	f.store_string("- **anim_*** frames are GIF source — ffmpeg stitches them in the workflow.\n")
	f.close()
	print("[playtest v3] summary → %s" % SUMMARY_FILE)


func _append_fps_log(avg_fps: float, min_fps: float) -> void:
	# Append a single line per scenario so fps.log accumulates as we go.
	# Issue #328: previously fps.log was never written at all.
	var f := FileAccess.open(FPS_LOG, FileAccess.READ_WRITE)
	if f == null:
		f = FileAccess.open(FPS_LOG, FileAccess.WRITE)
		if f == null:
			return
		f.store_string("# scenario\tavg_fps\tmin_fps\telapsed_s\n")
	else:
		f.seek_end()
	f.store_string("%s\t%.1f\t%.1f\t%.1f\n" % [
		_scenario_name, avg_fps, min_fps, _elapsed()
	])
	f.close()


func _elapsed() -> float:
	return float(Time.get_ticks_msec() - _start_ms) / 1000.0


func _state_name(s: int) -> String:
	match s:
		GameManager.GameState.MENU: return "MENU"
		GameManager.GameState.PLAYING: return "PLAYING"
		GameManager.GameState.PAUSED: return "PAUSED"
		GameManager.GameState.WON: return "WON"
		GameManager.GameState.LOST: return "LOST"
		_: return "?"
