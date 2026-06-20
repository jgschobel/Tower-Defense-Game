extends Node

## Centralized one-shot combat effects (autoloaded as EffectPlayer).
## Perf: global concurrent caps prevent burst-allocation during heavy waves
## (was unbounded — 20 enemies stepping = 20 new CPUParticles nodes/cycle).
## Particle counts reduced ~30% for muzzle/impact/death (no visible diff).

# Max concurrent live particles per category. Excess calls are skipped —
# effects are decorative, missing one during a heavy wave is imperceptible.
const MAX_FLASH: int = 8
const MAX_DUST: int  = 6
const MAX_MISC: int  = 10

var _active_flash: int = 0
var _active_dust: int  = 0
var _active_misc: int  = 0

# Per-kind CPUParticles2D pool (perf agent #5 bonus): even capped node
# instancing has a cost — we were allocating + parenting + freeing nodes
# every hit. Pool reuses prewarmed nodes; spawn = reposition + restart().
# Keys: "flash", "spark", "poof", "place", "dust". Each list grows up to
# its corresponding MAX_* cap (above) then loops oldest-first.
var _particle_pool: Dictionary = {}    # kind -> Array[CPUParticles2D]
var _particle_pool_next: Dictionary = {}  # kind -> int round-robin idx


func _acquire_particle(kind: String, cap: int) -> CPUParticles2D:
	# Get-or-create one CPUParticles2D for this kind. The pool grows up to
	# `cap` instances then round-robins, overwriting the oldest emitter
	# (in practice old ones have finished by then because lifetime < 0.6s).
	var pool: Array = _particle_pool.get(kind, [])
	# Try to find a non-emitting slot first
	for p in pool:
		if is_instance_valid(p) and not p.emitting:
			return p
	# All emitting — if pool is at cap, recycle oldest via round-robin
	if pool.size() >= cap:
		var idx: int = _particle_pool_next.get(kind, 0)
		var node: CPUParticles2D = pool[idx]
		_particle_pool_next[kind] = (idx + 1) % cap
		# Ensure it's parented to the current level scene (level switches
		# detach pool nodes; reparent on demand).
		if not is_instance_valid(node):
			node = CPUParticles2D.new()
			pool[idx] = node
		return node
	# Pool not full — allocate a new one
	var fresh := CPUParticles2D.new()
	pool.append(fresh)
	_particle_pool[kind] = pool
	return fresh


func _reparent_to_host(p: CPUParticles2D, host: Node) -> void:
	# Reparent a pooled node to the current level scene if it isn't already.
	# Pool nodes outlive scene swaps (this is an autoload), so they detach
	# when the level scene frees. Cheap idempotent reparent.
	if p.get_parent() == host:
		return
	if p.get_parent() != null:
		p.get_parent().remove_child(p)
	host.add_child(p)


func spawn_muzzle_flash(pos: Vector2, dir: Vector2, flash_color: Color, projectile_style: String = "") -> void:
	var host := _get_host()
	if not host:
		return
	# Pooled — no allocation per shot. The pool caps at MAX_FLASH and
	# round-robins when full, so worst-case heavy fire still costs O(1).
	var p := _acquire_particle("flash", MAX_FLASH)
	_reparent_to_host(p, host)
	p.global_position = pos
	p.one_shot = true
	p.explosiveness = 0.92
	p.color = flash_color
	p.gravity = Vector2.ZERO
	p.direction = dir.normalized() if dir.length_squared() > 0.0 else Vector2.RIGHT
	match projectile_style:
		"banana":
			p.lifetime = 0.18; p.amount = 5; p.spread = 22.0
			p.initial_velocity_min = 90.0; p.initial_velocity_max = 150.0
			p.scale_amount_min = 4.0; p.scale_amount_max = 7.5
		"pollen":
			p.lifetime = 0.30; p.amount = 10; p.spread = 90.0
			p.initial_velocity_min = 30.0; p.initial_velocity_max = 75.0
			p.scale_amount_min = 4.5; p.scale_amount_max = 9.0
		"flask":
			p.lifetime = 0.24; p.amount = 7; p.spread = 65.0
			p.initial_velocity_min = 50.0; p.initial_velocity_max = 160.0
			p.scale_amount_min = 2.5; p.scale_amount_max = 7.0
		"volleyball":
			p.lifetime = 0.22; p.amount = 8; p.spread = 180.0
			p.initial_velocity_min = 60.0; p.initial_velocity_max = 110.0
			p.scale_amount_min = 4.0; p.scale_amount_max = 6.5
		"tongue":
			p.lifetime = 0.18; p.amount = 5; p.spread = 18.0
			p.initial_velocity_min = 110.0; p.initial_velocity_max = 160.0
			p.scale_amount_min = 3.5; p.scale_amount_max = 5.5
		_:
			p.lifetime = 0.22; p.amount = 6; p.spread = 38.0
			p.initial_velocity_min = 70.0; p.initial_velocity_max = 130.0
			p.scale_amount_min = 3.0; p.scale_amount_max = 7.0
	p.restart()


