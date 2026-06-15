extends Node2D

## JoJo's chemical acid pool — lingers on the ground after a flask
## impact and ticks DoT damage on any enemy that walks through.

var duration: float = 3.0
var damage_per_tick: float = 4.0
var tick_interval: float = 0.5
var radius: float = 70.0
var damage_type: int = 1  # magic
var source_tower = null  # set by spawning projectile for kill attribution (#928)

var _elapsed: float = 0.0
var _tick_accum: float = 0.0


func _process(delta: float) -> void:
	_elapsed += delta
	_tick_accum += delta

	# Tick damage to enemies inside radius
	if _tick_accum >= tick_interval:
		_tick_accum -= tick_interval
		_tick_damage()

	# Fade + expire
	queue_redraw()
	if _elapsed >= duration:
		queue_free()


func _tick_damage() -> void:
	# Duck-typed: BaseEnemy class_name cannot be referenced here because this
	# script is preloaded by base_projectile.gd at parse time, and ProjectilePool
	# (autoload #9) loads base_projectile.tscn before EnemyPool (autoload #10)
	# has registered BaseEnemy. Any `as BaseEnemy` / `: BaseEnemy` ref in this
	# chain would parse-fail in headless CI, strip the script from the .tscn,
	# and cause every projectile to spawn as a bare Area2D (see #567, #595, #605).
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy_node in enemies:
		if enemy_node == null or not is_instance_valid(enemy_node):
			continue
		if enemy_node.get("is_dead"):
			continue
		if global_position.distance_to(enemy_node.global_position) <= radius:
			var was_alive: bool = not enemy_node.is_dead
			enemy_node.take_damage(damage_per_tick, damage_type)
			# Credit acid-pool kills to source tower so kill counters match
			# GameManager.level_kills (fixes attribution gap, issue #928).
			if was_alive and enemy_node.is_dead and source_tower != null and is_instance_valid(source_tower):
				if "kill_count" in source_tower:
					source_tower.kill_count += 1
				if "wave_kill_count" in source_tower:
					source_tower.wave_kill_count += 1


func _draw() -> void:
	var t := _elapsed / duration  # 0..1 over lifetime
	var alpha := 0.65 * (1.0 - t * 0.5)  # fade from 0.65 to 0.32
	# Outer hazy blob
	draw_circle(Vector2.ZERO, radius, Color(0.2, 0.85, 0.25, alpha * 0.45))
	# Inner pool
	draw_circle(Vector2.ZERO, radius * 0.7, Color(0.35, 1.0, 0.35, alpha * 0.75))
	# Bubbling specks — subtly animated
	var bubble_t := float(Time.get_ticks_msec()) * 0.002
	for i in 6:
		var a: float = (float(i) / 6.0) * TAU + bubble_t * 0.5
		var r: float = radius * (0.3 + 0.5 * sin(bubble_t + float(i)))
		var p: Vector2 = Vector2(cos(a), sin(a)) * r
		draw_circle(p, 4.0, Color(0.6, 1.0, 0.5, alpha))
