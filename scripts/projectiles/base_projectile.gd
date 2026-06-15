extends Area2D

## Projectile fired by towers. Tracks a target enemy and deals damage on hit.
## `style` drives the visual: each tower gets a distinct look (only Lemurius
## throws bananas). `leaves_ground_pool` spawns a lingering acid pool (JoJo).

var target = null
var damage: float = 0.0
var damage_type: int = 0
var speed: float = 500.0
var is_splash: bool = false
var splash_radius: float = 0.0
var splash_damage_pct: float = 0.5
var slow_amount: float = 0.0
var slow_duration: float = 0.0
var color: Color = Color.YELLOW
# Visual upgrade tier (0=base, 1–3 = progressively enhanced look)
var tier: int = 0

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

# Pierce (ROADMAP #38, Lemurius). remaining_pierce > 0 means the
# projectile keeps flying after each hit, chaining to the next
# unhit enemy within a small detection radius until the budget
# runs out or no eligible targets remain.
var remaining_pierce: int = 0
var _pierced_enemies: Array = []

# Amösius pull (ROADMAP #38). > 0 = on hit, reel enemy back this
# fraction of the path via BaseEnemy.pull_back().
var pull_path_fraction: float = 0.0

# Styles that render themselves via _draw() — the Sprite2D is hidden for
# these. Hoisted to module scope so adding a new style only requires one
# edit instead of three (audit P2 drift risk).
const DRAWN_STYLES: Array = ["tongue", "volleyball", "flask", "pollen"]


