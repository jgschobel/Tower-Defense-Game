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
var _prev_walk_sin: float = 0.0
var _is_hit_shaking: bool = false
var _base_v_offset: float = 0.0
var slow_timer: float = 0.0
var is_dead: bool = false
var _has_regrown: bool = false  # Regrow mechanic allows only one resurrect
var _last_killer: Node = null   # Source tower of the final blow (used for D7 death-cam)
var _health_bar_tween: Tween = null
var _death_tween: Tween = null
# 0=healthy, 1=hurt, 2=injured, 3=dying. Drives sprite tint (and
# eventually texture swap to data.damage_variants[i] once AI art lands).
var _damage_state: int = 0

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: ProgressBar = $HealthBar  # hidden permanently — see _ready

var heal_timer_node: Timer = null


func _ready() -> void:
	if has_node("HealTimer"):
		heal_timer_node = $HealTimer
	if data:
		_apply_data()
	_update_visual()
	# User directive: no HP bars at all — appearance changes communicate
	# health instead (BTD MOAB-style). Hide permanently.
	if health_bar:
		health_bar.visible = false
		health_bar.queue_free()
	# Visual-only offset so enemies that visually catch up at path bends
	# don't collapse into an indistinguishable blob (issue #48). Applied
	# to PathFollow2D's v_offset so each enemy is drawn ~±8px
	# perpendicular to the path without affecting gameplay progress.
	v_offset = randf_range(-10.0, 10.0)
	h_offset = randf_range(-14.0, 14.0)
	_base_v_offset = v_offset
	_walk_phase = randf() * TAU  # desync bobs across enemies


func _apply_data() -> void:
	# Difficulty scalars from GameManager — single multiplication point
	# so Easy/Normal/Hard feel meaningfully different.
	var hp_mult: float = GameManager.difficulty_hp_mult() if GameManager else 1.0
	var spd_mult: float = GameManager.difficulty_speed_mult() if GameManager else 1.0
	var gold_mult: float = GameManager.difficulty_gold_mult() if GameManager else 1.0
	max_health = data.max_health * hp_mult
	health = max_health
	move_speed = data.move_speed * spd_mult
	armor = data.armor
	gold_reward = int(round(data.gold_reward * gold_mult))

	# Camo visual (ROADMAP #50) — ghostly, lower opacity so the player
	# sees something but towers without can_detect_camo won't target.
	if sprite:
		if data.is_camo:
			sprite.modulate = Color(1, 1, 1, 0.35)
		else:
			sprite.modulate = Color(1, 1, 1, 1)

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
	var curr_sin := sin(_walk_phase)
	# D13: dust puff when step completes — detected on zero-crossing from
	# negative (downswing) to positive (upswing = foot just left the ground).
	# Skip flying enemies and very slow ones (tank bob barely registers).
	if _prev_walk_sin < 0.0 and curr_sin >= 0.0 and not is_dead:
		if data and not data.is_flying and speed > 50.0:
			if EffectPlayer and EffectPlayer.has_method("spawn_step_dust"):
				EffectPlayer.spawn_step_dust(global_position + Vector2(0.0, 10.0))
	_prev_walk_sin = curr_sin
	# Keep the base v_offset (set at spawn for visual separation) as the
	# midpoint and add the bob on top
	v_offset = _base_v_offset + curr_sin * 4.0

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


