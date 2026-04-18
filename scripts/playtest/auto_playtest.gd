extends Node

## Autonomous playtester. Activated when Godot is launched with --playtest.
## Drives the game through multiple scripted scenarios, captures screenshots
## every N seconds, logs FPS each frame, writes a summary text file, then
## exits.
##
## Screenshots + logs go to user://playtest/ and are picked up by the
## playtest GitHub Actions workflow, which passes them to a vision agent
## that files feedback issues.

const SHOT_DIR := "user://playtest/"
const FPS_LOG := "user://playtest/fps.log"
const SUMMARY_FILE := "user://playtest/summary.md"
const SHOT_INTERVAL := 2.5
const MAX_SHOTS_PER_SCENARIO := 8

# Three scenarios exercise different paths through the game.
# Scenario 1: healthy play — good tower comp, expected to survive
# Scenario 2: sparse play — one tower only, expected to struggle
# Scenario 3: empty play — no towers placed, prove enemies reach the end
const SCENARIOS: Array = [
	{
		"name": "healthy",
		"level": 1,
		"towers": [
			{ "id": "basic",  "pos": Vector2(320, 430) },
			{ "id": "basic",  "pos": Vector2(620, 260) },
			{ "id": "sniper", "pos": Vector2(900, 430) },
			{ "id": "splash", "pos": Vector2(460, 520) },
		],
	},
	{
		"name": "sparse",
		"level": 1,
		"towers": [
			{ "id": "basic", "pos": Vector2(600, 400) },
		],
	},
	{
		"name": "empty",
		"level": 1,
		"towers": [],
	},
]

var _active: bool = false
var _shot_count: int = 0
var _scenario_name: String = ""
var _fps_samples: Array[float] = []
var _scenario_summaries: Array[Dictionary] = []


func _ready() -> void:
	var args := OS.get_cmdline_args()
	if "--playtest" in args or "--headless-playtest" in args:
		_active = true
		print("[playtest] bot activated — 3 scenarios")
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
		call_deferred("_run_all_scenarios")


func _process(_delta: float) -> void:
	if _active:
		_fps_samples.append(Engine.get_frames_per_second())


func _run_all_scenarios() -> void:
	await get_tree().process_frame
	_snapshot("00_menu")

	for scen in SCENARIOS:
		_scenario_name = scen.name
		_fps_samples.clear()
		var start_time := Time.get_ticks_msec()
		await _run_scenario(scen)
		var elapsed_ms: int = Time.get_ticks_msec() - start_time
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
			"name": scen.name,
			"level": scen.level,
			"towers": scen.towers.size(),
			"elapsed_ms": elapsed_ms,
			"avg_fps": avg_fps,
			"min_fps": min_fps,
			"final_lives": GameManager.lives,
			"final_gold": CurrencyManager.gold,
			"final_state": GameManager.current_state,
			"enemies_remaining": _count_enemies_remaining(),
		})
		# Clean slate between scenarios
		_cleanup_scene()
		await get_tree().create_timer(0.3).timeout

	_write_summary()
	print("[playtest] done — %d screenshots across %d scenarios" % [_shot_count, SCENARIOS.size()])
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(0)


