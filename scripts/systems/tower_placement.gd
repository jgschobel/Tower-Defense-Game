class_name TowerPlacement
extends Node2D

## Handles tower placement via touch/click. Free placement (no grid snap).
## Towers can't overlap each other or be placed on the enemy path.
##
## Drag-and-drop flow (BTD-style):
##   1. Player taps a shop button → HUD emits tower_selected_for_placement
##   2. GameLevel calls start_placement() → ghost created (hidden)
##   3. First pointer motion reveals ghost at finger, continuously updates
##   4. On release (or on a quick tap with no motion) → try to place
##      at the release position. Release on invalid = cancel, not place.
##   5. Previous behavior (press-to-place) also still works as a fallback
##      for cases where release event is lost — press also fires a place.

signal tower_placed(tower: Node2D)
signal placement_cancelled
signal placement_invalid(reason: String)

@export var min_tower_spacing: float = 60.0
@export var min_path_distance: float = 45.0

var is_placing: bool = false
var ghost_tower: Node2D = null
var selected_tower_data: TowerData = null
var placed_towers: Array = []

var _tower_scene: PackedScene
var _path_points: PackedVector2Array = PackedVector2Array()
# Drag-and-drop state: suppress double-place (press + release fires twice).
var _just_placed: bool = false
# Track whether the current touch interaction has seen any motion, so a
# quick stationary tap counts as place-at-finger rather than cancel.
var _had_motion: bool = false


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
	# Park the ghost offscreen so it doesn't briefly flash at world origin
	# (0,0) = top-left corner of the play area before the player taps/drags
	# to position it. Fixes playtest-feedback #81.
	ghost_tower.global_position = Vector2(-9999, -9999)
	ghost_tower.visible = false
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
			# Start of interaction: update ghost to finger, clear motion flag.
			_had_motion = false
			_just_placed = false
			_update_ghost_position(pos)
		else:
			# Release: place on current position (drag-and-drop drop).
			# If we never moved (stationary tap), still place at the tap
			# location — identical to the pre-existing press-to-place UX
			# so tap-happy users aren't broken.
			if not _just_placed:
				_try_place(pos)

	if event is InputEventScreenDrag or event is InputEventMouseMotion:
		_had_motion = true
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
		# First input — reveal the ghost (was hidden offscreen at start_placement)
		if not ghost_tower.visible:
			ghost_tower.visible = true

		if _can_place_at(world_pos):
			ghost_tower.modulate = Color(0.5, 1.0, 0.5, 0.6)
		else:
			ghost_tower.modulate = Color(1.0, 0.3, 0.3, 0.6)


func _try_place(screen_pos: Vector2) -> void:
	var world_pos := get_canvas_transform().affine_inverse() * screen_pos

	var error := _get_placement_error(world_pos)
	if error != "":
		placement_invalid.emit(error)
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

	SfxManager.play_place()
	tower_placed.emit(tower)
	_just_placed = true
	cancel_placement()


func _can_place_at(pos: Vector2) -> bool:
	return _get_placement_error(pos) == ""


func _get_placement_error(pos: Vector2) -> String:
	for tower_node in placed_towers:
		if is_instance_valid(tower_node):
			if pos.distance_to(tower_node.global_position) < min_tower_spacing:
				return "Z'nöch am Turm!"

	for path_point in _path_points:
		if pos.distance_to(path_point) < min_path_distance:
			return "Z'nöch am Wäg!"

	var vp_size := get_viewport_rect().size
	if pos.x < 30 or pos.x > vp_size.x - 30 or pos.y < 55 or pos.y > vp_size.y - 160:
		return "Am Rand bleibe!"

	return ""


func _on_tower_sold(tower: Node2D) -> void:
	placed_towers.erase(tower)
