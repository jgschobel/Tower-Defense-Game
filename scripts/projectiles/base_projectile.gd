class_name BaseProjectile
extends Area2D

## Projectile fired by towers. Tracks a target enemy and deals damage on hit.
## `style` drives the visual: each tower gets a distinct look (only Lemurius
## throws bananas). `leaves_ground_pool` spawns a lingering acid pool (JoJo).

var target: BaseEnemy = null
var damage: float = 0.0
var damage_type: int = 0
var speed: float = 500.0
var is_splash: bool = false
var splash_radius: float = 0.0
var splash_damage_pct: float = 0.5
var slow_amount: float = 0.0
var slow_duration: float = 0.0
var color: Color = Color.YELLOW

# Projectile style (banana / volleyball / flask / pollen / tongue)
var style: String = "banana"
# Whether to spawn an AcidPool on impact (JoJo)
var leaves_pool: bool = false
var pool_duration: float = 3.0
var pool_dmg_per_tick: float = 4.0
var pool_radius: float = 70.0

var _direction: Vector2 = Vector2.ZERO
var _last_target_pos: Vector2 = Vector2.ZERO
var _spin_speed: float = 12.0
var _is_tongue: bool = false
var _origin_pos: Vector2 = Vector2.ZERO


func setup(
	origin: Vector2,
	p_target: BaseEnemy,
	p_damage: float,
	p_damage_type: int,
	p_color: Color,
	p_splash: bool = false,
	p_splash_radius: float = 0.0,
	p_splash_damage_pct: float = 0.5,
	p_slow_amount: float = 0.0,
	p_slow_duration: float = 0.0,
	p_style: String = "banana",
	p_leaves_pool: bool = false,
	p_pool_duration: float = 3.0,
	p_pool_dmg: float = 4.0,
	p_pool_radius: float = 70.0
) -> void:
	global_position = origin
	_origin_pos = origin
	target = p_target
	damage = p_damage
	damage_type = p_damage_type
	color = p_color
	is_splash = p_splash
	splash_radius = p_splash_radius
	splash_damage_pct = p_splash_damage_pct
	slow_amount = p_slow_amount
	slow_duration = p_slow_duration
	style = p_style
	leaves_pool = p_leaves_pool
	pool_duration = p_pool_duration
	pool_dmg_per_tick = p_pool_dmg
	pool_radius = p_pool_radius

	if target:
		_last_target_pos = target.global_position

	_is_tongue = style == "tongue"

	# Refresh sprite visibility based on current style — pooled projectiles
	# only run _ready() once (at pool prewarm with style=banana), so on
	# reuse we need to update here or the default sprite leaks through on
	# styles that draw themselves.
	var drawn_styles := ["tongue", "volleyball", "flask", "pollen"]
	if has_node("Sprite2D"):
		$Sprite2D.visible = not (style in drawn_styles)

	# Reset spin per style
	match style:
		"tongue":   _spin_speed = 0.0
		"flask":    _spin_speed = 8.0
		"pollen":   _spin_speed = 0.0
		"volleyball": _spin_speed = 10.0
		_:          _spin_speed = 12.0


func _ready() -> void:
	# Hide the default sprite for styles that draw themselves via _draw()
	var drawn_styles := ["tongue", "volleyball", "flask", "pollen"]
	if style in drawn_styles:
		if has_node("Sprite2D"):
			$Sprite2D.visible = false
	if _is_tongue:
		_spin_speed = 0.0
		speed = 800.0
	elif style == "flask":
		_spin_speed = 8.0  # chem flask tumbles
	elif style == "pollen":
		_spin_speed = 0.0  # pollen sphere pulses instead


func _process(delta: float) -> void:
	# If target is gone
	if not is_instance_valid(target) or target.is_dead:
		if is_splash:
			# Splash continues to last known position and detonates
			_direction = (_last_target_pos - global_position).normalized()
			global_position += _direction * speed * delta
			if global_position.distance_to(_last_target_pos) < 15.0:
				_hit()
			return
		else:
			# Return to pool instead of freeing — was causing freed-ref
			# crashes when the same pooled slot was reacquired (pool's
			# _free array kept a stale reference to a queue_freed node).
			if ProjectilePool:
				ProjectilePool.release(self)
			else:
				queue_free()
			return

	_last_target_pos = target.global_position
	_direction = (_last_target_pos - global_position).normalized()
	global_position += _direction * speed * delta

	# Styles that draw themselves redraw every frame; spinners spin their sprite
	var drawn_styles := ["tongue", "volleyball", "flask", "pollen"]
	if style in drawn_styles:
		queue_redraw()
	else:
		if has_node("Sprite2D"):
			$Sprite2D.rotation += _spin_speed * delta

	if global_position.distance_to(_last_target_pos) < 15.0:
		_hit()


