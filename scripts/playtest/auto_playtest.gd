extends Node

## Autonomous playtester. Activated when Godot is launched with --playtest.
## Drives the game through a scripted session: starts Level 1, places a few
## towers, runs waves, captures screenshots every N seconds, then exits.
##
## Screenshots are written to user://playtest/shot_NN.png and are picked up
## by the playtest GitHub Actions workflow, which passes them to a vision
## agent that files feedback issues.

const SHOT_DIR := "user://playtest/"
const SHOT_INTERVAL := 2.5  # seconds between screenshots
const MAX_SHOTS := 16         # hard cap so we always exit in finite time
const LEVEL_ID := 1

# Tower placements chosen for Level 1's known path — these positions are
# clear of the enemy path and cover the early zigzag well. If the path
# changes, these may need re-tuning.
const TOWER_PLACEMENTS: Array = [
	{ "id": "basic",  "pos": Vector2(320, 430) },
	{ "id": "basic",  "pos": Vector2(620, 260) },
	{ "id": "sniper", "pos": Vector2(900, 430) },
	{ "id": "splash", "pos": Vector2(460, 520) },
]

var _active: bool = false
var _shot_count: int = 0
var _timer_accum: float = 0.0
var _scene_tree_inited: bool = false


func _ready() -> void:
	var args := OS.get_cmdline_args()
	if "--playtest" in args or "--headless-playtest" in args:
		_active = true
		print("[playtest] bot activated")
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOT_DIR))
		call_deferred("_begin")


func _begin() -> void:
	# Give the initial main scene one frame to settle
	await get_tree().process_frame
	await get_tree().process_frame

	print("[playtest] capturing menu screenshot")
	_snapshot("menu")

	# Warp straight into Level 1 — skip menus
	GameManager.current_level = LEVEL_ID
	GameManager.start_level(LEVEL_ID)
	var level_path := "res://scenes/game/level_%d.tscn" % LEVEL_ID
	get_tree().change_scene_to_file(level_path)

	await get_tree().create_timer(1.5).timeout
	_snapshot("level_loaded")

	# Place towers programmatically
	var game_root := get_tree().current_scene
	var placement_node := game_root.get_node_or_null("TowerPlacement") as Node2D
	if placement_node == null:
		print("[playtest] no TowerPlacement node — scene structure unexpected")
	for entry in TOWER_PLACEMENTS:
		var data_path := "res://resources/tower_data/%s.tres" % entry.id
		if ResourceLoader.exists(data_path):
			var tower_data = load(data_path)
			if CurrencyManager.can_afford(tower_data.buy_cost):
				_instantiate_tower(game_root, tower_data, entry.pos)
				await get_tree().create_timer(0.2).timeout

	await get_tree().create_timer(0.5).timeout
	_snapshot("towers_placed")

	# Kick off the wave
	var wave_manager := game_root.get_node_or_null("WaveManager") as Node
	if wave_manager and wave_manager.has_method("start_next_wave"):
		wave_manager.start_next_wave()

	# Capture every SHOT_INTERVAL seconds until we hit MAX_SHOTS
	while _shot_count < MAX_SHOTS:
		await get_tree().create_timer(SHOT_INTERVAL).timeout
		_snapshot("wave_t%02d" % _shot_count)
		if GameManager.current_state == GameManager.GameState.LOST \
		or GameManager.current_state == GameManager.GameState.WON:
			break

	_snapshot("final")
	print("[playtest] done — %d screenshots in %s" % [_shot_count, SHOT_DIR])
	await get_tree().create_timer(0.5).timeout
	get_tree().quit(0)


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
