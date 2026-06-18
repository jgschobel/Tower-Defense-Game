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
# GPU readback flag: get_viewport().get_texture().get_image() stalls the main
# thread 100–300ms. The following frame reports ~2 fps from Engine.get_frames_per_second()
# even though gameplay was smooth. Setting this true before any readback causes
# _process to skip the one poisoned sample, fixing the false min-fps spike on L1
# (issues #975 #982 #989 — L1 uniquely runs _capture_anim_clip with 24 readbacks).
var _in_readback: bool = false


func _ready() -> void:
	var args := OS.get_cmdline_args()
	if "--playtest" in args or "--headless-playtest" in args:
		_active = true
		_start_ms = Time.get_ticks_msec()
		print("[playtest v4] bot activated — full coverage (all 7 levels + UI + new towers)")
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
		call_deferred("_run_all")


func _process(_delta: float) -> void:
	if _active and not _in_readback:
		_fps_samples.append(Engine.get_frames_per_second())
	_in_readback = false  # clear flag — set true by _snapshot/_capture_anim_clip for one frame


func _run_all() -> void:
	await get_tree().create_timer(0.5).timeout
	_snapshot("00_menu")

	# UI tour: capture the menu surfaces before any gameplay.
	await _run_ui_tour()

	# Priority scenarios run BEFORE healthy loops so they always complete
	# even if the CI runner runs tight on time. Total budget: ~30s.
	await _run_upgrade_flow()
	await _run_new_towers_showcase()
	await _run_stress_test()
	await _run_bug_hunt()

	# Healthy runs for L1-L3. Each caps at 20s real / 8 shots (see
	# _run_healthy_level). L4-L7 pushed past CI timeout (issue #499);
	# re-enable once per-scenario budget is measured and reduced.
	for level_id in range(1, 4):
		await _run_healthy_level(level_id)

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
			# Tier-2 path-A upgrade: at T1-A basic DPS = 33 (23 dmg x 1.45/s), just
			# barely above the 100 HP kill threshold. At 8x time_scale the ~110 dmg/pass
			# margin is too thin -- physics variance lets enemies slip through, giving
			# kills=0 (issues #760, #761). T2-A raises DPS to ~55 (29 dmg x 1.9/s),
			# a 2x buffer that kills basic/fast reliably in headless CI.
			CurrencyManager.gold = 2000
			if tower.has_method("upgrade_path"):
				tower.upgrade_path("a")  # T0 -> T1-A
				CurrencyManager.gold = 2000
				tower.upgrade_path("a")  # T1-A -> T2-A
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

	# Time-scale boost so we see active gameplay within the CI budget.
	# All levels at 12×: 10 ticks × 2.0s real = 240s game time, enough for
	# 10 dense waves with healers and boss deaths.
	# max_phys = 12 (matches time_scale): at 60fps that's exactly 12 physics
	# ticks/frame = 12×60=720hz — physically accurate. Previous value of 48
	# allowed catch-up spirals: if a frame stalled (wave boundary UI burst),
	# Godot queued up to 48 physics steps, making the NEXT frame even slower
	# and causing the 2.0 FPS min-spike seen in issues #975 #982. Capping at
	# 12 means a stalled frame simply loses physics accuracy (time slows), not
	# CPU throughput — a safe trade for a CI metric run.
	var _ts := 12.0
	var _max_phys := 12
	Engine.max_physics_steps_per_frame = _max_phys
	Engine.time_scale = _ts

	# Only capture wavestart anim clip for L1. L2/L3 skip it to save ~24 GPU
	# readbacks per level — each get_viewport().get_texture().get_image() call
	# can take 100-300ms on a slow CI runner, and 48 saved readbacks reclaim
	# ~10-15s of the 120s global godot timeout, preventing L3 from being killed
	# mid-run before _record_scenario fires (#871 root cause).
	if level_id == 1:
		await _capture_anim_clip("%s_wavestart" % _scenario_name)

	# Extended loop: keep sampling until WON/LOST or budget expires.
	# 12× across all levels: 10 ticks × 2.0s = 240s game time — enough for any
	# 10-wave level. WON/LOST early-exit keeps real time short (~10-15s typical).
	# 20s ceiling: 3 levels × ≤20s = ≤60s, plus ~36s priority scenarios,
	# leaving ~24s buffer inside the 120s Godot CI timeout for L3 to land.
	var sim_started := Time.get_ticks_msec()
	var shot_idx := 0
	var _diag_done := false
	while true:
		# ignore_time_scale=true: each 2.0s wait is real-clock seconds,
		# so the game runs 2.0 × time_scale game-seconds between screenshots.
		await get_tree().create_timer(2.0, true, false, true).timeout
		_snapshot("%s_t%02d" % [_scenario_name, shot_idx])
		# After first combat tick: emit a mid-combat diagnostic so kills=0
		# root cause is visible in CI logs even before the scenario ends.
		if not _diag_done and shot_idx == 0:
			_diag_done = true
			var e_count := get_tree().get_nodes_in_group("enemies").size()
			var t_count := get_tree().get_nodes_in_group("towers").size()
			print("[playtest] MID-COMBAT %s t=1 enemies=%d towers=%d kills=%d" % [
				_scenario_name, e_count, t_count, GameManager.level_kills
			])
			for t in get_tree().get_nodes_in_group("towers"):
				var tid: String = t.data.id if "data" in t and t.data else "?"
				var t_atk: int = t._diag_attack_count if "_diag_attack_count" in t else -1
				var t_det: int = t._diag_detect_count if "_diag_detect_count" in t else -1
				print("[playtest]   tower=%s attacks=%d detects=%d" % [tid, t_atk, t_det])
			for ei in get_tree().get_nodes_in_group("enemies"):
				var eid: String = ei.data.id if "data" in ei and ei.data else "?"
				var epos: Vector2 = ei.global_position if ei is Node2D else Vector2.ZERO
				print("[playtest]   enemy=%s pos=(%.0f,%.0f) is_dead=%s" % [
					eid, epos.x, epos.y,
					str(ei.is_dead if "is_dead" in ei else "?")
				])
		shot_idx += 1
		if GameManager.current_state == GameManager.GameState.LOST \
		or GameManager.current_state == GameManager.GameState.WON:
			break
		var elapsed := float(Time.get_ticks_msec() - sim_started) / 1000.0
		if elapsed > 20.0 or shot_idx >= 10:
			break

	# Grace-period: if the last wave has been started but stragglers are still
	# moving on the path, wait up to 3 extra real-clock ticks before giving up.
	# Covers two cases: (a) all_done=true but WON not yet propagated, and
	# (b) last wave sent but enemies still alive (common on L1 wave 10, #945).
	var wm_node := get_tree().get_first_node_in_group("wave_manager")
	var _wm_last_wave_started: bool = wm_node != null and \
		wm_node.get("current_wave") >= wm_node.get("total_waves") and \
		wm_node.get("total_waves") > 0
	if wm_node and (wm_node.get("all_done") == true or _wm_last_wave_started) \
	and GameManager.current_state == GameManager.GameState.PLAYING:
		for _grace in 3:
			await get_tree().create_timer(2.0, true, false, true).timeout
			_snapshot("%s_grace" % _scenario_name)
			if GameManager.current_state != GameManager.GameState.PLAYING:
				break

	Engine.time_scale = 1.0
	Engine.max_physics_steps_per_frame = 8
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
	# auto_start_waves stays false (default) — showcase only needs wave 1's
	# 6 enemies so the kill count matches cleanly. Setting it true caused
	# wave 2 to auto-start and 1 enemy from wave 2 would still be alive when
	# the snapshot fired, giving enemies_remaining=1 at scenario end (#874).
	var wm := game_root.get_node_or_null("WaveManager") as Node
	if wm and wm.has_method("start_next_wave"):
		wm.call("start_next_wave")
	Engine.time_scale = 3.0
	for i in 5:
		# ignore_time_scale=true: each tick is 1.2 REAL seconds regardless of
		# time_scale. Without it at 3× each tick fires after 0.4s real (1.2/3),
		# giving only 2s real / 6s game time — not enough to see kills.
		await get_tree().create_timer(1.2, true, false, true).timeout
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
			# 0.7s > 0.55s tween duration so the modulate restore completes
			# before screenshot (issue #620 — tints imperceptible at A1/A2).
			await get_tree().create_timer(0.7).timeout
			_snapshot("upgrades_tier_A%d" % (i + 1))

	# Then add path B tiers to test blend tint
	for i in 2:
		if tower and is_instance_valid(tower):
			tower.upgrade_path("b")
			await get_tree().create_timer(0.7).timeout
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

	# Place 5 towers spread across L1 path bends so the 80-enemy pile
	# actually stresses attack/projectile systems with ~65% kill coverage
	# (#903 — 3 towers only hit 28/80). Positions match L1 hardcoded set.
	var _stress_gold_saved := CurrencyManager.gold
	for _stress_entry in [
		{"id": "basic",  "pos": Vector2(320, 430)},
		{"id": "basic",  "pos": Vector2(620, 260)},
		{"id": "sniper", "pos": Vector2(900, 430)},
		{"id": "splash", "pos": Vector2(460, 520)},
		{"id": "slow",   "pos": Vector2(750, 380)},
	]:
		var _std = load("res://resources/tower_data/%s.tres" % _stress_entry.id)
		if _std:
			CurrencyManager.gold = 2000
			var _st := _instantiate_tower(game_root, _std, _stress_entry.pos)
			if _st and _st.has_method("upgrade_path"):
				CurrencyManager.gold = 2000
				_st.upgrade_path("a")
				CurrencyManager.gold = 2000
				_st.upgrade_path("a")
		await get_tree().process_frame
	CurrencyManager.gold = _stress_gold_saved

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

	# Register manually-spawned enemies with the WaveManager so the HUD shows
	# "Wälle 1/1" instead of "Bereit" and _decrement_enemies() fires correctly.
	# Without this the stress FPS benchmark reflects an idle pre-wave state
	# rather than active combat (issue #727).
	if wm:
		wm.current_wave = 1
		wm.wave_in_progress = true
		wm.is_spawning = false
		wm.enemies_alive = STRESS_ENEMY_COUNT
		if wm.has_signal("wave_started"):
			wm.wave_started.emit(1, 1)
		if wm.has_signal("enemies_remaining_changed"):
			wm.enemies_remaining_changed.emit(STRESS_ENEMY_COUNT)

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
		# Synthesize 5 rapid clicks at path-center points.
		# These are actual L1 bezier control points (points 1,3,5,7,9 of curve_1
		# in level_1.tscn), all within viewport bounds — guaranteed to be within
		# min_path_distance (45px) of the sampled curve and thus rejected with
		# "Z'nöch am Wäg!". The previous positions (300,300)+(400,320)+…+(700,300)
		# lay in the mid-screen region the L1 serpentine path never traverses,
		# so they were ACCEPTED rather than rejected (#870).
		var bad_positions := [
			Vector2(120, 120),  # point_1: (120,120) — path peak NW
			Vector2(420, 100),  # point_3: (420,100) — path peak north-center
			Vector2(700, 100),  # point_5: (700,100) — path peak north-east
			Vector2(960, 120),  # point_7: (960,120) — path peak east
			Vector2(1200, 200), # point_9: (1200,200) — path descending to exit
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
	# Hardcoded positions are manually verified to be within tower attack
	# range for each level's specific serpentine path — prefer them over
	# auto-sampling which can land towers outside range (issue #686).
	var hardcoded := _hardcoded_placements(level_id)
	if not hardcoded.is_empty():
		return hardcoded
	# Fall back to path-sampling for levels without hardcoded positions.
	var game_root := get_tree().current_scene
	var path := game_root.get_node_or_null("EnemyPath") as Path2D if game_root else null
	if path and path.curve and path.curve.get_baked_length() > 100:
		# Generic fallback for levels 8+ (no hardcoded entries yet)
		var ids: Array = ["basic", "sniper", "splash"]
		return _sample_placements_along(path, ids)
	push_warning("[playtest] no path found for level %d — using empty fallback" % level_id)
	return []


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
			{ "id": "slow",    "pos": Vector2(750, 380) },
		]
		2: return [
			{ "id": "basic",   "pos": Vector2(380, 420) },
			{ "id": "slow",    "pos": Vector2(620, 300) },
			{ "id": "sniper",  "pos": Vector2(880, 420) },
			{ "id": "splash",  "pos": Vector2(520, 520) },
			{ "id": "justus",  "pos": Vector2(920, 250) },
		]
		3: return [
			{ "id": "basic",   "pos": Vector2(340, 440) },
			{ "id": "cordula", "pos": Vector2(580, 280) },
			{ "id": "sniper",  "pos": Vector2(880, 440) },
			{ "id": "splash",  "pos": Vector2(500, 520) },
			{ "id": "slow",    "pos": Vector2(740, 380) },
			# 6th tower covers the right-side serpentine (950,150)→(1050,550)→(1180,200)
			# that the existing 5 towers don't fully reach; prevents life leaks on
			# wave 7's 20-basic spam + wave 8's healer+flying+fast combo (#872).
			{ "id": "sniper",  "pos": Vector2(1050, 350) },
			# 7th tower: exit-catcher for the 3 basic children the wave-10 boss spawns
			# on death (boss.tres: spawns_on_death="basic", spawn_count=3). These
			# children pop at boss death position and continue toward exit (1180,200).
			# A slow tower here buys the sniper at (1050,350) time to pick them off (#890).
			{ "id": "slow",    "pos": Vector2(1140, 400) },
		]
		4: return [
			{ "id": "basic",   "pos": Vector2(200, 300) },
			{ "id": "sniper",  "pos": Vector2(480, 420) },
			{ "id": "slow",    "pos": Vector2(640, 240) },
			{ "id": "seve",    "pos": Vector2(840, 460) },
			{ "id": "splash",  "pos": Vector2(1060, 500) },
			{ "id": "joe",     "pos": Vector2(1180, 380) },
		]
		5: return [
			{ "id": "justus",  "pos": Vector2(300, 340) },
			{ "id": "sniper",  "pos": Vector2(440, 380) },
			{ "id": "cordula", "pos": Vector2(680, 500) },
			{ "id": "seve",    "pos": Vector2(820, 430) },
			{ "id": "splash",  "pos": Vector2(1000, 480) },
		]
		6: return [
			{ "id": "joe",     "pos": Vector2(180, 240) },
			{ "id": "slow",    "pos": Vector2(360, 500) },
			{ "id": "basic",   "pos": Vector2(540, 340) },
			{ "id": "justus",  "pos": Vector2(700, 180) },
			{ "id": "cordula", "pos": Vector2(820, 400) },
			{ "id": "sniper",  "pos": Vector2(1000, 560) },
		]
		7: return [
			{ "id": "justus",  "pos": Vector2(300, 200) },
			{ "id": "cordula", "pos": Vector2(420, 300) },
			{ "id": "seve",    "pos": Vector2(560, 520) },
			{ "id": "splash",  "pos": Vector2(720, 500) },
			{ "id": "joe",     "pos": Vector2(780, 220) },
			{ "id": "slow",    "pos": Vector2(940, 460) },
			{ "id": "sniper",  "pos": Vector2(1060, 340) },
		]
		_: return []


