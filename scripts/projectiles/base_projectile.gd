class_name BaseProjectile
extends Area2D

## Projectile fired by towers. Tracks a target enemy and deals damage on hit.

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
	p_slow_duration: float = 0.0
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

	if target:
		_last_target_pos = target.global_position

	_is_tongue = slow_amount > 0.0 and slow_duration > 0.0


func _ready() -> void:
	if _is_tongue:
		_spin_speed = 0.0
		speed = 800.0
		if has_node("Sprite2D"):
			$Sprite2D.visible = false


func _process(delta: float) -> void:
	# If target is gone, self-destruct immediately
	if not is_instance_valid(target) or target.is_dead:
		queue_free()
		return

	_last_target_pos = target.global_position
	_direction = (_last_target_pos - global_position).normalized()
	global_position += _direction * speed * delta

	if _is_tongue:
		queue_redraw()
	else:
		if has_node("Sprite2D"):
			$Sprite2D.rotation += _spin_speed * delta

	if global_position.distance_to(_last_target_pos) < 15.0:
		_hit()


func _draw() -> void:
	if not _is_tongue:
		return
	# Draw hot pink tongue from tower face to projectile tip
	var local_origin := to_local(_origin_pos)
	# Thick tongue line
	draw_line(local_origin, Vector2.ZERO, Color(1.0, 0.1, 0.45, 1.0), 10.0)
	# Thinner highlight stripe down the middle
	draw_line(local_origin, Vector2.ZERO, Color(1.0, 0.4, 0.6, 0.7), 4.0)
	# Round sticky tip
	draw_circle(Vector2.ZERO, 12.0, Color(1.0, 0.05, 0.35, 1.0))


func _hit() -> void:
	if is_instance_valid(target) and not target.is_dead:
		target.take_damage(damage)

		if slow_amount > 0.0 and slow_duration > 0.0:
			target.apply_slow(1.0 - slow_amount, slow_duration)
			target.show_hit_reaction()

	if is_splash and splash_radius > 0.0:
		var enemies := get_tree().get_nodes_in_group("enemies")
		for enemy_node in enemies:
			var enemy := enemy_node as BaseEnemy
			if enemy == null or enemy == target or enemy.is_dead:
				continue
			if global_position.distance_to(enemy.global_position) <= splash_radius:
				enemy.take_damage(damage * splash_damage_pct)

	queue_free()