func setup(
	origin: Vector2,
	p_target: Node2D,
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
	p_pool_radius: float = 70.0,
	p_tier: int = 0
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
	tier = p_tier

	if target:
		_last_target_pos = target.global_position

	_is_tongue = style == "tongue"

	# Refresh sprite visibility based on current style — pooled projectiles
	# only run _ready() once (at pool prewarm with style=banana), so on
	# reuse we need to update here or the default sprite leaks through on
	# styles that draw themselves.
	var drawn_styles := DRAWN_STYLES
	if has_node("Sprite2D"):
		$Sprite2D.visible = not (style in drawn_styles)

	# Reset spin per style
	match style:
		"tongue":   _spin_speed = 0.0
		"flask":    _spin_speed = 8.0
		"pollen":   _spin_speed = 0.0
		"volleyball": _spin_speed = 10.0
		_:          _spin_speed = 12.0

	# Banana (sprite-based) tier skins: progressively larger + golden/khaki tint
	if style not in DRAWN_STYLES and has_node("Sprite2D"):
		var sp: Sprite2D = $Sprite2D as Sprite2D
		if sp:
			match tier:
				0: sp.scale = Vector2.ONE;          sp.modulate = Color.WHITE
				1: sp.scale = Vector2(1.25, 1.25);  sp.modulate = Color(1.0, 1.0, 0.75, 1.0)
				2: sp.scale = Vector2(1.5, 1.5);    sp.modulate = Color(0.95, 0.88, 0.5, 1.0)
				_: sp.scale = Vector2(1.75, 1.75);  sp.modulate = Color(0.68, 0.62, 0.32, 1.0)


func _ready() -> void:
	# Hide the default sprite for styles that draw themselves via _draw()
	var drawn_styles := DRAWN_STYLES
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
			if global_position.distance_to(_last_target_pos) < maxf(15.0, speed * delta):
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
	var drawn_styles := DRAWN_STYLES
	if style in drawn_styles:
		queue_redraw()
	else:
		if has_node("Sprite2D"):
			$Sprite2D.rotation += _spin_speed * delta

	if global_position.distance_to(_last_target_pos) < maxf(15.0, speed * delta):
		_hit()


func _draw() -> void:
	var t: float = float(Time.get_ticks_msec()) / 1000.0
	match style:
		"tongue":
			# Amösius tongue — tier 0: hot pink; tier 1: bright red; tier 2: deep red; tier 3: crimson thick
			var local_origin := to_local(_origin_pos)
			var thickness: float = 10.0 + tier * 3.5
			var tip_r: float = 12.0 + tier * 3.5
			var line_c: Color
			var tip_c: Color
			match tier:
				0: line_c = Color(1.0, 0.1, 0.45, 1.0); tip_c = Color(1.0, 0.05, 0.35, 1.0)
				1: line_c = Color(1.0, 0.05, 0.2, 1.0);  tip_c = Color(1.0, 0.0, 0.15, 1.0)
				2: line_c = Color(0.85, 0.0, 0.05, 1.0); tip_c = Color(0.9, 0.0, 0.05, 1.0)
				_: line_c = Color(0.7, 0.0, 0.0, 1.0);   tip_c = Color(0.75, 0.0, 0.0, 1.0)
			draw_line(local_origin, Vector2.ZERO, line_c, thickness)
			draw_line(local_origin, Vector2.ZERO, Color(line_c.r, line_c.g + 0.3, line_c.b + 0.2, 0.6), thickness * 0.38)
			draw_circle(Vector2.ZERO, tip_r, tip_c)
		"volleyball":
			# Cordula's volleyball — tier 0: pink stripes; tier 1: gold; tier 2: rainbow; tier 3: rainbow+larger
			var r: float = 12.0 + tier * 3.0
			draw_circle(Vector2.ZERO, r, Color(1.0, 1.0, 1.0, 1.0))
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, Color(0.15, 0.15, 0.2, 1), 2.0)
			var stripe_colors: Array
			match tier:
				0: stripe_colors = [Color(0.9, 0.2, 0.5, 1), Color(0.9, 0.2, 0.5, 1), Color(0.9, 0.2, 0.5, 1)]
				1: stripe_colors = [Color(1.0, 0.75, 0.0, 1), Color(0.95, 0.6, 0.0, 1), Color(1.0, 0.85, 0.1, 1), Color(0.9, 0.65, 0.0, 1)]
				2: stripe_colors = [Color(1, 0.2, 0.2, 1), Color(1, 0.6, 0, 1), Color(0.2, 0.9, 0.2, 1), Color(0.2, 0.45, 1, 1), Color(0.7, 0.15, 1, 1)]
				_: stripe_colors = [Color(1, 0.15, 0.15, 1), Color(1, 0.55, 0, 1), Color(1, 1, 0, 1), Color(0.15, 0.9, 0, 1), Color(0, 0.5, 1, 1), Color(0.6, 0, 1, 1)]
			for i in stripe_colors.size():
				var a: float = (float(i) / stripe_colors.size()) * TAU + t * 4.0
				var p: Vector2 = Vector2(cos(a), sin(a)) * (r * 0.65)
				draw_circle(p, 2.5 + tier * 0.5, stripe_colors[i])
		"flask":
			# JoJo's flask — tier 0: green; tier 1: cyan acid; tier 2: purple mystic; tier 3: crimson bio
			var spin: float = t * _spin_speed
			var sc: float = 1.0 + tier * 0.22
			draw_set_transform(Vector2.ZERO, spin, Vector2(sc, sc))
			var glass_c: Color
			var liquid_c: Color
			match tier:
				0: glass_c = Color(0.85, 0.95, 1.0, 0.5); liquid_c = Color(0.3, 1.0, 0.4, 0.9)
				1: glass_c = Color(0.7, 1.0, 1.0, 0.5);   liquid_c = Color(0.0, 0.9, 0.9, 0.9)
				2: glass_c = Color(0.88, 0.72, 1.0, 0.5);  liquid_c = Color(0.68, 0.1, 1.0, 0.9)
				_: glass_c = Color(1.0, 0.72, 0.72, 0.5);  liquid_c = Color(0.88, 0.05, 0.08, 0.9)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-8, -10), Vector2(8, -10),
				Vector2(10, 6), Vector2(0, 12), Vector2(-10, 6)
			]), glass_c)
			draw_colored_polygon(PackedVector2Array([
				Vector2(-7, 0), Vector2(7, 0),
				Vector2(8, 5), Vector2(0, 11), Vector2(-8, 5)
			]), liquid_c)
			draw_line(Vector2(-3, -10), Vector2(-3, -15), Color(0.5, 0.7, 0.8, 1), 1.5)
			draw_line(Vector2(3, -10), Vector2(3, -15), Color(0.5, 0.7, 0.8, 1), 1.5)
			draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		"pollen":
			# Kühne's pollen — tier 0: gold/violet; tier 1: icy aqua; tier 2: fire orange; tier 3: cosmic white
			var pulse: float = 1.0 + 0.2 * sin(t * 10.0)
			var base_r: float = (8.0 + tier * 3.0) * pulse
			var inner_r: float = (5.0 + tier * 2.0) * pulse
			var orbit_r: float = 11.0 + tier * 4.0
			var dot_count: int = 4 + tier * 2
			var orbit_speed: float = 3.0 + tier * 1.5
			var outer_c: Color
			var inner_c: Color
			var orbit_c: Color
			match tier:
				0: outer_c = Color(0.95, 0.85, 0.3, 0.6);  inner_c = Color(1.0, 0.95, 0.5, 1.0);  orbit_c = Color(0.7, 0.3, 0.9, 0.8)
				1: outer_c = Color(0.3, 0.95, 1.0, 0.6);   inner_c = Color(0.7, 1.0, 1.0, 1.0);   orbit_c = Color(0.1, 0.7, 1.0, 0.9)
				2: outer_c = Color(1.0, 0.55, 0.1, 0.7);   inner_c = Color(1.0, 0.85, 0.2, 1.0);  orbit_c = Color(1.0, 0.25, 0.0, 0.9)
				_: outer_c = Color(0.92, 0.92, 1.0, 0.85); inner_c = Color(1.0, 1.0, 1.0, 1.0);   orbit_c = Color(0.5, 0.25, 1.0, 1.0)
			draw_circle(Vector2.ZERO, base_r, outer_c)
			draw_circle(Vector2.ZERO, inner_r, inner_c)
			for i in dot_count:
				var a2: float = (float(i) / dot_count) * TAU + t * orbit_speed
				var p2: Vector2 = Vector2(cos(a2), sin(a2)) * orbit_r
				draw_circle(p2, 2.5 + tier * 0.5, orbit_c)
		_:
			pass  # "banana" uses default sprite2d (already textured)


