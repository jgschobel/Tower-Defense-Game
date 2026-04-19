class_name BaseEnemy
extends PathFollow2D

## Base enemy that follows a Path2D. Attach to a Path2D node.
## Loses health from tower projectiles, awards gold on death.

signal enemy_died(enemy: Node)
signal enemy_reached_end(enemy: Node)

@export var data: EnemyData

var health: float = 100.0
var max_health: float = 100.0
var move_speed: float = 80.0
var armor: float = 0.0
var gold_reward: int = 10
var slow_factor: float = 1.0
var _walk_phase: float = 0.0
var _base_v_offset: float = 0.0
var slow_timer: float = 0.0
var is_dead: bool = false
var _health_bar_tween: Tween = null

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: ProgressBar = $HealthBar

var heal_timer_node: Timer = null


func _ready() -> void:
	if has_node("HealTimer"):
		heal_timer_node = $HealTimer
	if data:
		_apply_data()
	_update_visual()
	# Visual-only offset so enemies that visually catch up at path bends
	# don't collapse into an indistinguishable blob (issue #48). Applied
	# to PathFollow2D's v_offset so each enemy is drawn ~±8px
	# perpendicular to the path without affecting gameplay progress.
	v_offset = randf_range(-10.0, 10.0)
	h_offset = randf_range(-6.0, 6.0)
	_base_v_offset = v_offset
	_walk_phase = randf() * TAU  # desync bobs across enemies


func _apply_data() -> void:
	max_health = data.max_health
	health = max_health
	move_speed = data.move_speed
	armor = data.armor
	gold_reward = data.gold_reward

	if heal_timer_node:
		# Always stop first — if this enemy was reused from pool, the
		# timer may still be live from its previous life. For non-
		# healer reuse we want it OFF entirely.
		heal_timer_node.stop()
		if data.heals_nearby:
			heal_timer_node.wait_time = 1.0
			heal_timer_node.start()


func _process(delta: float) -> void:
	if is_dead:
		return

	# Handle slow debuff
	if slow_timer > 0.0:
		slow_timer -= delta
		if slow_timer <= 0.0:
			slow_factor = 1.0
			# Reset tint when slow wears off
			modulate = Color.WHITE

	# Move along path
	var speed := move_speed * slow_factor
	progress += speed * delta

	# Bobbing walk: sine-wave vertical offset gives enemies a "step" feel
	# instead of sliding rigidly along the path. Frequency scales with
	# speed so slow enemies bob slow, fast enemies bob fast.
	_walk_phase += delta * (speed * 0.04)
	# Keep the base v_offset (set at spawn for visual separation) as the
	# midpoint and add the bob on top
	v_offset = _base_v_offset + sin(_walk_phase) * 4.0

	# Healer aura animates via _draw — the pulse is time-driven so 15fps
	# is plenty for a smooth look. Throttle redraw to every ~4th frame.
	# Per-enemy jitter (via instance_id) staggers redraws across the 4
	# bucket phases so L5-L7 waves with 10+ healers don't all repaint
	# on the same frame. ROADMAP PERF #8.
	if data and data.heals_nearby:
		var phase: int = (Engine.get_frames_drawn() + int(get_instance_id())) & 3
		if phase == 0:
			queue_redraw()

	# Check if reached end of path
	if progress_ratio >= 1.0:
		_reached_end()
		return


func take_damage(amount: float, damage_type: int = 0) -> void:
	if is_dead:
		return

	# Damage-type enum (mirrors TowerData.DamageType):
	# 0 = PHYSICAL — full armor reduction
	# 1 = MAGIC    — 70% armor bypass (30% applied)
	# 2 = PURE     — ignore armor entirely
	var effective_armor: float = armor
	match damage_type:
		1: effective_armor = armor * 0.3
		2: effective_armor = 0.0
		_: effective_armor = armor

	var actual_damage := maxf(1.0, amount - effective_armor)
	health -= actual_damage
	_update_health_bar()

	# Show floating damage number, color-coded by type
	_show_damage_number(actual_damage, damage_type)

	# Juice: tiny +1 gold floater on every non-killing hit. Adds dopamine
	# drip between kills. Actual gold is only awarded on kill (_on_killed)
	# — this is purely visual/audio feedback, no economy change.
	if health > 0 and amount > 0:
		_show_mini_pop()

	# Flash white on hit, then restore
	modulate = Color(2.0, 2.0, 2.0)
	var tween := create_tween()
	var restore_color := Color(0.6, 0.7, 1.0) if slow_factor < 1.0 else Color.WHITE
	tween.tween_property(self, "modulate", restore_color, 0.15)

	if health <= 0.0:
		die()