func _instantiate_tower(parent: Node, tower_data: Resource, pos: Vector2) -> BaseTower:
	var tower_scene: PackedScene = load("res://scenes/towers/base_tower.tscn") as PackedScene
	if tower_scene == null:
		return null
	var tower: BaseTower = tower_scene.instantiate()
	tower.data = tower_data
	tower.is_placed = true
	tower.global_position = pos
	parent.add_child(tower)
	tower.add_to_group("towers")
	CurrencyManager.spend_gold(tower_data.buy_cost)
	return tower


func _capture_anim_clip(tag: String) -> void:
	for i in ANIM_FRAMES:
		_in_readback = true  # suppress the post-readback slow-frame FPS sample
		var img: Image = get_viewport().get_texture().get_image()
		if img:
			var filename := "%sanim_%s_%03d.png" % [SHOT_DIR, tag, i]
			img.save_png(filename)
			_anim_count += 1
		await get_tree().create_timer(ANIM_INTERVAL).timeout


func _snapshot(tag: String) -> void:
	_in_readback = true  # suppress the post-readback slow-frame FPS sample
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
	# Cancel any active placement ghost — ghost is NOT in the "towers" group
	# so the loop below misses it, leaving a stale sprite on screen (#941).
	var scene_root := get_tree().current_scene
	if scene_root:
		var placement := scene_root.get_node_or_null("TowerPlacement")
		if placement and placement.has_method("cancel_placement") and placement.get("is_placing"):
			placement.cancel_placement()
	# Release enemies via pool so pool slots are reclaimed for the next
	# scenario (queue_free bypasses release, depleting EnemyPool after stress).
	# Mark is_dead=true before release so that if a parked enemy stays in the
	# "enemies" group (edge case), base_tower distance scan skips it.
	for e in get_tree().get_nodes_in_group("enemies"):
		if "is_dead" in e:
			e.is_dead = true
		if EnemyPool and EnemyPool.has_method("release"):
			EnemyPool.release(e)
		elif is_instance_valid(e):
			e.queue_free()
	for t in get_tree().get_nodes_in_group("towers"):
		if is_instance_valid(t):
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
	var enemy_count: int = get_tree().get_nodes_in_group("enemies").size()
	var tower_count: int = get_tree().get_nodes_in_group("towers").size()
	# Secondary kill counter: sum per-tower kill_count to cross-check GameManager.level_kills.
	# If tower_kills > 0 but level_kills = 0, the kill event fires but record_kill() is broken.
	# If both = 0, towers genuinely aren't landing killing blows.
	var tower_kills: int = 0
	for t in get_tree().get_nodes_in_group("towers"):
		if "kill_count" in t:
			tower_kills += t.kill_count
	_scenario_summaries.append({
		"name": _scenario_name,
		"elapsed_ms": Time.get_ticks_msec() - start_ms,
		"avg_fps": avg_fps,
		"min_fps": min_fps if min_fps < 9999.0 else 0.0,
		"final_lives": GameManager.lives,
		"final_gold": CurrencyManager.gold,
		"final_state": _state_name(GameManager.current_state),
		"enemies_remaining": enemy_count,
		"level_kills": GameManager.level_kills,
		"tower_kills": tower_kills,
	})
	print("[playtest] %s — kills=%d tower_kills=%d lives=%d state=%s enemies=%d towers=%d fps=%.0f" % [
		_scenario_name, GameManager.level_kills, tower_kills, GameManager.lives,
		_state_name(GameManager.current_state), enemy_count, tower_count, avg_fps,
	])
	if GameManager.level_kills == 0 and tower_count > 0 and enemy_count > 0:
		print("[playtest] WARN kills=0 with %d towers + %d enemies still alive — towers may be off-path or physics missed" % [tower_count, enemy_count])
	elif GameManager.level_kills == 0 and tower_count > 0 and GameManager.current_state == GameManager.GameState.LOST:
		print("[playtest] WARN kills=0 but LOST — all enemies escaped without dying, DPS insufficient for wave density")
	# Diagnostic dump: print per-tower attack/detect counts to trace kills=0 root cause.
	# Also stored in scenario dict so _write_summary() can include it in summary.md
	# where the Claude analysis agent can read it (stdout-only data was invisible, #825).
	# Guard: skip if no enemies were ever spawned (e.g. upgrades scenario) — kills=0
	# in that case is expected and emitting a diagnostic is a false-positive (#897).
	if GameManager.level_kills == 0 and tower_count > 0 and enemy_count > 0:
		print("[playtest] DIAG tower breakdown:")
		var diag_rows: Array = []
		for t in get_tree().get_nodes_in_group("towers"):
			var tid: String = t.data.id if "data" in t and t.data else "?"
			var tpos: Vector2 = t.global_position if t is Node2D else Vector2.ZERO
			var t_range: float = t.effective_range if "effective_range" in t else -1.0
			var t_spd: float = t.effective_speed if "effective_speed" in t else -1.0
			var t_atk: int = t._diag_attack_count if "_diag_attack_count" in t else -1
			var t_det: int = t._diag_detect_count if "_diag_detect_count" in t else -1
			var t_kc: int = t.kill_count if "kill_count" in t else -1
			var t_dmg: float = t.effective_damage if "effective_damage" in t else -1.0
			print("[playtest]   tower=%s pos=(%.0f,%.0f) range=%.0f spd=%.2f dmg=%.1f attacks=%d detects=%d kills=%d" % [
				tid, tpos.x, tpos.y, t_range, t_spd, t_dmg, t_atk, t_det, t_kc
			])
			diag_rows.append({
				"id": tid, "pos": tpos, "range": t_range, "speed": t_spd,
				"damage": t_dmg, "attacks": t_atk, "detects": t_det, "kills": t_kc,
			})
		# Back-patch the last scenario summary with the collected diagnostic rows
		if not _scenario_summaries.is_empty():
			_scenario_summaries[-1]["tower_diag"] = diag_rows
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
	f.store_string("| Scenario | Duration (s) | Avg FPS | Min FPS | Final Lives | Kills (GM) | Kills (towers) | State | Enemies Remaining |\n")
	f.store_string("|---|---|---|---|---|---|---|---|---|\n")
	for s in _scenario_summaries:
		f.store_string("| %s | %.1f | %.1f | %.1f | %d | %d | %d | %s | %d |\n" % [
			s.name, float(s.elapsed_ms) / 1000.0,
			s.avg_fps, s.min_fps,
			s.final_lives, s.get("level_kills", 0), s.get("tower_kills", 0), s.final_state, s.enemies_remaining,
		])
	f.store_string("\n## Interpretation hints\n\n")
	f.store_string("- **L1/L2/L3_healthy**: should end WON, lives > 0. LOST here means the scenario tower placements no longer counter the waves (rebalance or retune placements).\n")
	f.store_string("- **upgrades**: screenshots walk Lemurius from tier-0 through path-A then path-B. Tints should shift noticeably between states — if they look identical, the _apply_path_tint blend is broken.\n")
	f.store_string("- **stress**: 80 simultaneous enemies. Avg FPS < 30 = performance regression; projectile / pathfollow scaling needs attention (object pooling overdue).\n")
	f.store_string("- **bughunt**: rapid invalid placements. Expect placement toasts firing and no crashes. shot `bughunt_after_cancel` should show the normal HUD, no stuck ghost tower.\n")
	f.store_string("- **anim_*** frames are GIF source — ffmpeg stitches them in the workflow.\n")
	# Per-tower kill-chain diagnostic — only emitted for scenarios where kills=0.
	# This data lives in summary.md so the Claude analysis agent can diagnose
	# whether the issue is detection (detects=0), targeting (attacks=0), or
	# damage delivery (attacks>0 but kills=0). Previously lived only in stdout.
	var any_diag := false
	for s in _scenario_summaries:
		if s.has("tower_diag") and not (s["tower_diag"] as Array).is_empty():
			any_diag = true
			break
	if any_diag:
		f.store_string("\n## Kill-chain diagnostic (kills=0 scenarios)\n\n")
		f.store_string("| Scenario | Tower | Pos | Range | Speed | Damage | Detects | Attacks | Kills |\n")
		f.store_string("|---|---|---|---|---|---|---|---|---|\n")
		for s in _scenario_summaries:
			if not s.has("tower_diag"):
				continue
			for row in (s["tower_diag"] as Array):
				var r: Dictionary = row
				f.store_string("| %s | %s | (%.0f,%.0f) | %.0f | %.2f | %.1f | %d | %d | %d |\n" % [
					s.name, r.get("id", "?"),
					r.get("pos", Vector2.ZERO).x, r.get("pos", Vector2.ZERO).y,
					r.get("range", -1.0), r.get("speed", -1.0), r.get("damage", -1.0),
					r.get("detects", -1), r.get("attacks", -1), r.get("kills", -1),
				])
		f.store_string("\n**Interpretation**: detects=0 → tower never saw enemies (range/path mismatch). ")
		f.store_string("attacks=0 → enemies detected but target selection failed. ")
		f.store_string("attacks>0,kills=0 → projectiles fired but did not deal lethal damage (check damage vs enemy HP, pool release race).\n")
	f.store_string("\n## Headless CI FPS note\n\n")
	f.store_string("This playtest runs headlessly on a GitHub Actions runner without a GPU.\n")
	f.store_string("Headless Godot FPS is typically **10–15 FPS** even on fast code — this is\n")
	f.store_string("normal and NOT a performance regression. The 30 FPS threshold applies only\n")
	f.store_string("to the **stress** scenario on a real device. Do NOT file a P0 perf issue\n")
	f.store_string("based on headless healthy-scenario FPS readings alone.\n")
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