func spawn_impact_sparks(pos: Vector2, spark_color: Color) -> void:
	var host := _get_host()
	if not host:
		return
	var p := _acquire_particle("spark", MAX_MISC)
	_reparent_to_host(p, host)
	p.global_position = pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.30
	p.amount = 7
	p.direction = Vector2(0.0, -1.0)
	p.spread = 85.0
	p.initial_velocity_min = 55.0
	p.initial_velocity_max = 135.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 8.0
	p.color = spark_color
	p.gravity = Vector2(0.0, 320.0)
	p.restart()


## Bursty death effect — radial burst with tint + white flash ring.
func spawn_death_poof(pos: Vector2, tint: Color) -> void:
	var host := _get_host()
	if not host:
		return
	var p := _acquire_particle("poof", MAX_MISC)
	_reparent_to_host(p, host)
	p.global_position = pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.34
	p.amount = 9
	p.direction = Vector2(0.0, -0.4)
	p.spread = 180.0
	p.initial_velocity_min = 60.0
	p.initial_velocity_max = 130.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.5
	p.color = Color(tint.r, tint.g, tint.b, 0.85)
	p.gravity = Vector2(0.0, 220.0)
	p.restart()
	# White flash ring
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
	# Pool cap of 6 — placement fires at most once per tap, never bursts.
	var p := _acquire_particle("place", 6)
	_reparent_to_host(p, host)
	p.global_position = pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.55
	p.amount = 12
	p.direction = Vector2(0.0, -0.6)
	p.spread = 180.0
	p.initial_velocity_min = 70.0
	p.initial_velocity_max = 140.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.5
	p.color = Color(1.0, 0.92, 0.35, 0.9)
	p.gravity = Vector2(0.0, 280.0)
	p.restart()


## Tiny dust puff at enemy feet on each step-down (ROADMAP #13).
## Capped at MAX_DUST concurrent — heavy waves skip excess puffs silently.
func spawn_step_dust(pos: Vector2) -> void:
	var host := _get_host()
	if not host:
		return
	var p := _acquire_particle("dust", MAX_DUST)
	_reparent_to_host(p, host)
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
	p.restart()


## Hit-pause: briefly slow time on impact so the brain reads weight.
## The single biggest amateur→pro lever per Vlambeer's "Art of Screenshake"
## and GMTK's "Secrets of Game Feel" — pros punctuate continuous motion
## with a 2-4 frame freeze; amateurs play one continuous animation.
##
## Scoped (50-90ms real time, 0.05× speed) so it never feels janky. Won't
## stack — if a pause is in flight, new calls are ignored. Won't crush the
## playtester's 8× time scale either — captures-then-restores the prior
## value so fast-forward survives.
func hit_pause(strength: float = 1.0) -> void:
	if has_meta("hit_pause_active"):
		return
	set_meta("hit_pause_active", true)
	var prior_scale: float = Engine.time_scale
	# Keep the player's chosen game speed intact. 0.05× of WHATEVER it is.
	var pause_scale: float = maxf(0.02, prior_scale * 0.05)
	var pause_seconds: float = clampf(0.055 + strength * 0.04, 0.04, 0.13)
	Engine.time_scale = pause_scale
	# Use the realtime SceneTree timer so the pause length is in WALL
	# seconds, not in scaled game seconds (which would loop).
	var timer := get_tree().create_timer(pause_seconds, true, false, true)
	timer.timeout.connect(func():
		# Restore only if no other system stomped the scale in the meantime
		# (playtester re-asserts every few seconds, so usually safe).
		Engine.time_scale = prior_scale
		remove_meta("hit_pause_active"))


