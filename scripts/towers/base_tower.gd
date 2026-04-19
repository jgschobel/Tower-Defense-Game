class_name BaseTower
extends Node2D

## Base tower that targets and shoots enemies in range.

signal tower_sold(tower: Node2D)
signal tower_upgraded(tower: Node2D, new_level: int)

@export var data: TowerData

var upgrade_level: int = 0          # legacy linear
var path_a_tier: int = 0            # branching, 0-3
var path_b_tier: int = 0            # branching, 0-3
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

	if data.has_branching_upgrades():
		for i in path_a_tier:
			if i < data.path_a_damage_bonus.size():
				effective_damage += data.path_a_damage_bonus[i]
			if i < data.path_a_range_bonus.size():
				effective_range += data.path_a_range_bonus[i]
			if i < data.path_a_speed_bonus.size():
				effective_speed += data.path_a_speed_bonus[i]
		for i in path_b_tier:
			if i < data.path_b_damage_bonus.size():
				effective_damage += data.path_b_damage_bonus[i]
			if i < data.path_b_range_bonus.size():
				effective_range += data.path_b_range_bonus[i]
			if i < data.path_b_speed_bonus.size():
				effective_speed += data.path_b_speed_bonus[i]
	else:
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

	# Juice: sprite visibly turns toward the active target. Attack origin
	# rotates fully (for projectile spawn direction). Sprite clamped to
	# ±35° so chibi heads stay readable (not fully upside-down when
	# enemy is to the left), with snappy 8× lerp for "tracking feel".
	if current_target and attack_origin:
		var dir := current_target.global_position - global_position
		attack_origin.rotation = dir.angle()
		var target_tilt := clampf(dir.angle(), -0.6, 0.6)
		if sprite:
			sprite.rotation = lerpf(sprite.rotation, target_tilt, 8.0 * delta)
	elif sprite:
		# No target: ease back to neutral
		sprite.rotation = lerpf(sprite.rotation, 0.0, 4.0 * delta)

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

	# Projectile spawns from per-tower offset (Amösius tongue from mouth,
	# Lemurius bananas from hand, etc). Falls back to attack_origin marker
	# then to tower center.
	var origin_pos: Vector2
	if data.projectile_origin_offset != Vector2.ZERO:
		origin_pos = global_position + data.projectile_origin_offset
	elif attack_origin:
		origin_pos = attack_origin.global_position
	else:
		origin_pos = global_position

	SfxManager.play_shoot()
	# Muzzle flash — colored burst in the direction of the target
	if EffectPlayer and is_instance_valid(current_target):
		var flash_dir := (current_target.global_position - origin_pos).normalized()
		EffectPlayer.spawn_muzzle_flash(origin_pos, flash_dir, data.projectile_color)
	# Attack animation — bounce/pulse
	if sprite:
		var atk_tween := create_tween()
		atk_tween.tween_property(sprite, "scale", sprite.scale * 1.2, 0.08)
		atk_tween.tween_property(sprite, "scale", sprite.scale, 0.12)

	# Prefer the pool to avoid instantiate/queue_free churn at scale.
	# Falls back to instantiation if pool is unavailable (loading order)
	var projectile: Node = null
	if ProjectilePool and ProjectilePool.has_method("acquire"):
		projectile = ProjectilePool.acquire()
	if projectile == null or not is_instance_valid(projectile):
		projectile = _projectile_scene.instantiate()
		var scene_root := get_tree().current_scene
		if scene_root:
			scene_root.add_child(projectile)
		else:
			# Pathological case — no current scene. Bail rather than crash.
			projectile.queue_free()
			return
	# setup() must not throw. If it does, quietly release the projectile.
	if projectile.has_method("setup"):
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
			data.slow_duration,
			data.projectile_style,
			data.leaves_ground_pool,
			data.ground_pool_duration,
			data.ground_pool_damage_per_tick,
			data.ground_pool_radius
		)
	else:
		push_warning("[tower] projectile has no setup() — releasing")
		if ProjectilePool:
			ProjectilePool.release(projectile)
		else:
			projectile.queue_free()


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

	SfxManager.play_upgrade()
	# Upgrade celebration animation
	if sprite:
		var upg_tween := create_tween()
		upg_tween.tween_property(sprite, "scale", sprite.scale * 1.5, 0.15)
		upg_tween.tween_property(sprite, "scale", sprite.scale, 0.2)
		# Flash gold
		upg_tween.parallel().tween_property(sprite, "modulate", Color(1.5, 1.3, 0.5), 0.15)
		upg_tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)

	# Floating upgrade text
	var upg_label := Label.new()
	if upgrade_level <= data.upgrade_names.size():
		upg_label.text = data.upgrade_names[upgrade_level - 1]
	else:
		upg_label.text = "UPGRÄDET!"
	upg_label.add_theme_font_size_override("font_size", 16)
	upg_label.add_theme_color_override("font_color", Color(1, 0.85, 0.1))
	upg_label.add_theme_color_override("font_outline_color", Color.BLACK)
	upg_label.add_theme_constant_override("outline_size", 3)
	upg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upg_label.position = Vector2(-50, -60)
	upg_label.z_index = 20
	add_child(upg_label)
	var lbl_tween := create_tween()
	lbl_tween.set_parallel(true)
	lbl_tween.tween_property(upg_label, "position:y", -100.0, 1.0)
	lbl_tween.tween_property(upg_label, "modulate:a", 0.0, 1.0)
	lbl_tween.chain().tween_callback(upg_label.queue_free)

	return true


