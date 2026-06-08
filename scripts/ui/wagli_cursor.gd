extends Control

## Wagli-Schub drag overlay (ROADMAP P2).
## When active, a finger drag pushes enemies backward along their path.
## Cost: 30 gold per unique enemy pushed per stroke, capped at 4 per stroke.
## Activated by HUD WagliButton; deactivates on finger lift or gold depleted.

signal mode_deactivated

const PUSH_RADIUS_SQ: float = 3600.0  # 60px radius
const PUSH_AMOUNT: float = 35.0
const PUSH_COST: int = 30
const MAX_PUSH_PER_STROKE: int = 4

var _pushed_this_stroke: Array = []
var _is_active: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 10


func activate() -> void:
	_is_active = true
	_pushed_this_stroke.clear()
	mouse_filter = Control.MOUSE_FILTER_STOP


func deactivate() -> void:
	_is_active = false
	_pushed_this_stroke.clear()
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mode_deactivated.emit()


func _gui_input(event: InputEvent) -> void:
	if not _is_active:
		return
	if event is InputEventMouseButton or event is InputEventScreenTouch:
		var pressed: bool = event.pressed if "pressed" in event else false
		if not pressed:
			deactivate()
		return
	var drag_pos: Vector2 = Vector2.ZERO
	var is_drag := false
	if event is InputEventMouseMotion:
		drag_pos = event.position
		is_drag = true
	elif event is InputEventScreenDrag:
		drag_pos = event.position
		is_drag = true
	if not is_drag:
		return
	_push_enemies_near(drag_pos)


func _push_enemies_near(screen_pos: Vector2) -> void:
	if _pushed_this_stroke.size() >= MAX_PUSH_PER_STROKE:
		return
	if not CurrencyManager.can_afford(PUSH_COST):
		deactivate()
		return
	var world_pos := screen_pos
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if enemy in _pushed_this_stroke:
			continue
		if _pushed_this_stroke.size() >= MAX_PUSH_PER_STROKE:
			break
		var dist_sq: float = enemy.global_position.distance_squared_to(world_pos)
		if dist_sq > PUSH_RADIUS_SQ:
			continue
		if "is_dead" in enemy and enemy.is_dead:
			continue
		if not CurrencyManager.can_afford(PUSH_COST):
			deactivate()
			return
		CurrencyManager.spend(PUSH_COST)
		enemy.progress = maxf(0.0, enemy.progress - PUSH_AMOUNT)
		_pushed_this_stroke.append(enemy)
		if EffectPlayer and EffectPlayer.has_method("spawn_step_dust"):
			EffectPlayer.spawn_step_dust(enemy.global_position)
		if SfxManager and SfxManager.has_method("play_click"):
			SfxManager.play_click()