func apply_slow(factor: float, duration: float) -> void:
	slow_factor = factor
	slow_timer = duration
	# Tint blue-ish when slowed (whole node including drawn shapes)
	modulate = Color(0.6, 0.7, 1.0, 1.0)


func show_hit_reaction() -> void:
	# Show a floating angry/sad label above the enemy
	var reaction := Label.new()
	var reactions := [">:(", "AUA!", "HEY!", "STOPP!", "NEI!", "WÄÄH!", "AUTSCH!", "GOPF!"]
	reaction.text = reactions[randi() % reactions.size()]
	reaction.add_theme_font_size_override("font_size", 18)
	reaction.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	reaction.position = Vector2(-15, -50)
	reaction.z_index = 10
	add_child(reaction)

	# Float up and fade out
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(reaction, "position:y", -80.0, 0.8)
	tween.tween_property(reaction, "modulate:a", 0.0, 0.8)
	tween.chain().tween_callback(reaction.queue_free)


func die() -> void:
	if is_dead:
		return
	is_dead = true
	# Stop heal timer immediately — previously ran through the 0.35s
	# death animation, wasting cycles (audit #14)
	if heal_timer_node:
		heal_timer_node.stop()
	CurrencyManager.add_gold(gold_reward)
	GameManager.record_kill()
	_show_gold_earned()
	SfxManager.play_death(data.max_health if data else 100.0)

	# Boss celebration — massive impact spark burst + screen shake
	# + floating "TÜÜFEL GSTÜRZT!" text. Only for boss enemies so
	# small kills don't spam the effects.
	if data and data.id == "boss":
		_celebrate_boss_death()

	# Spawn children on death if configured
	if data and data.spawns_on_death != "" and data.spawn_count > 0:
		_spawn_children()

	enemy_died.emit(self)

	# Death animation with spin and pop
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(self, "scale", Vector2.ZERO, 0.35).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "rotation", randf_range(-1.5, 1.5), 0.35)
	tween.tween_property(self, "modulate:a", 0.0, 0.35)
	tween.chain().tween_callback(_return_to_pool_or_free)


func _reached_end() -> void:
	if is_dead:
		return
	is_dead = true
	GameManager.lose_life()
	enemy_reached_end.emit(self)
	_return_to_pool_or_free()


func _return_to_pool_or_free() -> void:
	# Pool release if available — falls back to queue_free otherwise
	if EnemyPool and EnemyPool.has_method("release"):
		EnemyPool.release(self)
	else:
		queue_free()


func reset_for_pool() -> void:
	# Called by EnemyPool when this enemy is about to be reused.
	# Resets all transient runtime state so the next spawn is clean.
	if data:
		_apply_data()
	is_dead = false
	progress = 0.0
	progress_ratio = 0.0
	slow_factor = 1.0
	slow_timer = 0.0
	modulate = Color.WHITE
	scale = Vector2.ONE
	rotation = 0.0
	# Reapply visual offset for path-bend separation (#48)
	v_offset = randf_range(-10.0, 10.0)
	h_offset = randf_range(-6.0, 6.0)
	_base_v_offset = v_offset
	_walk_phase = randf() * TAU  # desync bobs across enemies
	# Kill any in-flight float labels from the previous life — their
	# tweens were bound to this node and would otherwise keep stale
	# damage numbers / reactions stuck over the reused enemy
	# (observed as "blurry empty text box" during pool reuse).
	for child in get_children():
		if child is Label:
			child.queue_free()
	# Reset health bar visuals
	if health_bar:
		health_bar.visible = false
		health_bar.value = 100.0


