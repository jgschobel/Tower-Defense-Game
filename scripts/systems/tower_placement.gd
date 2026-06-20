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
signal tower_removed(tower: Node2D)
signal placement_cancelled
signal placement_invalid(reason: String)

@export var min_tower_spacing: float = 60.0
@export var min_path_distance: float = 45.0

var is_placing: bool = false
var ghost_tower: Node2D = null
var _ghost_x_label: TextureRect = null  # red x SVG overlay when placement invalid (D28)
var selected_tower_data: TowerData = null
var placed_towers: Array = []

var _tower_scene: PackedScene
var _path_points: PackedVector2Array = PackedVector2Array()
# Drag-and-drop state: suppress double-place (press + release fires twice).
var _just_placed: bool = false
# Track whether the current touch interaction has seen any motion, so a
# quick stationary tap counts as place-at-finger rather than cancel.
var _had_motion: bool = false
# Premium-feel tracking (drag-place research 2026-06-20): remember last
# validity so we can fire a haptic+audio "tick" exactly at the boundary
# transition — the BTD6 stickiness feel without changing the math.
var _was_valid_last_frame: bool = true
# Mobile touch needs the ghost rendered ABOVE the finger so the thumb
# doesn't occlude the tower being placed. Single biggest mobile TD tell.
const _MOBILE_THUMB_OFFSET_PX: float = 56.0


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
	_had_motion = false
	_just_placed = false

	ghost_tower = _tower_scene.instantiate()
	ghost_tower.data = tower_data
	ghost_tower.modulate = Color(1.0, 1.0, 1.0, 0.5)
	ghost_tower.is_placed = false
	# Ghost starts at viewport center, VISIBLE with a "hover" tint so
	# the player sees selection confirmation. First pointer press
	# on the map places the tower. The ghost follows drag motion.
	var vp_center: Vector2 = get_viewport_rect().size * 0.5
	ghost_tower.global_position = get_canvas_transform().affine_inverse() * vp_center
	ghost_tower.visible = true
	add_child(ghost_tower)
	# Show range AFTER adding to tree so _ready() has set up the range indicator
	ghost_tower.show_range(true)
	# Set tint based on center validity — safe to call after add_child
	# because placed_towers / path_points are already cached from _ready.
	if _can_place_at(ghost_tower.global_position):
		ghost_tower.modulate = Color(0.5, 1.0, 0.5, 0.6)
	else:
		ghost_tower.modulate = Color(1.0, 0.6, 0.3, 0.5)


func cancel_placement() -> void:
	if ghost_tower:
		# remove_child ejects the node from the scene tree immediately so no
		# subsequent render frame can show it, even if queue_free hasn't run yet.
		var gp := ghost_tower.get_parent()
		if gp:
			gp.remove_child(ghost_tower)
		ghost_tower.queue_free()
		ghost_tower = null
	_ghost_x_label = null
	is_placing = false
	selected_tower_data = null
	placement_cancelled.emit()