func _hit() -> void:
	if is_instance_valid(target) and not target.is_dead:
		# Capture is_dead BEFORE damage so we can credit the source tower
		# if this hit was the killing blow.
		var was_alive: bool = not target.is_dead
		var _src: Node = get_meta("source_tower") as Node if has_meta("source_tower") else null
		target.take_damage(damage, damage_type, _src)
		target.show_hit_reaction()
		_pierced_enemies.append(target)
		# Impact sparks at the hit position, tinted by this projectile's color
		if EffectPlayer:
			EffectPlayer.spawn_impact_sparks(global_position, color)

		if slow_amount > 0.0 and slow_duration > 0.0:
			target.apply_slow(1.0 - slow_amount, slow_duration)

		if pull_path_fraction > 0.0 and target.has_method("pull_back"):
			target.pull_back(pull_path_fraction)

		# If the target just died, credit the kill to the owning tower
		if was_alive and target.is_dead and has_meta("source_tower"):
			var src = get_meta("source_tower")
			if src != null and is_instance_valid(src) and "kill_count" in src:
				src.kill_count += 1
				if "wave_kill_count" in src:
					src.wave_kill_count += 1

	# Pierce (ROADMAP #38): if budget remains, pick a nearby unhit enemy
	# and keep flying instead of releasing.
	if remaining_pierce > 0:
		remaining_pierce -= 1
		var next = _find_pierce_target()
		if next != null:
			target = next
			_last_target_pos = next.global_position
			_direction = (next.global_position - global_position).normalized()
			return

	if is_splash and splash_radius > 0.0:
		var src_tower = get_meta("source_tower") if has_meta("source_tower") else null
		var enemies := get_tree().get_nodes_in_group("enemies")
		for enemy_node in enemies:
			var enemy = enemy_node
			if not is_instance_valid(enemy) or enemy == target or enemy.get("is_dead"):
				continue
			# F10: camo enemies are invisible to towers without detection.
			# Splash from a non-detector tower must not reveal/damage camo.
			if enemy.data and enemy.data.is_camo:
				if src_tower == null or not src_tower.has_method("has_camo_detection") or not src_tower.has_camo_detection():
					continue
			if global_position.distance_to(enemy.global_position) <= splash_radius:
				var splash_was_alive: bool = not enemy.is_dead
				enemy.take_damage(damage * splash_damage_pct, damage_type, src_tower)
				# Credit splash kills back to the owning tower too — was
				# previously only crediting the direct-hit target. Agent-audit
				# BUG #2 (JoJo's kill total was artificially low).
				if splash_was_alive and enemy.is_dead and src_tower != null and is_instance_valid(src_tower) and "kill_count" in src_tower:
					src_tower.kill_count += 1

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


func _spawn_acid_pool() -> void:
	# Load at runtime (not parse-time) so this script has no class-level
	# dependency on acid_pool.gd. This eliminates the parse-order trap where
	# ProjectilePool (#9) loads base_projectile.gd at startup and a compile-time
	# preload of acid_pool.gd would pull in unregistered class names from
	# autoloads that haven't initialised yet (#567, #595, #605, #609).
	var tree := get_tree()
	if tree == null:
		return
	var host: Node = tree.current_scene
	if host == null:
		return
	var acid_script = load("res://scripts/projectiles/acid_pool.gd")
	if acid_script == null:
		return
	var pool: Node2D = acid_script.new()
	pool.global_position = global_position
	pool.duration = pool_duration
	pool.damage_per_tick = pool_dmg_per_tick
	pool.radius = pool_radius
	pool.damage_type = damage_type
	host.add_child(pool)


func _find_pierce_target() -> Node2D:
	var best: Node2D = null
	var best_dist: float = 220.0  # cap how far pierce-chains reach
	for enemy_node in get_tree().get_nodes_in_group("enemies"):
		var enemy: Node2D = enemy_node as Node2D
		if enemy == null or enemy.get("is_dead") or enemy in _pierced_enemies:
			continue
		var d: float = global_position.distance_to(enemy.global_position)
		if d < best_dist:
			best_dist = d
			best = enemy
	return best


func reset_for_pool() -> void:
	target = null
	damage = 0.0
	damage_type = 0
	tier = 0
	remaining_pierce = 0
	_pierced_enemies.clear()
	pull_path_fraction = 0.0
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
	# Clear the source_tower meta so a freshly-acquired projectile can't
	# briefly carry the previous owner and mis-credit a kill between
	# acquire() and setup(). Agent-audit BUG #1.
	if has_meta("source_tower"):
		remove_meta("source_tower")