func _update_visual() -> void:
	if not sprite:
		return

	# Try to load friend photo
	if data and data.friend_character_id != "":
		var photo := GameManager.get_friend_photo(data.friend_character_id)
		if photo:
			sprite.texture = photo
			sprite.scale = Vector2.ONE * data.scale_factor * 0.5
			return

	# Use custom texture if set
	if data and data.custom_texture:
		sprite.texture = data.custom_texture
		sprite.visible = true
		# Auto-scale based on enemy size
		var max_dim := maxf(data.custom_texture.get_width(), data.custom_texture.get_height())
		var target_size := 50.0 * data.scale_factor
		var s := target_size / max_dim
		sprite.scale = Vector2(s, s)
		return

	# Hide the default icon sprite — we draw food shapes instead
	sprite.visible = false
	# Note: per-enemy name labels were removed — the HUD enemy-intro
	# overlay announces each new enemy type the first time it spawns.
	# Persistent labels were cluttering the map and, after a recent
	# refactor, rendered as empty blurry text boxes.

	queue_redraw()


func _draw() -> void:
	if not data:
		# Fallback circle
		draw_circle(Vector2.ZERO, 15.0, Color.RED)
		return

	# Healer aura — ALWAYS drawn regardless of sprite visibility so that
	# photo-skinned healers also show their heal range. Audit P0 #2:
	# the earlier placement below the `sprite.visible` short-circuit
	# meant custom_texture healers had no visible aura.
	if data.heals_nearby and data.heal_radius > 0.0 and not is_dead:
		var aura_t: float = float(Time.get_ticks_msec()) * 0.002
		var pulse_f: float = 0.85 + 0.15 * sin(aura_t * 3.0)
		var r: float = data.heal_radius * pulse_f
		draw_circle(Vector2.ZERO, r, Color(0.35, 1.0, 0.4, 0.08))
		var ring_points := PackedVector2Array()
		for i in 33:
			var a: float = (float(i) / 32.0) * TAU
			ring_points.append(Vector2(cos(a), sin(a)) * r)
		for i in 32:
			draw_line(ring_points[i], ring_points[i + 1], Color(0.4, 1.0, 0.45, 0.35), 2.0)

	if sprite and sprite.visible:
		return  # Using a real texture, don't draw the body shape

	var s := data.scale_factor
	var c := data.base_color

	# Drop shadow BEHIND the draw so every enemy sits in the scene
	draw_circle(Vector2(0, 12) * s, 12.0 * s, Color(0, 0, 0, 0.35))

	match data.id:
		"basic":
			# Brötli (bread roll) - round golden bun
			draw_circle(Vector2.ZERO, 16.0 * s, c)
			draw_circle(Vector2.ZERO, 12.0 * s, Color(0.9, 0.78, 0.55))
			# Cross on top
			draw_line(Vector2(-6, -6) * s, Vector2(6, 6) * s, Color(0.7, 0.55, 0.3), 2.0)
			draw_line(Vector2(6, -6) * s, Vector2(-6, 6) * s, Color(0.7, 0.55, 0.3), 2.0)
			# Angry eyes
			draw_circle(Vector2(-5, -3) * s, 2.5, Color.WHITE)
			draw_circle(Vector2(5, -3) * s, 2.5, Color.WHITE)
			draw_circle(Vector2(-5, -3) * s, 1.2, Color.BLACK)
			draw_circle(Vector2(5, -3) * s, 1.2, Color.BLACK)
		"swarm":
			# Tofu-Würfli — tiny white cube with nervous eyes
			draw_rect(Rect2(Vector2(-9, -9) * s, Vector2(18, 18) * s), c, true)
			draw_rect(Rect2(Vector2(-9, -9) * s, Vector2(18, 18) * s), Color(0.6, 0.6, 0.5), false, 1.5)
			# Nervous darting eyes (left-biased)
			draw_circle(Vector2(-3, -2) * s, 2.0, Color.WHITE)
			draw_circle(Vector2(3, -2) * s, 2.0, Color.WHITE)
			draw_circle(Vector2(-4, -2) * s, 1.0, Color.BLACK)
			draw_circle(Vector2(2, -2) * s, 1.0, Color.BLACK)
			# Sweat drop for extra panic
			draw_circle(Vector2(6, 2) * s, 1.2, Color(0.5, 0.8, 1.0, 0.8))
		"fast":
			# Toblerone - triangular chocolate bar
			var tri := PackedVector2Array([
				Vector2(0, -18) * s,
				Vector2(-12, 12) * s,
				Vector2(12, 12) * s,
			])
			draw_colored_polygon(tri, c)
			draw_colored_polygon(tri, Color(0.65, 0.4, 0.2), PackedVector2Array(), null)
			# Eyes
			draw_circle(Vector2(-4, 0) * s, 2.0, Color.WHITE)
			draw_circle(Vector2(4, 0) * s, 2.0, Color.WHITE)
			draw_circle(Vector2(-4, 0) * s, 1.0, Color.BLACK)
			draw_circle(Vector2(4, 0) * s, 1.0, Color.BLACK)
		"tank":
			# Cervelat (sausage) - thick oval
			var rect := Rect2(Vector2(-22, -10) * s, Vector2(44, 20) * s)
			draw_rect(rect, c, true)
			# Rounded ends
			draw_circle(Vector2(-22, 0) * s, 10.0 * s, c)
			draw_circle(Vector2(22, 0) * s, 10.0 * s, c)
			# Skin lines
			draw_line(Vector2(-10, -8) * s, Vector2(-10, 8) * s, Color(0.6, 0.35, 0.25), 1.5)
			draw_line(Vector2(10, -8) * s, Vector2(10, 8) * s, Color(0.6, 0.35, 0.25), 1.5)
			# Angry face
			draw_circle(Vector2(-5, -2) * s, 2.5, Color.WHITE)
			draw_circle(Vector2(5, -2) * s, 2.5, Color.WHITE)
			draw_circle(Vector2(-5, -2) * s, 1.2, Color.BLACK)
			draw_circle(Vector2(5, -2) * s, 1.2, Color.BLACK)
		"healer":
			# Rivella bottle - red bottle shape
			draw_rect(Rect2(Vector2(-8, -15) * s, Vector2(16, 30) * s), c, true)
			draw_rect(Rect2(Vector2(-5, -22) * s, Vector2(10, 8) * s), Color(0.8, 0.15, 0.15), true)
			# Label
			draw_rect(Rect2(Vector2(-6, -5) * s, Vector2(12, 10) * s), Color.WHITE, true)
			# Plus sign (healing)
			draw_line(Vector2(0, -3) * s, Vector2(0, 3) * s, Color.RED, 2.0)
			draw_line(Vector2(-3, 0) * s, Vector2(3, 0) * s, Color.RED, 2.0)
		"flying":
			# Fondue pot - round pot with cheese dripping
			draw_circle(Vector2.ZERO, 14.0 * s, c)
			draw_rect(Rect2(Vector2(-16, -4) * s, Vector2(32, 12) * s), Color(0.4, 0.35, 0.3), true)
			# Cheese drips
			draw_circle(Vector2(-8, 10) * s, 4.0 * s, Color(1, 0.9, 0.4))
			draw_circle(Vector2(6, 12) * s, 3.0 * s, Color(1, 0.9, 0.4))
			# Steam
			draw_line(Vector2(-5, -14) * s, Vector2(-7, -22) * s, Color(1, 1, 1, 0.4), 1.5)
			draw_line(Vector2(5, -14) * s, Vector2(7, -22) * s, Color(1, 1, 1, 0.4), 1.5)
		"boss":
			# M-Teufel - big orange M with horns
			draw_circle(Vector2.ZERO, 25.0 * s, c)
			# Horns
			draw_line(Vector2(-12, -20) * s, Vector2(-18, -35) * s, Color(0.8, 0.2, 0), 4.0)
			draw_line(Vector2(12, -20) * s, Vector2(18, -35) * s, Color(0.8, 0.2, 0), 4.0)
			# M letter
			draw_line(Vector2(-10, 8) * s, Vector2(-10, -5) * s, Color.WHITE, 3.0)
			draw_line(Vector2(-10, -5) * s, Vector2(0, 3) * s, Color.WHITE, 3.0)
			draw_line(Vector2(0, 3) * s, Vector2(10, -5) * s, Color.WHITE, 3.0)
			draw_line(Vector2(10, -5) * s, Vector2(10, 8) * s, Color.WHITE, 3.0)
			# Evil eyes
			draw_circle(Vector2(-8, -8) * s, 4.0, Color(1, 1, 0))
			draw_circle(Vector2(8, -8) * s, 4.0, Color(1, 1, 0))
			draw_circle(Vector2(-8, -8) * s, 2.0, Color.RED)
			draw_circle(Vector2(8, -8) * s, 2.0, Color.RED)
		_:
			# Unknown enemy - generic colored circle
			draw_circle(Vector2.ZERO, 15.0 * s, c)
			draw_circle(Vector2(-4, -3), 2.0, Color.WHITE)
			draw_circle(Vector2(4, -3), 2.0, Color.WHITE)
			draw_circle(Vector2(-4, -3), 1.0, Color.BLACK)
			draw_circle(Vector2(4, -3), 1.0, Color.BLACK)