func take_damage(amount: float, damage_type: int = 0, source_tower: Node = null) -> void:
	if is_dead:
		return

	# Copycat (Selbschtskan-Schiff): no-op if the attacker's tower_id
	# matches the silhouette this enemy is wearing. Forces players who
	# spam one friend to diversify before L8+. Meta is set per-spawn by
	# WaveManager from GameLevel.most_recent_tower_id.
	if has_meta("immune_to") and source_tower != null and is_instance_valid(source_tower):
		if "data" in source_tower and source_tower.data != null:
			if str(get_meta("immune_to")) == String(source_tower.data.id):
				_flash_immunity()
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

	# Lead (ROADMAP #50): physical weapons bounce. Magic / pure pass
	# through normally. Reduces physical to 15% — and lead's own
	# resistance replaces normal armor (F9: prevents armor stacking
	# from flooring all physical hits to 1 regardless of tower power).
	var pre_armor: float = amount
	if data and data.is_lead and damage_type == 0:
		pre_armor *= 0.15
		effective_armor = 0.0

	var actual_damage := maxf(1.0, pre_armor - effective_armor)
	if source_tower != null and is_instance_valid(source_tower) and "wave_damage_dealt" in source_tower:
		source_tower.wave_damage_dealt += actual_damage
	health -= actual_damage
	# User directive: no HP bars + no damage numbers — replaced by
	# enemy appearance changing as health drops (BTD MOAB-style).
	_apply_damage_state_visual()
	# Subtle screen-shake on chunky hits — gives weight to tier-3 hits
	# without spamming on every basic shot.
	if actual_damage >= 80.0 and EffectPlayer and EffectPlayer.has_method("screen_shake"):
		EffectPlayer.screen_shake(2.5, 0.10)
	# Per-enemy hit pop (ROADMAP #27). Skipped if this hit kills — the
	# death sound via SfxManager.play_death takes over on kill.
	if health > 0 and data and SfxManager.has_method("play_enemy_hit"):
		SfxManager.play_enemy_hit(data.id)

	# Flash white on hit, then restore
	modulate = Color(2.0, 2.0, 2.0)
	var tween := create_tween()
	var restore_color := Color(0.6, 0.7, 1.0) if slow_factor < 1.0 else Color.WHITE
	tween.tween_property(self, "modulate", restore_color, 0.15)

	if health <= 0.0:
		# Regrow (ROADMAP #50): non-PURE damage allows one resurrect per
		# life at regrow_hp_pct of max. PURE damage (burn / holy) always
		# permakills. Visual: green flash + "ZRUGG!" label so the player
		# sees why the enemy didn't die.
		if data and data.can_regrow and not _has_regrown and damage_type != 2:
			_has_regrown = true
			health = maxf(1.0, max_health * data.regrow_hp_pct)
			_update_health_bar()
			_play_regrow_effect()
			return
		_last_killer = source_tower
		die()


func _flash_immunity() -> void:
	# Visual confirmation that a copycat just shrugged off a hit from its
	# silhouette source. Magenta pop + small "✕" label tells the player
	# why their tower's damage vanished. ~30% chance so heavy spam doesn't
	# flood the screen — every hit shouldn't tutorialize the mechanic.
	if randf() > 0.3:
		return
	if sprite:
		var base_mod: Color = sprite.modulate
		var tw := create_tween()
		tw.tween_property(sprite, "modulate", Color(1.4, 0.35, 1.0, 1), 0.08)
		tw.tween_property(sprite, "modulate", base_mod, 0.22)
	var lbl := Label.new()
	lbl.text = "NÖD!"
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.35, 1.0))
	lbl.add_theme_color_override("font_outline_color", Color(0.25, 0.05, 0.25))
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.position = Vector2(-18, -52)
	lbl.z_index = 11
	add_child(lbl)
	var lt := create_tween().set_parallel(true)
	lt.tween_property(lbl, "position:y", -88.0, 0.6)
	lt.tween_property(lbl, "modulate:a", 0.0, 0.6)
	lt.chain().tween_callback(lbl.queue_free)


func apply_copycat_silhouette(tower_id: String, source_texture: Texture2D) -> void:
	# Called by WaveManager after spawn when this enemy is a copycat.
	# Stores the immunity tower_id in meta + skins the sprite with the
	# silhouette of `source_texture`. Falls back to the generic camo-
	# style tint if no texture is provided (e.g. no tower placed yet).
	set_meta("immune_to", tower_id)
	if sprite == null:
		return
	if source_texture != null:
		sprite.texture = source_texture
		var max_dim: float = maxf(source_texture.get_width(), source_texture.get_height())
		var target_size: float = 50.0 * (data.scale_factor if data else 1.0)
		if max_dim > 0:
			var s: float = target_size / max_dim
			sprite.scale = Vector2(s, s)
		sprite.visible = true
	# Dark inverted silhouette with magenta outline tint — reads as
	# "ghost of yourself" without needing a custom shader pass.
	sprite.modulate = Color(0.18, 0.05, 0.20, 0.92)
	sprite.self_modulate = Color(0.4, 0.05, 0.5, 1.0)


