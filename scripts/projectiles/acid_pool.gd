class_name AcidPool
extends Node2D

## JoJo's chemical acid pool — lingers on the ground after a flask
## impact and ticks DoT damage on any enemy that walks through.

var duration: float = 3.0
var damage_per_tick: float = 4.0
var tick_interval: float = 0.5
var radius: float = 70.0
var damage_type: int = 1  # magic

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
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy_node in enemies:
		var enemy := enemy_node as BaseEnemy
		if enemy == null or enemy.is_dead:
			continue
		if global_position.distance_to(enemy.global_position) <= radius:
			enemy.take_damage(damage_per_tick, damage_type)


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