func _run_scenario(scen: Dictionary) -> void:
	print("[playtest] starting scenario: %s" % scen.name)
	GameManager.current_level = scen.level
	GameManager.start_level(scen.level)
	var level_path := "res://scenes/game/level_%d.tscn" % scen.level
	get_tree().change_scene_to_file(level_path)

	await get_tree().create_timer(1.5).timeout
	_snapshot("%s_level_loaded" % scen.name)

	var game_root := get_tree().current_scene
	for entry in scen.towers:
		var data_path := "res://resources/tower_data/%s.tres" % entry.id
		if ResourceLoader.exists(data_path):
			var tower_data = load(data_path)
			if CurrencyManager.can_afford(tower_data.buy_cost):
				_instantiate_tower(game_root, tower_data, entry.pos)
				await get_tree().create_timer(0.15).timeout

	await get_tree().create_timer(0.4).timeout
	_snapshot("%s_towers_placed" % scen.name)

	var wave_manager := game_root.get_node_or_null("WaveManager") as Node
	if wave_manager and wave_manager.has_method("start_next_wave"):
		wave_manager.start_next_wave()

	for i in MAX_SHOTS_PER_SCENARIO:
		await get_tree().create_timer(SHOT_INTERVAL).timeout
		_snapshot("%s_wave_t%02d" % [scen.name, i])
		if GameManager.current_state == GameManager.GameState.LOST \
		or GameManager.current_state == GameManager.GameState.WON:
			break

	_snapshot("%s_final" % scen.name)


func _cleanup_scene() -> void:
	# Clear the current level so the next scenario starts fresh
	for e in get_tree().get_nodes_in_group("enemies"):
		e.queue_free()
	for t in get_tree().get_nodes_in_group("towers"):
		t.queue_free()
	GameManager.set_state(GameManager.GameState.MENU)


func _count_enemies_remaining() -> int:
	return get_tree().get_nodes_in_group("enemies").size()


func _snapshot(tag: String) -> void:
	var img: Image = get_viewport().get_texture().get_image()
	if img == null:
		return
	var filename := "%sshot_%02d_%s.png" % [SHOT_DIR, _shot_count, tag]
	var err := img.save_png(filename)
	if err != OK:
		print("[playtest] screenshot failed: %s (err=%d)" % [filename, err])
	else:
		print("[playtest] %s" % filename)
	_shot_count += 1


func _instantiate_tower(parent: Node, tower_data, pos: Vector2) -> void:
	var tower_scene: PackedScene = load("res://scenes/towers/base_tower.tscn") as PackedScene
	if tower_scene == null:
		return
	var tower = tower_scene.instantiate()
	tower.data = tower_data
	tower.is_placed = true
	tower.global_position = pos
	parent.add_child(tower)
	CurrencyManager.spend_gold(tower_data.buy_cost)


func _write_summary() -> void:
	var f := FileAccess.open(SUMMARY_FILE, FileAccess.WRITE)
	if f == null:
		return
	f.store_string("# Playtest Summary\n\n")
	f.store_string("Timestamp: %s\n\n" % Time.get_datetime_string_from_system(true))
	f.store_string("| Scenario | Level | Towers | Duration (s) | Avg FPS | Min FPS | Final Lives | Final State | Enemies Remaining |\n")
	f.store_string("|---|---|---|---|---|---|---|---|---|\n")
	for s in _scenario_summaries:
		f.store_string("| %s | %d | %d | %.1f | %.1f | %.1f | %d | %s | %d |\n" % [
			s.name,
			s.level,
			s.towers,
			float(s.elapsed_ms) / 1000.0,
			s.avg_fps,
			s.min_fps,
			s.final_lives,
			_state_name(s.final_state),
			s.enemies_remaining,
		])
	f.store_string("\n## Interpretation hints for the vision agent\n\n")
	f.store_string("- `healthy` scenario should result in WON state with lives > 0.\n")
	f.store_string("- `sparse` scenario may lose but should NOT crash; check final screenshots.\n")
	f.store_string("- `empty` scenario should result in LOST state (enemies reach end).\n")
	f.store_string("- Avg FPS < 30 is a performance red flag. Min FPS < 15 is a hitch.\n")
	f.close()
	print("[playtest] summary written to %s" % SUMMARY_FILE)


func _state_name(s: int) -> String:
	match s:
		GameManager.GameState.MENU: return "MENU"
		GameManager.GameState.PLAYING: return "PLAYING"
		GameManager.GameState.PAUSED: return "PAUSED"
		GameManager.GameState.WON: return "WON"
		GameManager.GameState.LOST: return "LOST"
		_: return "UNKNOWN"