func _play_regrow_effect() -> void:
	modulate = Color(0.5, 1.4, 0.6)
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color.WHITE, 0.4)
	var label := Label.new()
	label.text = "ZRUGG!"
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.5, 1.0, 0.4))
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.25, 0, 1))
	label.add_theme_constant_override("outline_size", 3)
	label.position = Vector2(-30, -60)
	label.z_index = 11
	add_child(label)
	var lt := create_tween().set_parallel(true)
	lt.tween_property(label, "position:y", -100.0, 0.7)
	lt.tween_property(label, "modulate:a", 0.0, 0.7)
	lt.chain().tween_callback(label.queue_free)


func apply_slow(factor: float, duration: float) -> void:
	slow_factor = factor
	slow_timer = duration
	# Tint blue-ish when slowed (whole node including drawn shapes)
	modulate = Color(0.6, 0.7, 1.0, 1.0)


func pull_back(fraction: float) -> void:
	# Amösius tongue pull (ROADMAP #38). Reduces progress_ratio by the
	# given fraction of total path, floored at 0. Small tween on
	# modulate briefly tints the enemy cyan to signal the grab.
	if fraction <= 0.0 or is_dead:
		return
	progress_ratio = max(0.0, progress_ratio - fraction)
	if sprite:
		var base_mod: Color = sprite.modulate
		var tw := create_tween()
		tw.tween_property(sprite, "modulate", Color(0.4, 0.8, 1.0, 1), 0.08)
		tw.tween_property(sprite, "modulate", base_mod, 0.25)