func sell() -> void:
	var refund: int
	if data.has_branching_upgrades():
		refund = data.get_sell_value_branched(path_a_tier, path_b_tier)
	else:
		refund = data.get_sell_value(upgrade_level)
	CurrencyManager.add_gold(refund)
	tower_sold.emit(self)
	is_placed = false  # stop attacking
	SfxManager.play_sell()
	# Shrink animation before removing
	var sell_tween := create_tween()
	sell_tween.tween_property(self, "scale", Vector2.ZERO, 0.3).set_ease(Tween.EASE_IN)
	sell_tween.tween_callback(queue_free)


func can_upgrade() -> bool:
	if upgrade_level >= data.upgrade_costs.size():
		return false
	return CurrencyManager.can_afford(data.upgrade_costs[upgrade_level])


func get_upgrade_cost() -> int:
	if upgrade_level >= data.upgrade_costs.size():
		return -1
	return data.upgrade_costs[upgrade_level]


# -- Branching upgrades (BTD5-style) --

func can_upgrade_path(path_letter: String) -> bool:
	if not data or not data.has_branching_upgrades():
		return false
	var tier := path_a_tier if path_letter == "a" else path_b_tier
	var costs: Array[int] = data.path_a_costs if path_letter == "a" else data.path_b_costs
	if tier >= costs.size():
		return false
	return CurrencyManager.can_afford(costs[tier])


func get_path_upgrade_cost(path_letter: String) -> int:
	if not data or not data.has_branching_upgrades():
		return -1
	var tier := path_a_tier if path_letter == "a" else path_b_tier
	var costs: Array[int] = data.path_a_costs if path_letter == "a" else data.path_b_costs
	if tier >= costs.size():
		return -1
	return costs[tier]


func get_path_next_tier_name(path_letter: String) -> String:
	if not data or not data.has_branching_upgrades():
		return ""
	var tier := path_a_tier if path_letter == "a" else path_b_tier
	var names: Array[String] = data.path_a_tier_names if path_letter == "a" else data.path_b_tier_names
	if tier >= names.size():
		return ""
	return names[tier]


