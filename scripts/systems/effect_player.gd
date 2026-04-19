extends Node

## Centralized one-shot combat effects (autoloaded as EffectPlayer).
## spawn_muzzle_flash / spawn_impact_sparks / screen_shake all auto-free.


func spawn_muzzle_flash(pos: Vector2, dir: Vector2, flash_color: Color) -> void:
	var host := _get_host()
	if not host:
		return
	var p := CPUParticles2D.new()
	p.global_position = pos
	p.one_shot = true
	p.explosiveness = 0.92
	p.lifetime = 0.22
	p.amount = 8
	p.direction = dir.normalized() if dir.length_squared() > 0.0 else Vector2.RIGHT
	p.spread = 38.0
	p.initial_velocity_min = 70.0
	p.initial_velocity_max = 130.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 7.0
	p.color = flash_color
	p.gravity = Vector2.ZERO
	host.add_child(p)
	p.emitting = true
	get_tree().create_timer(0.5).timeout.connect(p.queue_free)


func spawn_impact_sparks(pos: Vector2, spark_color: Color) -> void:
	var host := _get_host()
	if not host:
		return
	var p := CPUParticles2D.new()
	p.global_position = pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.32
	p.amount = 10
	p.direction = Vector2(0.0, -1.0)
	p.spread = 85.0
	p.initial_velocity_min = 55.0
	p.initial_velocity_max = 135.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 8.0
	p.color = spark_color
	p.gravity = Vector2(0.0, 320.0)
	host.add_child(p)
	p.emitting = true
	get_tree().create_timer(0.6).timeout.connect(p.queue_free)


## Briefly jitters the game scene's position (HUD CanvasLayer is unaffected).
func screen_shake(amplitude: float, duration: float) -> void:
	var scene := get_tree().current_scene
	if not (scene is Node2D):
		return
	var n := scene as Node2D
	var orig := n.position
	var steps := maxi(4, int(duration * 20.0))
	var step_dur: float = duration / float(steps)
	var tw := n.create_tween()
	for _i in range(steps):
		var offset := Vector2(
			randf_range(-amplitude, amplitude),
			randf_range(-amplitude, amplitude)
		)
		tw.tween_property(n, "position", orig + offset, step_dur)
	tw.tween_property(n, "position", orig, step_dur)


func _get_host() -> Node:
	var tree := get_tree()
	return tree.current_scene if tree else null