func flash_crit() -> void:
	# Visual callback for crit hits (ROADMAP #38, Kühne). Big yellow
	# "KRIT!" pop + brief sprite scale-punch. Called from base_tower
	# before the damage is applied.
	var label := Label.new()
	label.text = "KRIT!"
	label.add_theme_font_size_override("font_size", 38)
	label.add_theme_color_override("font_color", Color(1, 0.92, 0.12))
	label.add_theme_color_override("font_outline_color", Color(0.45, 0.18, 0, 1))
	label.add_theme_constant_override("outline_size", 6)
	label.position = Vector2(-44, -78)
	label.z_index = 22
	label.scale = Vector2(0.4, 0.4)
	add_child(label)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(label, "scale", Vector2(1.15, 1.15), 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(label, "position:y", -120.0, 0.7)
	tw.chain().tween_property(label, "modulate:a", 0.0, 0.25)
	tw.chain().tween_callback(label.queue_free)
	# Crit shake — feels weighty without being huge
	if EffectPlayer and EffectPlayer.has_method("screen_shake"):
		EffectPlayer.screen_shake(3.5, 0.12)
	if sprite:
		var base_scale: Vector2 = sprite.scale
		var punch := create_tween()
		punch.tween_property(sprite, "scale", base_scale * 1.25, 0.08).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		punch.tween_property(sprite, "scale", base_scale, 0.14).set_trans(Tween.TRANS_SINE)


func show_hit_reaction() -> void:
	# Hit-shake the sprite — gives a tactile "hit registered" feel beyond
	# just the damage number. ±4px lateral over 0.07s, then settles back.
	if sprite and not _is_hit_shaking:
		_is_hit_shaking = true
		var base_x: float = sprite.position.x
		var sk := sprite.create_tween()
		sk.tween_property(sprite, "position:x", base_x + 4.0, 0.025)
		sk.tween_property(sprite, "position:x", base_x - 3.0, 0.04)
		sk.tween_property(sprite, "position:x", base_x, 0.035)
		sk.tween_callback(func(): _is_hit_shaking = false)
	# Show a floating angry/sad label above the enemy (~30% of the time so
	# it's punctuation not noise — was every hit, became repetitive in
	# stress waves)
	if randf() > 0.7:
		var reaction := Label.new()
		var reactions := [">:(", "AUA!", "HEY!", "STOPP!", "NEI!", "WÄÄH!", "AUTSCH!", "GOPF!"]
		reaction.text = reactions[randi() % reactions.size()]
		reaction.add_theme_font_size_override("font_size", 18)
		reaction.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
		reaction.add_theme_color_override("font_outline_color", Color.BLACK)
		reaction.add_theme_constant_override("outline_size", 2)
		reaction.position = Vector2(-15, -50)
		reaction.z_index = 10
		add_child(reaction)
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
	# Combo multiplier applied to gold (ROADMAP combo system). note_kill
	# BEFORE add_gold so the new streak's multiplier applies to this kill.
	var mult: float = 1.0
	if ComboTracker:
		ComboTracker.note_kill()
		mult = ComboTracker.current_multiplier()
	CurrencyManager.add_gold(int(round(gold_reward * mult)))
	GameManager.record_kill()
	_show_gold_earned()
	SfxManager.play_death(data.max_health if data else 100.0)

	# Boss celebration — massive impact spark burst + screen shake
	# + floating "TÜÜFEL GSTÜRZT!" text. Only for boss enemies so
	# small kills don't spam the effects.
	if data and data.id == "boss":
		_celebrate_boss_death(_last_killer)

	# Spawn children on death if configured
	if data and (data.spawn_payload.size() > 0 or (data.spawns_on_death != "" and data.spawn_count > 0)):
		_spawn_children()

	# Fondue-Bomb (ROADMAP #31): on death, heal nearby enemies.
	if data and data.splash_on_death_radius > 0.0 and data.splash_on_death_heal_pct > 0.0:
		_splash_heal_nearby()

	enemy_died.emit(self)

	# Spawn a one-shot poof at the enemy's position so we can immediately
	# hide the enemy without losing the death feedback. Cleaner than a
	# 0.35s on-corpse tween that left bodies visible mid-screen.
	if EffectPlayer and EffectPlayer.has_method("spawn_death_poof"):
		var poof_color: Color = data.base_color if data else Color(1, 0.5, 0.3)
		EffectPlayer.spawn_death_poof(global_position, poof_color)
	# Snappier death — 0.18s instead of 0.35s, parallel scale+fade only,
	# no rotation (felt floaty). Set visible=false at end so the enemy
	# actually vanishes even if pool release races on the callback.
	_death_tween = create_tween()
	_death_tween.set_parallel(true)
	_death_tween.tween_property(self, "scale", Vector2(0.7, 0.7), 0.18).set_ease(Tween.EASE_IN)
	_death_tween.tween_property(self, "modulate:a", 0.0, 0.18)
	_death_tween.chain().tween_callback(func():
		visible = false
		_return_to_pool_or_free())


func _splash_heal_nearby() -> void:
	var radius_sq: float = data.splash_on_death_radius * data.splash_on_death_radius
	var heal_pct: float = data.splash_on_death_heal_pct
	for n in get_tree().get_nodes_in_group("enemies"):
		var e := n as BaseEnemy
		if e == null or e == self or e.is_dead:
			continue
		if global_position.distance_squared_to(e.global_position) > radius_sq:
			continue
		var heal: float = e.max_health * heal_pct
		e.health = clampf(e.health + heal, 0.0, e.max_health)
		if e.has_method("_update_health_bar"):
			e._update_health_bar()


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
	# Kill the death tween first — if still running it would fade out
	# the reused enemy or leave sprite.modulate at 0 (F1/F2 fix).
	if _death_tween and _death_tween.is_valid():
		_death_tween.kill()
	_death_tween = null
	if _health_bar_tween and _health_bar_tween.is_valid():
		_health_bar_tween.kill()
	_health_bar_tween = null
	if data:
		_apply_data()
		_update_visual()
	is_dead = false
	_has_regrown = false
	_last_killer = null
	_damage_state = 0
	# Copycat immunity must NOT survive pool reuse — clearing here means
	# a copycat-respawned-as-basic doesn't keep its previous immune_to.
	if has_meta("immune_to"):
		remove_meta("immune_to")
	if sprite:
		sprite.modulate = Color.WHITE
		sprite.self_modulate = Color.WHITE
	progress = 0.0
	progress_ratio = 0.0
	slow_factor = 1.0
	slow_timer = 0.0
	modulate = Color.WHITE
	scale = Vector2.ONE
	rotation = 0.0
	# Reapply visual offset for path-bend separation (#48)
	v_offset = randf_range(-10.0, 10.0)
	h_offset = randf_range(-14.0, 14.0)
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
			# Normalize to the same on-screen size as custom-texture
			# enemies. The old `scale_factor * 0.5` ignored texture
			# dimensions, so a 1024px photo rendered ~10× too big —
			# giant raw faces floating over the map.
			var photo_max := maxf(photo.get_width(), photo.get_height())
			var photo_target := 50.0 * data.scale_factor
			if photo_max > 0:
				sprite.scale = Vector2.ONE * (photo_target / photo_max)
			else:
				sprite.scale = Vector2.ONE * (photo_target / 512.0)
			# Same circular clip the towers use — photo reads as a face
			# token, not a pasted rectangle.
			if sprite.material == null:
				var clip := ShaderMaterial.new()
				clip.shader = preload("res://assets/shaders/circle_clip.gdshader")
				sprite.material = clip
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


func _apply_damage_state_visual() -> void:
	# BTD MOAB-style: enemy appearance shifts as HP drops, NO health bar.
	# 4 states: 0=healthy (>66%), 1=hurt (33-66%), 2=injured (10-33%),
	# 3=dying (<10%). Texture-swap (hurt / injured / dying PNGs) plus a
	# light residual tint so the shift reads even on bright enemies.
	if sprite == null or max_health <= 0:
		return
	# Copycats wear a fixed dark+magenta silhouette — don't let the
	# damage-state tint clobber it (otherwise the "ghost of yourself"
	# read disappears as soon as another tower lands a hit).
	if has_meta("immune_to"):
		return
	var pct: float = clampf(health / max_health, 0.0, 1.0)
	var state: int = 0
	if pct < 0.10: state = 3
	elif pct < 0.33: state = 2
	elif pct < 0.66: state = 1
	if state == _damage_state:
		return
	_damage_state = state
	# Try texture swap to the matching state variant. These files live
	# under assets/textures/variants/enemies/<id>/<id>_state{1,2,3}_*.png
	# and were generated by the enemy-damage-art workflow back in May.
	# Falls through to tint-only if the file doesn't exist.
	var enemy_id: String = data.id if data and "id" in data else ""
	if enemy_id != "" and state > 0:
		var suffix: String = ["", "hurt", "injured", "dying"][state]
		var variant_path := "res://assets/textures/variants/enemies/%s/%s_state%d_%s.png" % \
			[enemy_id, enemy_id, state, suffix]
		if ResourceLoader.exists(variant_path):
			var tex: Texture2D = load(variant_path)
			if tex:
				sprite.texture = tex
	elif state == 0 and data and data.custom_texture:
		# Recovering / first-time application: restore the clean texture.
		sprite.texture = data.custom_texture
	# Residual tint keeps the read even when textures look similar at
	# small map scale. Lighter than the old tint-only ramp.
	match state:
		0: sprite.modulate = Color(1.0, 1.0, 1.0, 1.0)
		1: sprite.modulate = Color(1.0, 0.95, 0.92, 1.0)
		2: sprite.modulate = Color(0.95, 0.85, 0.80, 1.0)
		3: sprite.modulate = Color(0.85, 0.65, 0.62, 1.0)


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
	if not data:
		return
	var parent_path := get_parent() as Path2D
	if not parent_path or not parent_path.curve:
		return
	var curve_length: float = parent_path.curve.get_baked_length()
	var base_progress: float = clampf(progress, 0.0, curve_length - 40.0)

	var wm := get_tree().get_first_node_in_group("wave_manager")

	# Multi-type payload overrides single-type spawns_on_death.
	if data.spawn_payload.size() > 0:
		for i in data.spawn_payload.size():
			var enemy_id: String = str(data.spawn_payload[i])
			var dp := "res://resources/enemy_data/%s.tres" % enemy_id
			if not ResourceLoader.exists(dp):
				push_warning("[base_enemy] spawn_payload entry missing: %s (skipped)" % dp)
				continue
			var child_data = load(dp)
			var child: Node = null
			if EnemyPool and EnemyPool.has_method("acquire"):
				child = EnemyPool.acquire(child_data, parent_path)
			if child == null:
				child = preload("res://scenes/enemies/base_enemy.tscn").instantiate()
				child.data = child_data
				parent_path.add_child(child)
			child.add_to_group("enemies")
			child.progress = max(0.0, base_progress - float(i + 1) * 20.0)
			if wm and wm.has_method("register_spawned_enemy"):
				wm.register_spawned_enemy(child)
		return

	# Single-type fallback (original behaviour).
	if data.spawns_on_death == "" or data.spawn_count <= 0:
		return
	var data_path := "res://resources/enemy_data/%s.tres" % data.spawns_on_death
	if not ResourceLoader.exists(data_path):
		push_warning("[base_enemy] spawns_on_death data missing: %s (skipped)" % data_path)
		return
	var child_data = load(data_path)
	for i in data.spawn_count:
		var child: Node = null
		if EnemyPool and EnemyPool.has_method("acquire"):
			child = EnemyPool.acquire(child_data, parent_path)
		if child == null:
			child = preload("res://scenes/enemies/base_enemy.tscn").instantiate()
			child.data = child_data
			parent_path.add_child(child)
		child.add_to_group("enemies")
		child.progress = max(0.0, base_progress - float(i + 1) * 20.0)
		if wm and wm.has_method("register_spawned_enemy"):
			wm.register_spawned_enemy(child)


func _celebrate_boss_death(killer: Node = null) -> void:
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

	# D7: tier-3 tower kill on boss → cinematic bullet-time + name bubble
	if killer != null and is_instance_valid(killer) and EffectPlayer and EffectPlayer.has_method("tier3_boss_kill"):
		var killer_tier: int = 0
		if "path_a_tier" in killer and "path_b_tier" in killer:
			killer_tier = max(int(killer.path_a_tier), int(killer.path_b_tier))
		if killer_tier >= 3:
			EffectPlayer.tier3_boss_kill(killer, global_position)


func _show_gold_earned() -> void:
	# D26: styled gold floater — coin prefix, bolder size, arc trajectory.
	var label := Label.new()
	label.text = "+%d G" % gold_reward  # was "✦ +N G" — sparkle removed (tofu on Android Noto-stripped)
	# Three tiers: small reward 18px, medium 24px, big 30px. Big rewards
	# also get a brief sparkle pop scale.
	var font_size: int = 18
	if gold_reward >= 50:
		font_size = 30
	elif gold_reward >= 25:
		font_size = 24
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", Color(1.0, 0.88, 0.15))
	label.add_theme_color_override("font_outline_color", Color(0.25, 0.12, 0.0))
	label.add_theme_constant_override("outline_size", 4)
	label.z_index = 20
	get_parent().add_child(label)
	label.global_position = global_position + Vector2(randf_range(-12, 12), -30)
	# Slight horizontal drift for variety — floats up and fades.
	var drift_x: float = randf_range(-18.0, 18.0)
	var tween := get_tree().create_tween().set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 55.0, 0.75)
	tween.tween_property(label, "position:x", label.position.x + drift_x, 0.75)
	tween.tween_property(label, "modulate:a", 0.0, 0.75).set_delay(0.25)
	tween.chain().tween_callback(label.queue_free)


func _on_heal_timer_timeout() -> void:
	_heal_nearby()