func _unhandled_input(event: InputEvent) -> void:
	if not is_placing:
		return

	if event is InputEventScreenTouch or event is InputEventMouseButton:
		var pos := _get_event_position(event)
		if event.is_pressed():
			# Press on the map → place immediately. Shop buttons consume
			# their own press events via MOUSE_FILTER_STOP so this path
			# only fires when the pointer is genuinely on the play area.
			# The `_fresh_placement` swallow-first-press hack was a net
			# regression (it broke tap-to-place entirely since shop
			# button events don't reach _unhandled_input anyway).
			_had_motion = false
			_update_ghost_position(pos)
			_try_place(pos)
		else:
			# Release: only place if we dragged and haven't already placed
			# via the press branch. Handles edge cases where the finger
			# moved between press and release.
			if _had_motion and not _just_placed:
				_try_place(pos)
			_just_placed = false

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
	if not ghost_tower:
		return
	# Mobile finger-occlusion offset (drag-place research #1): render the
	# ghost 56px above the touch point so the thumb doesn't cover the
	# tower the player is placing. THE single biggest mobile TD tell.
	# Non-mobile platforms keep cursor-centered placement.
	var adjusted_screen: Vector2 = screen_pos
	if OS.has_feature("mobile") or OS.has_feature("web_android") \
			or OS.has_feature("web_ios"):
		adjusted_screen.y -= _MOBILE_THUMB_OFFSET_PX
	var world_pos := get_canvas_transform().affine_inverse() * adjusted_screen
	ghost_tower.global_position = world_pos
	# First input — reveal the ghost (was hidden offscreen at start_placement)
	if not ghost_tower.visible:
		ghost_tower.visible = true

	var ring: Node2D = ghost_tower.get_node_or_null("RangeIndicator") if ghost_tower else null
	var is_valid: bool = _can_place_at(world_pos)
	# Validity-boundary tick (drag-place research #2): on the FRAME the
	# state changes, fire haptic + soft audio click. Gives the BTD6
	# "stickiness" feel — the player feels when the ghost crosses into
	# legal territory without staring at the modulate flip.
	if is_valid != _was_valid_last_frame:
		if Input.has_method("vibrate_handheld"):
			Input.vibrate_handheld(15)
		if SfxManager and SfxManager.has_method("play_soft_pluck"):
			SfxManager.play_soft_pluck()
		_was_valid_last_frame = is_valid
	if is_valid:
		ghost_tower.modulate = Color(0.5, 1.0, 0.5, 0.6)
		if ring and ring.has_method("set_tint"):
			ring.set_tint(Color(0.35, 1.0, 0.45, 1.0))
		if _ghost_x_label:
			_ghost_x_label.visible = false
	else:
		ghost_tower.modulate = Color(1.0, 0.3, 0.3, 0.6)
		if ring and ring.has_method("set_tint"):
			ring.set_tint(Color(1.0, 0.30, 0.25, 1.0))
		if _ghost_x_label == null or not is_instance_valid(_ghost_x_label):
			# SVG x icon — was unicode ✕ which depended on font fallback.
			_ghost_x_label = IconLibrary.make_rect("x", 48, Color(1, 0.20, 0.20))
			_ghost_x_label.position = Vector2(-24, -56)
			_ghost_x_label.z_index = 15
			ghost_tower.add_child(_ghost_x_label)
		_ghost_x_label.visible = true


func _try_place(screen_pos: Vector2) -> void:
	if not is_placing:
		return
	var world_pos := get_canvas_transform().affine_inverse() * screen_pos

	var error := _get_placement_error(world_pos)
	if error != "":
		placement_invalid.emit(error)
		# Keep placement mode active so the user can immediately retry on
		# a different spot — they shouldn't need to re-buy the tower.
		# The earlier auto-cancel-on-motion was biting touch users because
		# phone touchscreens register micro-drag even for nominal taps,
		# making every invalid tap cancel + lose context.
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
	_spawn_place_ring(world_pos)
	if tower.has_method("play_place_animation"):
		tower.play_place_animation()
	tower_placed.emit(tower)
	_just_placed = true
	# Adjacency buffs (ROADMAP #38/#41): recompute stats on every
	# placed tower so newly-placed support towers immediately boost
	# neighbors + existing towers pick up new support coverage.
	_refresh_adjacency()
	cancel_placement()


func _spawn_place_ring(pos: Vector2) -> void:
	# Premium place burst (drag-place research #3): expanding shockwave
	# ring instead of the floaty check icon. The check icon read as
	# "I'm a placeholder" — pro TDs use a radial shockwave to confirm
	# "you placed it" with kinetic weight. Pure procedural, no asset.
	var shock := Node2D.new()
	shock.name = "PlaceShockwave"
	shock.z_index = 18
	get_parent().add_child(shock)
	shock.global_position = pos
	# Render via tween + queue_redraw — draw an expanding arc on the node.
	var _draw_state := {"radius": 6.0, "alpha": 0.92}
	shock.set_meta("ds", _draw_state)
	shock.draw.connect(func():
		var st: Dictionary = shock.get_meta("ds")
		shock.draw_arc(Vector2.ZERO, st.radius, 0.0, TAU, 48,
			Color(0.40, 1.0, 0.55, st.alpha), 3.0, true)
		shock.draw_arc(Vector2.ZERO, st.radius * 0.65, 0.0, TAU, 36,
			Color(0.55, 1.0, 0.70, st.alpha * 0.55), 2.0, true))
	var tw := shock.create_tween().set_parallel(true)
	tw.tween_method(func(r: float):
		_draw_state.radius = r
		shock.queue_redraw(), 6.0, 70.0, 0.45) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_method(func(a: float):
		_draw_state.alpha = a
		shock.queue_redraw(), 0.92, 0.0, 0.45) \
		.set_trans(Tween.TRANS_SINE)
	tw.chain().tween_callback(shock.queue_free)


func _refresh_adjacency() -> void:
	for t in get_tree().get_nodes_in_group("towers"):
		if t is BaseTower and t.has_method("_apply_data"):
			t._apply_data()


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
	_refresh_adjacency()
	tower_removed.emit(tower)