func _draw() -> void:
	match style:
		"tongue":
			# Hot pink tongue from tower's mouth to tip
			var local_origin := to_local(_origin_pos)
			draw_line(local_origin, Vector2.ZERO, Color(1.0, 0.1, 0.45, 1.0), 10.0)
			draw_line(local_origin, Vector2.ZERO, Color(1.0, 0.4, 0.6, 0.7), 4.0)
			draw_circle(Vector2.ZERO, 12.0, Color(1.0, 0.05, 0.35, 1.0))
		"volleyball":
			# Cordula's fasnachts-volleyball — white with colorful stripes
			draw_circle(Vector2.ZERO, 12.0, Color(1.0, 1.0, 1.0, 1.0))
			draw_arc(Vector2.ZERO, 12.0, 0.0, TAU, 20, Color(0.15, 0.15, 0.2, 1), 2.0)
			# Three curved stripes for volleyball pattern
			var t: float = float(Time.get_ticks_msec()) / 1000.0
			for i in 3:
				var a: float = (float(i) / 3.0) * TAU + t * 4.0
				var p: Vector2 = Vector2(cos(a), sin(a)) * 8.0
				draw_circle(p, 2.5, Color(0.9, 0.2, 0.5, 1))
		"flask":
			# JoJo's chemical erlenmeyer-flask projectile — green liquid
			# in a glass body that tumbles
			var t: float = float(Time.get_ticks_msec()) / 1000.0
			var spin: float = t * _spin_speed
			draw_set_transform(Vector2.ZERO, spin, Vector2.ONE)
			# Glass body (downward triangle)
			var glass := PackedVector2Array([
				Vector2(-8, -10), Vector2(8, -10),
				Vector2(10, 6), Vector2(0, 12), Vector2(-10, 6)
			])
			draw_colored_polygon(glass, Color(0.85, 0.95, 1.0, 0.5))
			# Bubbling green liquid inside
			draw_colored_polygon(PackedVector2Array([
				Vector2(-7, 0), Vector2(7, 0),
				Vector2(8, 5), Vector2(0, 11), Vector2(-8, 5)
			]), Color(0.3, 1.0, 0.4, 0.9))
			# Neck
			draw_line(Vector2(-3, -10), Vector2(-3, -15), Color(0.5, 0.7, 0.8, 1), 1.5)
			draw_line(Vector2(3, -10), Vector2(3, -15), Color(0.5, 0.7, 0.8, 1), 1.5)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"pollen":
			# Kühne's magical pollen cluster — pulsing violet/gold spheres
			var t2: float = float(Time.get_ticks_msec()) / 1000.0
			var pulse: float = 1.0 + 0.2 * sin(t2 * 10.0)
			draw_circle(Vector2.ZERO, 8.0 * pulse, Color(0.95, 0.85, 0.3, 0.6))
			draw_circle(Vector2.ZERO, 5.0 * pulse, Color(1.0, 0.95, 0.5, 1.0))
			for i in 4:
				var a2: float = (float(i) / 4.0) * TAU + t2 * 3.0
				var p2: Vector2 = Vector2(cos(a2), sin(a2)) * 11.0
				draw_circle(p2, 2.5, Color(0.7, 0.3, 0.9, 0.8))
		_:
			pass  # "banana" uses default sprite2d (already textured)


func _hit() -> void:
	if is_instance_valid(target) and not target.is_dead:
		target.take_damage(damage, damage_type)
		target.show_hit_reaction()

		if slow_amount > 0.0 and slow_duration > 0.0:
			target.apply_slow(1.0 - slow_amount, slow_duration)

	if is_splash and splash_radius > 0.0:
		var enemies := get_tree().get_nodes_in_group("enemies")
		for enemy_node in enemies:
			var enemy := enemy_node as BaseEnemy
			if enemy == null or enemy == target or enemy.is_dead:
				continue
			if global_position.distance_to(enemy.global_position) <= splash_radius:
				enemy.take_damage(damage * splash_damage_pct, damage_type)

	# Spawn a lingering acid pool for JoJo-style projectiles — continues
	# damaging enemies that walk over it for `pool_duration` seconds.
	if leaves_pool:
		_spawn_acid_pool()

	# Return to pool instead of freeing. Pool no-ops gracefully if this
	# projectile wasn't originally acquired from it.
	if ProjectilePool:
		ProjectilePool.release(self)
	else:
		queue_free()


const _ACID_POOL_SCRIPT := preload("res://scripts/projectiles/acid_pool.gd")

func _spawn_acid_pool() -> void:
	# Defensive: class_name resolution can be flaky, use preload.
	# Also guard against current_scene being null mid-transition.
	var tree := get_tree()
	if tree == null:
		return
	var host: Node = tree.current_scene
	if host == null:
		return
	var pool: Node2D = _ACID_POOL_SCRIPT.new()
	pool.global_position = global_position
	pool.duration = pool_duration
	pool.damage_per_tick = pool_dmg_per_tick
	pool.radius = pool_radius
	pool.damage_type = damage_type
	host.add_child(pool)


func reset_for_pool() -> void:
	target = null
	damage = 0.0
	damage_type = 0
	is_splash = false
	splash_radius = 0.0
	splash_damage_pct = 0.5
	slow_amount = 0.0
	slow_duration = 0.0
	style = "banana"
	leaves_pool = false
	pool_duration = 3.0
	pool_dmg_per_tick = 4.0
	pool_radius = 70.0
	_direction = Vector2.ZERO
	_last_target_pos = Vector2.ZERO
	_is_tongue = false
	_origin_pos = Vector2.ZERO
	global_position = Vector2.ZERO
	rotation = 0.0
