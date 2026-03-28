class_name BaseTower
extends Node2D

## Base tower that targets and shoots enemies in range.

signal tower_sold(tower: Node2D)
signal tower_upgraded(tower: Node2D, new_level: int)

@export var data: TowerData

var upgrade_level: int = 0
var current_target: BaseEnemy = null
var attack_timer: float = 0.0
var is_placed: bool = false

# Computed stats (base + upgrades)
var effective_damage: float = 0.0
var effective_range: float = 0.0
var effective_speed: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var range_indicator: Node2D = $RangeIndicator
@onready var attack_origin: Marker2D = $AttackOrigin
@onready var detection_area: Area2D = $DetectionArea

var _enemies_in_range: Array = []
var _projectile_scene: PackedScene


func _ready() -> void:
	_projectile_scene = preload("res://scenes/projectiles/base_projectile.tscn")
	if data:
		_apply_data()
		_update_visual()
		_update_range_collider()


func _apply_data() -> void:
	_recalculate_stats()


func _recalculate_stats() -> void:
	if not data:
		return
	effective_damage = data.damage
	effective_range = data.attack_range
	effective_speed = data.attack_speed

	for i in upgrade_level:
		if i < data.upgrade_damage_bonus.size():
			effective_damage += data.upgrade_damage_bonus[i]
		if i < data.upgrade_range_bonus.size():
			effective_range += data.upgrade_range_bonus[i]
		if i < data.upgrade_speed_bonus.size():
			effective_speed += data.upgrade_speed_bonus[i]

	# Apply buff from nearby support towers
	var buff_damage := 0.0
	var buff_speed := 0.0
	for tower_node in get_tree().get_nodes_in_group("towers"):
		var tower := tower_node as BaseTower
		if tower == self or tower == null or not tower.data:
			continue
		if tower.data.buff_range > 0.0:
			if global_position.distance_to(tower.global_position) <= tower.data.buff_range:
				buff_damage += tower.data.buff_damage_pct
				buff_speed += tower.data.buff_speed_pct

	effective_damage *= (1.0 + buff_damage)
	effective_speed *= (1.0 + buff_speed)


func _process(delta: float) -> void:
	if not is_placed or not data:
		return

	# Clean up dead enemies from range list
	var valid_enemies: Array = []
	for e in _enemies_in_range:
		if is_instance_valid(e) and not e.is_dead:
			valid_enemies.append(e)
	_enemies_in_range = valid_enemies

	# Find target
	current_target = _find_target()

	# Slight character tilt toward target + aim attack origin
	if current_target and attack_origin:
		var dir := current_target.global_position - global_position
		attack_origin.rotation = dir.angle()
		# Gentle tilt of the sprite (max ~15 degrees)
		var target_tilt := clampf(dir.angle(), -0.26, 0.26)
		if sprite:
			sprite.rotation = lerpf(sprite.rotation, target_tilt, 5.0 * delta)

	# Attack
	attack_timer -= delta
	if attack_timer <= 0.0 and current_target:
		_attack()
		attack_timer = 1.0 / effective_speed


func _find_target() -> BaseEnemy:
	if _enemies_in_range.is_empty():
		return null

	# Filter flying if can't target them
	var valid: Array = []
	for e in _enemies_in_range:
		var enemy := e as BaseEnemy
		if enemy == null:
			continue
		if not data.can_target_flying and enemy.data and enemy.data.is_flying:
			continue
		valid.append(enemy)

	if valid.is_empty():
		return null

	match data.target_mode:
		TowerData.TargetMode.FIRST:
			var best: BaseEnemy = valid[0]
			for e in valid:
				if e.progress_ratio > best.progress_ratio:
					best = e
			return best
		TowerData.TargetMode.LAST:
			var best: BaseEnemy = valid[0]
			for e in valid:
				if e.progress_ratio < best.progress_ratio:
					best = e
			return best
		TowerData.TargetMode.CLOSEST:
			var best: BaseEnemy = valid[0]
			var best_dist := global_position.distance_squared_to(best.global_position)
			for e in valid:
				var d := global_position.distance_squared_to(e.global_position)
				if d < best_dist:
					best = e
					best_dist = d
			return best
		TowerData.TargetMode.STRONGEST:
			var best: BaseEnemy = valid[0]
			for e in valid:
				if e.health > best.health:
					best = e
			return best

	return valid[0]


func _attack() -> void:
	if not current_target:
		return
	# Double check target is still valid
	if not is_instance_valid(current_target) or current_target.is_dead:
		current_target = null
		return

	# Tongue starts from tower center (face), bananas from attack origin
	var origin_pos: Vector2
	if data.slow_amount > 0.0:
		origin_pos = global_position
	elif attack_origin:
		origin_pos = attack_origin.global_position
	else:
		origin_pos = global_position

	var projectile = _projectile_scene.instantiate()
	projectile.setup(
		origin_pos,
		current_target,
		effective_damage,
		data.damage_type,
		data.projectile_color,
		data.is_splash,
		data.splash_radius,
		data.splash_damage_pct,
		data.slow_amount,
		data.slow_duration
	)
	get_tree().current_scene.add_child(projectile)


func upgrade() -> bool:
	if upgrade_level >= data.upgrade_costs.size():
		return false

	var cost: int = data.upgrade_costs[upgrade_level]
	if not CurrencyManager.spend_gold(cost):
		return false

	upgrade_level += 1
	_recalculate_stats()
	_update_range_collider()
	_update_visual()
	tower_upgraded.emit(self, upgrade_level)
	return true


func sell() -> void:
	var refund := data.get_sell_value(upgrade_level)
	CurrencyManager.add_gold(refund)
	tower_sold.emit(self)
	queue_free()


func can_upgrade() -> bool:
	if upgrade_level >= data.upgrade_costs.size():
		return false
	return CurrencyManager.can_afford(data.upgrade_costs[upgrade_level])


func get_upgrade_cost() -> int:
	if upgrade_level >= data.upgrade_costs.size():
		return -1
	return data.upgrade_costs[upgrade_level]


func show_range(visible_flag: bool) -> void:
	if range_indicator:
		range_indicator.visible = visible_flag


func _update_visual() -> void:
	if not sprite:
		return

	var tex: Texture2D = null

	if data.friend_character_id != "":
		var photo := GameManager.get_friend_photo(data.friend_character_id)
		if photo:
			tex = photo

	if tex == null and data.custom_texture:
		tex = data.custom_texture

	if tex:
		sprite.texture = tex
		# Auto-scale to fit nicely on the map — big and recognizable
		var max_dim := maxf(tex.get_width(), tex.get_height())
		var target_size := 140.0
		var s := target_size / max_dim
		sprite.scale = Vector2(s, s)
		sprite.modulate = Color.WHITE
	else:
		sprite.modulate = data.base_color


func _update_range_collider() -> void:
	if detection_area and detection_area.has_node("CollisionShape2D"):
		var col_shape: CollisionShape2D = detection_area.get_node("CollisionShape2D")
		var circle := CircleShape2D.new()
		circle.radius = effective_range
		col_shape.shape = circle

	if range_indicator and range_indicator.has_method("set_radius"):
		range_indicator.set_radius(effective_range)


func _on_detection_area_area_entered(area: Area2D) -> void:
	var enemy := area.get_parent()
	if enemy is BaseEnemy:
		_enemies_in_range.append(enemy)


func _on_detection_area_area_exited(area: Area2D) -> void:
	var enemy := area.get_parent()
	if enemy is BaseEnemy:
		_enemies_in_range.erase(enemy)