func upgrade_path(path_letter: String) -> bool:
	if not can_upgrade_path(path_letter):
		return false
	var cost := get_path_upgrade_cost(path_letter)
	if not CurrencyManager.spend_gold(cost):
		return false
	if path_letter == "a":
		path_a_tier += 1
	else:
		path_b_tier += 1
	upgrade_level = path_a_tier + path_b_tier  # keep legacy counter in sync for sell_value, etc.
	_recalculate_stats()
	_update_range_collider()
	_apply_path_tint()
	tower_upgraded.emit(self, upgrade_level)
	SfxManager.play_upgrade()

	if sprite:
		var upg_tween := create_tween()
		upg_tween.tween_property(sprite, "scale", sprite.scale * 1.3, 0.15)
		upg_tween.tween_property(sprite, "scale", sprite.scale, 0.2)

	var upg_label := Label.new()
	var tier_name := ""
	if path_letter == "a" and path_a_tier > 0 and path_a_tier - 1 < data.path_a_tier_names.size():
		tier_name = data.path_a_tier_names[path_a_tier - 1]
	elif path_letter == "b" and path_b_tier > 0 and path_b_tier - 1 < data.path_b_tier_names.size():
		tier_name = data.path_b_tier_names[path_b_tier - 1]
	upg_label.text = tier_name if tier_name != "" else "UPGRÄDET!"
	upg_label.add_theme_font_size_override("font_size", 18)
	upg_label.add_theme_color_override("font_color", Color(1, 0.85, 0.1))
	upg_label.add_theme_color_override("font_outline_color", Color.BLACK)
	upg_label.add_theme_constant_override("outline_size", 3)
	upg_label.position = Vector2(-80, -60)
	upg_label.z_index = 20
	add_child(upg_label)
	var lbl_tween := create_tween()
	lbl_tween.set_parallel(true)
	lbl_tween.tween_property(upg_label, "position:y", -100.0, 1.0)
	lbl_tween.tween_property(upg_label, "modulate:a", 0.0, 1.0)
	lbl_tween.chain().tween_callback(upg_label.queue_free)

	return true


func _apply_path_tint() -> void:
	if not sprite or not data or not data.has_branching_upgrades():
		return
	if path_a_tier == 0 and path_b_tier == 0:
		sprite.modulate = Color.WHITE
		return
	# Per-tier visual delta fix (playtest-feedback #80): strength ramp alone
	# collapsed into near-identical greens at A1/A2/A3 because lerp(WHITE,
	# saturated_tint, 0.55..1.0) produces small perceptual steps on an
	# already-green target. We now also darken each step so the player
	# reads tier progression as "getting darker/richer", not just "slightly
	# different green". T1 = pastel, T2 = mid, T3 = rich-dark.
	var max_tier: int = max(path_a_tier, path_b_tier)
	# Lookup-table per tier for strength + brightness. Hand-tuned for
	# perceptual separation against Lemurius green and Cordula orange tints.
	var strength: float = 0.45
	var brightness: float = 1.0
	match max_tier:
		1:
			strength = 0.45
			brightness = 1.0
		2:
			strength = 0.85
			brightness = 0.88
		_:  # 3+
			strength = 1.0
			brightness = 0.72
	# Blend tints by their per-path weights
	var a_weight: float = float(path_a_tier)
	var b_weight: float = float(path_b_tier)
	var total: float = a_weight + b_weight
	var blended: Color = data.path_a_tint * (a_weight / total) + data.path_b_tint * (b_weight / total)
	var tinted: Color = Color.WHITE.lerp(blended, strength)
	# Apply brightness by scaling RGB (keep alpha)
	sprite.modulate = Color(tinted.r * brightness, tinted.g * brightness, tinted.b * brightness, tinted.a)


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
		# Auto-scale to fit nicely on the map
		var max_dim := maxf(tex.get_width(), tex.get_height())
		var target_size := 120.0
		var s := target_size / max_dim
		sprite.scale = Vector2(s, s)
		sprite.modulate = Color.WHITE
	else:
		sprite.modulate = data.base_color
	# Draw base pedestal under tower
	queue_redraw()


func _draw() -> void:
	if not is_placed:
		return
	# Stone pedestal under tower
	draw_circle(Vector2.ZERO, 35.0, Color(0.35, 0.3, 0.25, 0.5))
	draw_circle(Vector2.ZERO, 32.0, Color(0.45, 0.4, 0.35, 0.4))


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
	# Dedupe: pool reuse can re-fire area_entered for an already-tracked
	# enemy when the HitBox was deactivated + reactivated while still
	# overlapping our DetectionArea (area_exited may skip on pool-park).
	# Audit P1: duplicate entries were biasing target-mode selection.
	if enemy is BaseEnemy and enemy not in _enemies_in_range:
		_enemies_in_range.append(enemy)


func _on_detection_area_area_exited(area: Area2D) -> void:
	var enemy := area.get_parent()
	if enemy is BaseEnemy:
		_enemies_in_range.erase(enemy)
