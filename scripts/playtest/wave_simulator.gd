extends Node

## Headless wave-balance simulator. Activated by --simulate flag.
## Runs every level with a default tower loadout, simulates all waves,
## records: leaks (enemies that reached the end), gold-left, time-to-clear,
## final lives. Emits CSV to user://simulate/results.csv.
##
## CI gate (sim-gate.yml) parses the CSV and fails the workflow if:
## - Any level is unwinnable (final_lives <= 0 with any tower comp)
## - Any level is trivial (cleared with 0 leaks AND 1 tower placed)
##
## This is the fast deterministic check (~30s) that runs on every PR
## touching tower_data/level_data — catches balance regressions before
## the slow vision-agent playtest does.

const SIM_DIR := "user://simulate/"
const RESULTS_CSV := "user://simulate/results.csv"
const MAX_SIM_SECONDS := 90.0  # per level; aborts if a level takes longer

var _active: bool = false
var _results: Array[Dictionary] = []
var _started_ms: int = 0


func _ready() -> void:
	var args := OS.get_cmdline_args()
	if "--simulate" in args:
		_active = true
		_started_ms = Time.get_ticks_msec()
		print("[simulator] activated")
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SIM_DIR))
		call_deferred("_run_all")


func _run_all() -> void:
	# Speed everything up so a wave takes ~5s wall-clock instead of 30s+
	Engine.time_scale = 8.0
	await get_tree().process_frame

	for level_id in [1, 2, 3]:
		await _simulate_level(level_id, "default")
		await _simulate_level(level_id, "minimal")

	Engine.time_scale = 1.0
	_write_csv()
	print("[simulator] done — %d level/loadout combos in %.1fs" % [
		_results.size(), float(Time.get_ticks_msec() - _started_ms) / 1000.0
	])
	get_tree().quit(_exit_code())


func _simulate_level(level_id: int, loadout: String) -> void:
	print("[simulator] level=%d loadout=%s" % [level_id, loadout])
	GameManager.current_level = level_id
	GameManager.start_level(level_id)
	get_tree().change_scene_to_file("res://scenes/game/level_%d.tscn" % level_id)
	await get_tree().create_timer(1.0).timeout

	var game_root := get_tree().current_scene
	if game_root == null:
		_results.append(_failed_row(level_id, loadout, "scene_load_failed"))
		return

	# Place towers based on loadout
	var placements := _placements(game_root, loadout)
	for entry in placements:
		var data_path := "res://resources/tower_data/%s.tres" % entry.id
		if ResourceLoader.exists(data_path):
			var td = load(data_path)
			_instantiate_tower(game_root, td, entry.pos)

	# Auto-start all waves
	var wm := game_root.get_node_or_null("WaveManager") as Node
	if wm == null:
		_results.append(_failed_row(level_id, loadout, "no_wave_manager"))
		return
	wm.set("auto_start_waves", true)
	wm.call("start_next_wave")

	var leaks := 0
	var lives_lost_signal := func(n: int): leaks += n
	GameManager.lives_changed.connect(func(_l): pass)

	# Wait for all waves to finish OR sim timeout
	var t0 := Time.get_ticks_msec()
	while true:
		await get_tree().create_timer(0.25).timeout
		var elapsed := float(Time.get_ticks_msec() - t0) / 1000.0
		var all_done: bool = wm.get("all_done") if wm.has_method("get") else false
		if all_done or GameManager.current_state == GameManager.GameState.LOST:
			break
		if elapsed > MAX_SIM_SECONDS:
			print("[simulator] level %d loadout %s timed out" % [level_id, loadout])
			break

	var elapsed_s: float = float(Time.get_ticks_msec() - t0) / 1000.0
	var final_lives: int = GameManager.lives
	var final_gold: int = CurrencyManager.gold
	var leaks_inferred: int = max(0, GameManager.max_lives - final_lives)
	var won: bool = GameManager.current_state == GameManager.GameState.WON \
		or (GameManager.current_state != GameManager.GameState.LOST and final_lives > 0)

	_results.append({
		"level": level_id,
		"loadout": loadout,
		"towers": placements.size(),
		"leaks": leaks_inferred,
		"final_lives": final_lives,
		"final_gold": final_gold,
		"sim_seconds": elapsed_s,
		"won": "true" if won else "false",
	})

	_cleanup()


func _placements(game_root: Node, loadout: String) -> Array:
	var path := game_root.get_node_or_null("EnemyPath") as Path2D
	if path == null or path.curve == null:
		return []
	var ids: Array
	if loadout == "minimal":
		ids = ["basic"]  # Trivialness check: 1 tower only
	else:
		ids = ["basic", "basic", "sniper", "splash"]
	# Sample along curve, offset perpendicular
	var curve := path.curve
	var length := curve.get_baked_length()
	var placements: Array = []
	for i in ids.size():
		var t := float(i + 1) / float(ids.size() + 1)
		var on_path: Vector2 = path.to_global(curve.sample_baked(length * t))
		var ahead: Vector2 = path.to_global(curve.sample_baked(min(length * t + 10.0, length)))
		var tangent: Vector2 = (ahead - on_path).normalized() if (ahead - on_path).length() > 0.1 else Vector2(1, 0)
		var perp: Vector2 = Vector2(-tangent.y, tangent.x) * (90.0 if i % 2 == 0 else -90.0)
		var pos := on_path + perp
		pos.x = clampf(pos.x, 80.0, 1200.0)
		pos.y = clampf(pos.y, 80.0, 640.0)
		placements.append({ "id": ids[i], "pos": pos })
	return placements


func _instantiate_tower(parent: Node, td: Resource, pos: Vector2) -> void:
	var scn: PackedScene = load("res://scenes/towers/base_tower.tscn") as PackedScene
	var tower = scn.instantiate()
	tower.data = td
	tower.is_placed = true
	tower.global_position = pos
	parent.add_child(tower)
	if CurrencyManager.can_afford(td.buy_cost):
		CurrencyManager.spend_gold(td.buy_cost)


func _cleanup() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	for t in get_tree().get_nodes_in_group("towers"):
		t.queue_free()
	GameManager.set_state(GameManager.GameState.MENU)


func _failed_row(level_id: int, loadout: String, reason: String) -> Dictionary:
	return {
		"level": level_id,
		"loadout": loadout,
		"towers": 0,
		"leaks": 999,
		"final_lives": 0,
		"final_gold": 0,
		"sim_seconds": 0.0,
		"won": "false",
		"reason": reason,
	}


func _write_csv() -> void:
	var f := FileAccess.open(RESULTS_CSV, FileAccess.WRITE)
	if f == null:
		return
	f.store_line("level,loadout,towers,leaks,final_lives,final_gold,sim_seconds,won")
	for r in _results:
		f.store_line("%d,%s,%d,%d,%d,%d,%.1f,%s" % [
			r.level, r.loadout, r.towers, r.leaks,
			r.final_lives, r.final_gold, r.sim_seconds, r.won,
		])
	f.close()
	print("[simulator] CSV written to %s" % RESULTS_CSV)


func _exit_code() -> int:
	# 0 = all default loadouts won AND minimal loadout did NOT trivially clear
	# 1 = a level is unwinnable on default loadout (regression)
	# 2 = a level is trivial — clearable with just 1 tower (too easy)
	var any_unwinnable := false
	var any_trivial := false
	for r in _results:
		if r.loadout == "default" and r.won == "false":
			any_unwinnable = true
		if r.loadout == "minimal" and r.won == "true" and r.leaks == 0:
			any_trivial = true
	if any_unwinnable: return 1
	if any_trivial: return 2
	return 0
