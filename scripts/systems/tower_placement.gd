class_name TowerPlacement
extends Node2D

## Handles tower placement via touch/click. Free placement (no grid snap).
## Towers can't overlap each other or be placed on the enemy path.

signal tower_placed(tower: Node2D)
signal placement_cancelled
signal placement_failed(reason: String, at_pos: Vector2)

@export var min_tower_spacing: float = 60.0
@export var min_path_distance: float = 45.0

var is_placing: bool = false
var ghost_tower: Node2D = null
var selected_tower_data: TowerData = null
var placed_towers: Array = []

var _tower_scene: PackedScene
var _path_points: PackedVector2Array = PackedVector2Array()


func _ready() -> void:
	_tower_scene = preload("res://scenes/towers/base_tower.tscn")
	# Cache path points for distance checks
	_cache_path_points()


func _cache_path_points() -> void:
	var path_node := get_parent().get_node_or_null("EnemyPath") as Path2D
	if path_node and path_node.curve:
		# Sample points along the curve
		var curve := path_node.curve
		var length := curve.get_baked_length()
		var step := 15.0
		var dist := 0.0
		while dist <= length:
			var point := curve.sample_baked(dist)
			_path_points.append(path_node.to_global(point))
			dist += step


func start_placement(tower_data: TowerData) -> void:
	if is_placing:
		cancel_placement()

	if not CurrencyManager.can_afford(tower_data.buy_cost):
		return

	selected_tower_data = tower_data
	is_placing = true

	ghost_tower = _tower_scene.instantiate()
	ghost_tower.data = tower_data
	ghost_tower.modulate = Color(1.0, 1.0, 1.0, 0.5)
	ghost_tower.is_placed = false
	add_child(ghost_tower)
	# Show range AFTER adding to tree so _ready() has set up the range indicator
	ghost_tower.show_range(true)


func cancel_placement() -> void:
	if ghost_tower:
		ghost_tower.queue_free()
		ghost_tower = null
	is_placing = false
	selected_tower_data = null
	placement_cancelled.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not is_placing:
		return

	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var pos := _get_event_position(event)
		if event.is_pressed():
			_try_place(pos)

	if event is InputEventScreenDrag or event is InputEventMouseMotion:
		var pos := _get_event_position(event)
		_update_ghost_position(pos)


func _get_event_position(event: InputEvent) -> Vector2:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).position
	if event is InputEventScreenDrag:
		return (event as InputEventScreenDrag).position
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).position
	if event is InputEventMouseMotion:
		return (event as InputEventMouseMotion).position
	return Vector2.ZERO


func _update_ghost_position(screen_pos: Vector2) -> void:
	if ghost_tower:
		var world_pos := get_canvas_transform().affine_inverse() * screen_pos
		ghost_tower.global_position = world_pos

		if _can_place_at(world_pos):
			ghost_tower.modulate = Color(0.5, 1.0, 0.5, 0.6)
		else:
			ghost_tower.modulate = Color(1.0, 0.3, 0.3, 0.6)


func _try_place(screen_pos: Vector2) -> void:
	var world_pos := get_canvas_transform().affine_inverse() * screen_pos

	if not _can_place_at(world_pos):
		placement_failed.emit(_get_failure_reason(world_pos), screen_pos)
		return

	if not CurrencyManager.spend_gold(selected_tower_data.buy_cost):
		return

	var tower = _tower_scene.instantiate()
	tower.data = selected_tower_data
	tower.global_position = world_pos
	tower.is_placed = true
	tower.add_to_group("towers")
	tower.tower_sold.connect(_on_tower_sold)
	get_parent().add_child(tower)

	placed_towers.append(tower)

	tower_placed.emit(tower)
	cancel_placement()


func _get_failure_reason(pos: Vector2) -> String:
	for tower_node in placed_towers:
		if is_instance_valid(tower_node):
			if pos.distance_to(tower_node.global_position) < min_tower_spacing:
				return "Z'nöch am Turm!"
	for path_point in _path_points:
		if pos.distance_to(path_point) < min_path_distance:
			return "Z'nöch am Wäg!"
	return "Nid gültig!"


func _can_place_at(pos: Vector2) -> bool:
	# Check distance to other towers
	for tower_node in placed_towers:
		if is_instance_valid(tower_node):
			if pos.distance_to(tower_node.global_position) < min_tower_spacing:
				return false

	# Check distance to enemy path
	for path_point in _path_points:
		if pos.distance_to(path_point) < min_path_distance:
			return false

	# Keep within screen bounds (with margin)
	# Dynamic bounds based on viewport
	var vp_size := get_viewport_rect().size
	if pos.x < 30 or pos.x > vp_size.x - 30 or pos.y < 55 or pos.y > vp_size.y - 160:
		return false

	return true


func _on_tower_sold(tower: Node2D) -> void:
	placed_towers.erase(tower)