func _get_base_color() -> Color:
	if data:
		return data.base_color
	return Color.RED


func _update_health_bar() -> void:
	if not health_bar:
		return
	health_bar.visible = health < max_health
	var target := (health / max_health) * 100.0
	if _health_bar_tween:
		_health_bar_tween.kill()
	_health_bar_tween = create_tween()
	_health_bar_tween.tween_property(health_bar, "value", target, 0.2)


func _heal_nearby() -> void:
	if not data or not data.heals_nearby or is_dead:
		return
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy_node in enemies:
		if enemy_node == self:
			continue
		var enemy := enemy_node as BaseEnemy
		if enemy == null or enemy.is_dead:
			continue
		# Use path-progress distance, not global — v_offset randomization
		# for visual separation (#48) means global_position is ±10px off
		# the true path position. Progress-distance is the gameplay
		# distance along the shared path (audit #7).
		var progress_delta: float = absf(enemy.progress - progress)
		if progress_delta <= data.heal_radius:
			enemy.health = minf(enemy.max_health, enemy.health + data.heal_amount)


func _spawn_children() -> void:
	if not data or data.spawns_on_death == "" or data.spawn_count <= 0:
		return
	var parent_path := get_parent() as Path2D
	if not parent_path or not parent_path.curve:
		return
	var data_path := "res://resources/enemy_data/%s.tres" % data.spawns_on_death
	if not ResourceLoader.exists(data_path):
		push_warning("[base_enemy] spawns_on_death data missing: %s (skipped)" % data_path)
		return
	var child_data = load(data_path)
	# Bounds-check: if parent died past the end of the path (progress
	# edge cases), spawn children BEHIND current position instead of
	# ahead-off-path where they'd be invisible/unreachable. Audit #4.
	var curve_length: float = parent_path.curve.get_baked_length()
	var base_progress: float = clampf(progress, 0.0, curve_length - 40.0)
	for i in data.spawn_count:
		var child: Node = null
		if EnemyPool and EnemyPool.has_method("acquire"):
			child = EnemyPool.acquire(child_data, parent_path)
		if child == null:
			child = preload("res://scenes/enemies/base_enemy.tscn").instantiate()
			child.data = child_data
			parent_path.add_child(child)
		child.add_to_group("enemies")
		# Stagger backward along the path so children don't stack at
		# the parent's death point — spread over ~60 progress units
		child.progress = max(0.0, base_progress - float(i + 1) * 20.0)


