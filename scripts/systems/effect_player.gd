extends Node

## Centralized one-shot combat effects (autoloaded as EffectPlayer).
## spawn_muzzle_flash / spawn_impact_sparks / screen_shake all auto-free.


func spawn_muzzle_flash(pos: Vector2, dir: Vector2, flash_color: Color, projectile_style: String = "") -> void:
	# D6: shape varies by projectile_style. banana=tight burst, pollen=puff,
	# flask=jagged crack, volleyball=star, tongue=tight ring. Falls back to
	# the original wide cone for unknown styles.
	var host := _get_host()
	if not host:
		return
	var p := CPUParticles2D.new()
	p.global_position = pos
	p.one_shot = true
	p.explosiveness = 0.92
	p.color = flash_color
	p.gravity = Vector2.ZERO
	p.direction = dir.normalized() if dir.length_squared() > 0.0 else Vector2.RIGHT
	match projectile_style:
		"banana":
			p.lifetime = 0.18; p.amount = 6; p.spread = 22.0
			p.initial_velocity_min = 90.0; p.initial_velocity_max = 150.0
			p.scale_amount_min = 4.0; p.scale_amount_max = 7.5
		"pollen":
			p.lifetime = 0.32; p.amount = 14; p.spread = 90.0
			p.initial_velocity_min = 30.0; p.initial_velocity_max = 75.0
			p.scale_amount_min = 4.5; p.scale_amount_max = 9.0
		"flask":
			p.lifetime = 0.24; p.amount = 10; p.spread = 65.0
			p.initial_velocity_min = 50.0; p.initial_velocity_max = 160.0
			p.scale_amount_min = 2.5; p.scale_amount_max = 7.0
		"volleyball":
			p.lifetime = 0.22; p.amount = 12; p.spread = 180.0  # full star burst
			p.initial_velocity_min = 60.0; p.initial_velocity_max = 110.0
			p.scale_amount_min = 4.0; p.scale_amount_max = 6.5
		"tongue":
			p.lifetime = 0.18; p.amount = 7; p.spread = 18.0
			p.initial_velocity_min = 110.0; p.initial_velocity_max = 160.0
			p.scale_amount_min = 3.5; p.scale_amount_max = 5.5
		_:
			p.lifetime = 0.22; p.amount = 8; p.spread = 38.0
			p.initial_velocity_min = 70.0; p.initial_velocity_max = 130.0
			p.scale_amount_min = 3.0; p.scale_amount_max = 7.0
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


## Bursty death effect — replaces the slow on-corpse death tween. 12 particles
## radial with the enemy's tint, plus a quick white flash ring underneath.
func spawn_death_poof(pos: Vector2, tint: Color) -> void:
	var host := _get_host()
	if not host:
		return
	# Colored burst
	var p := CPUParticles2D.new()
	p.global_position = pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.36
	p.amount = 14
	p.direction = Vector2(0.0, -0.4)
	p.spread = 180.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 130.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.5
	p.color = Color(tint.r, tint.g, tint.b, 0.85)
	p.gravity = Vector2(0.0, 220.0)
	host.add_child(p)
	p.emitting = true
	get_tree().create_timer(0.7).timeout.connect(p.queue_free)
	# White flash ring — a tiny ColorRect that scales up + fades.
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.7)
	flash.size = Vector2(36, 36)
	flash.position = pos - flash.size * 0.5
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(flash)
	var tw := flash.create_tween().set_parallel(true)
	tw.tween_property(flash, "scale", Vector2(1.8, 1.8), 0.2)
	tw.tween_property(flash, "color:a", 0.0, 0.2)
	tw.chain().tween_callback(flash.queue_free)


## Gold sparkle ring at tower placement.
func spawn_place_sparkles(pos: Vector2) -> void:
	var host := _get_host()
	if not host:
		return
	var p := CPUParticles2D.new()
	p.global_position = pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.55
	p.amount = 16
	p.direction = Vector2(0.0, -0.6)
	p.spread = 180.0
	p.initial_velocity_min = 70.0
	p.initial_velocity_max = 140.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.5
	p.color = Color(1.0, 0.92, 0.35, 0.9)
	p.gravity = Vector2(0.0, 280.0)
	host.add_child(p)
	p.emitting = true
	get_tree().create_timer(0.9).timeout.connect(p.queue_free)


## Tiny dust puff at enemy feet on each step-down (ROADMAP #13).
func spawn_step_dust(pos: Vector2) -> void:
	var host := _get_host()
	if not host:
		return
	var p := CPUParticles2D.new()
	p.global_position = pos
	p.one_shot = true
	p.explosiveness = 0.85
	p.lifetime = 0.22
	p.amount = 4
	p.direction = Vector2(0.0, -0.3)
	p.spread = 70.0
	p.initial_velocity_min = 12.0
	p.initial_velocity_max = 28.0
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.5
	p.color = Color(0.72, 0.65, 0.5, 0.6)
	p.gravity = Vector2(0.0, 80.0)
	host.add_child(p)
	p.emitting = true
	get_tree().create_timer(0.35).timeout.connect(p.queue_free)


## Briefly jitters the game scene's position (HUD CanvasLayer is unaffected).
func screen_shake(amplitude: float, duration: float) -> void:
	var scene := get_tree().current_scene
	if not (scene is Node2D):
		return
	var n := scene as Node2D
	# Guard against concurrent shakes stacking onto a mid-shake position:
	# kill any existing shake tween first and restore the true origin
	# before building a new chain. Audit P2 #22.
	if n.has_meta("shake_tween"):
		var prev_tween = n.get_meta("shake_tween")
		if prev_tween != null and prev_tween is Tween and prev_tween.is_valid():
			prev_tween.kill()
	if n.has_meta("shake_origin"):
		n.position = n.get_meta("shake_origin")
	var orig := n.position
	n.set_meta("shake_origin", orig)
	var steps := maxi(4, int(duration * 20.0))
	var step_dur: float = duration / float(steps)
	var tw := n.create_tween()
	n.set_meta("shake_tween", tw)
	for _i in range(steps):
		var offset := Vector2(
			randf_range(-amplitude, amplitude),
			randf_range(-amplitude, amplitude)
		)
		tw.tween_property(n, "position", orig + offset, step_dur)
	tw.tween_property(n, "position", orig, step_dur)
	tw.tween_callback(func():
		if n.has_meta("shake_origin"):
			n.remove_meta("shake_origin")
		if n.has_meta("shake_tween"):
			n.remove_meta("shake_tween"))


func _get_host() -> Node:
	var tree := get_tree()
	return tree.current_scene if tree else null