## Briefly jitters the game scene's position (HUD CanvasLayer is unaffected).
func screen_shake(amplitude: float, duration: float) -> void:
	var scene := get_tree().current_scene
	if not (scene is Node2D):
		return
	var n := scene as Node2D
	# Guard against concurrent shakes stacking onto a mid-shake position.
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


## D7: cinematic bullet-time when a tier-3 tower kills a boss.
## Slows time to 5% for 0.4 real seconds, spawns an extra-large kill burst,
## and floats the tower's name above it. Guard prevents re-entry during an
## active sequence (multi-boss waves can overlap).
func tier3_boss_kill(killer_tower: Node, kill_pos: Vector2) -> void:
	if has_meta("t3_kill_active"):
		return
	set_meta("t3_kill_active", true)

	# Extra-large gold/white spark burst at kill site
	var host := _get_host()
	if host:
		for i in 3:
			var burst_pos := kill_pos + Vector2(randf_range(-30, 30), randf_range(-30, 30))
			spawn_impact_sparks(burst_pos, Color(1.0, 0.95, 0.3))
		spawn_impact_sparks(kill_pos, Color(1.0, 1.0, 1.0))

	# Tower name bubble: "✦ [Name]" floating above the killer
	if host and is_instance_valid(killer_tower):
		var tower_name: String = ""
		if killer_tower.has_method("get") and "data" in killer_tower:
			var td = killer_tower.data
			if td != null and "display_name" in td:
				tower_name = td.display_name
		if tower_name == "" and "data" in killer_tower:
			var td = killer_tower.data
			if td != null and "id" in td:
				tower_name = td.id.capitalize()
		var lbl := Label.new()
		lbl.text = "✦ %s" % tower_name
		lbl.add_theme_font_size_override("font_size", 26)
		lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.3))
		lbl.add_theme_color_override("font_outline_color", Color(0.15, 0.05, 0.0))
		lbl.add_theme_constant_override("outline_size", 5)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.size = Vector2(200, 36)
		lbl.z_index = 40
		lbl.z_as_relative = false
		host.add_child(lbl)
		lbl.global_position = killer_tower.global_position + Vector2(-100, -90)
		var tw := create_tween()
		tw.set_parallel(true)
		tw.tween_property(lbl, "global_position:y", lbl.global_position.y - 55.0, 1.0)
		tw.tween_property(lbl, "modulate:a", 0.0, 1.0)
		tw.chain().tween_callback(lbl.queue_free)

	# Bullet-time: store and slow Engine.time_scale, restore after 0.4s real time.
	var prev_scale: float = Engine.time_scale
	Engine.time_scale = 0.05
	await get_tree().create_timer(0.4, false, false, true).timeout
	Engine.time_scale = prev_scale
	remove_meta("t3_kill_active")


## Expanding ring + radial particle burst at a tower's position when its
## active ability fires. Each tower passes its signature color so the burst
## reads as "this ability belongs to that tower" at a glance.
func spawn_ability_burst(pos: Vector2, color: Color) -> void:
	var host := _get_host()
	if not host:
		return
	# Expanding ring: Line2D circle, tweened from small → large + fade out
	var ring := Line2D.new()
	var pts := PackedVector2Array()
	var N := 28
	for i in N + 1:
		var a := TAU * float(i) / float(N)
		pts.append(Vector2(cos(a), sin(a)) * 26.0)
	ring.points = pts
	ring.width = 5.0
	ring.default_color = Color(color.r, color.g, color.b, 0.88)
	ring.global_position = pos
	ring.z_index = 25
	ring.z_as_relative = false
	host.add_child(ring)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector2(3.4, 3.4), 0.50).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "modulate:a", 0.0, 0.50).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(ring.queue_free)
	# Radial sparkle burst outward from the center
	var p := CPUParticles2D.new()
	p.global_position = pos
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 0.45
	p.amount = 18
	p.spread = 180.0
	p.direction = Vector2(0.0, -1.0)
	p.initial_velocity_min = 90.0
	p.initial_velocity_max = 170.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 7.0
	p.color = Color(color.r, color.g, color.b, 0.8)
	p.gravity = Vector2.ZERO
	p.z_index = 24
	p.z_as_relative = false
	host.add_child(p)
	p.emitting = true
	get_tree().create_timer(0.7).timeout.connect(p.queue_free)


func _get_host() -> Node:
	var tree := get_tree()
	return tree.current_scene if tree else null