func _show_damage_number(amount: float, damage_type: int = 0) -> void:
	var label := Label.new()
	label.text = "-%d" % int(amount)
	label.add_theme_font_size_override("font_size", 14)
	# Color-code by damage type for visual feedback
	var col := Color(1, 0.3, 0.2)  # physical red
	match damage_type:
		1: col = Color(0.7, 0.3, 1)  # magic purple
		2: col = Color(1, 0.85, 0.2) # pure gold
	label.add_theme_color_override("font_color", col)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	label.position = Vector2(randf_range(-15, 15), -40)
	label.z_index = 20
	add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", -75.0, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(label.queue_free)


func _show_mini_pop() -> void:
	# Tiny "✦" particle on damage (non-kill). Very cheap, lots of dopamine.
	var label := Label.new()
	label.text = "✦"
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", Color(1, 0.95, 0.5, 0.9))
	label.position = Vector2(randf_range(-18, 18), randf_range(-20, -30))
	label.z_index = 15
	add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 20.0, 0.4)
	tween.tween_property(label, "modulate:a", 0.0, 0.4)
	tween.chain().tween_callback(label.queue_free)


func _celebrate_boss_death() -> void:
	# Big impact burst + screen shake + deep roar — makes toppling the
	# M-Tüüfel feel like an event rather than another tick in the counter.
	if SfxManager and SfxManager.has_method("play_boss_roar"):
		SfxManager.play_boss_roar()
	if EffectPlayer:
		if EffectPlayer.has_method("spawn_impact_sparks"):
			EffectPlayer.spawn_impact_sparks(global_position, Color(1, 0.9, 0.3))
			EffectPlayer.spawn_impact_sparks(global_position + Vector2(-20, -20), Color(1, 0.4, 0.2))
			EffectPlayer.spawn_impact_sparks(global_position + Vector2(20, -20), Color(1, 0.6, 0.2))
		# Shake debounce — if another boss died in the last 0.5s, skip
		# this shake to prevent nausea on multi-boss waves (L5-10, L6-10,
		# L7-10 all spawn 3-4 bosses within a few seconds). Agent-audit
		# UX #20.
		if EffectPlayer.has_method("screen_shake"):
			var last_shake_ms: int = int(EffectPlayer.get_meta("last_boss_shake_ms", 0))
			var now_ms: int = Time.get_ticks_msec()
			if now_ms - last_shake_ms >= 500:
				EffectPlayer.screen_shake(9.0, 0.5)
				EffectPlayer.set_meta("last_boss_shake_ms", now_ms)
	# Floating "TÜÜFEL GSTÜRZT!" label at the death position
	var lbl := Label.new()
	lbl.text = "TÜÜFEL GSTÜRZT!"
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.2))
	lbl.add_theme_color_override("font_outline_color", Color(0.3, 0.1, 0))
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.position = Vector2(-120, -90)
	lbl.size = Vector2(240, 40)
	lbl.z_index = 30
	lbl.z_as_relative = false
	# Reparent to current_scene rather than the Path2D parent: Path2D can
	# have rotation/scale, which would skew or flip the label text.
	# Agent-audit BUG #19.
	var scene_root := get_tree().current_scene
	var host: Node = scene_root if scene_root else get_parent()
	if host:
		host.add_child(lbl)
		lbl.global_position = global_position + Vector2(-120, -90)
		var tw := get_tree().create_tween()
		tw.set_parallel(true)
		tw.tween_property(lbl, "global_position:y", lbl.global_position.y - 60.0, 1.2)
		tw.tween_property(lbl, "modulate:a", 0.0, 1.2)
		tw.chain().tween_callback(lbl.queue_free)


func _show_gold_earned() -> void:
	var label := Label.new()
	label.text = "+%d" % gold_reward
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1, 0.9, 0.2))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.position = Vector2(0, -50)
	label.z_index = 20
	# Add to parent so it persists after enemy freed
	get_parent().add_child(label)
	label.global_position = global_position + Vector2(0, -30)
	# Bind tween to the tree (not self) — enemy is about to queue_free
	# and a self-bound tween would die with it, leaving the label stranded.
	var tween := get_tree().create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 50.0, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.chain().tween_callback(label.queue_free)


func _on_heal_timer_timeout() -> void:
	_heal_nearby()
