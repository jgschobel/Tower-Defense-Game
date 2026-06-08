class_name BaseTower
extends Node2D

## Base tower that targets and shoots enemies in range.

signal tower_sold(tower: Node2D)
signal tower_upgraded(tower: Node2D, new_level: int)

@export var data: TowerData

var upgrade_level: int = 0          # legacy linear
var path_a_tier: int = 0            # branching, 0-3
var path_b_tier: int = 0            # branching, 0-3
var current_target: BaseEnemy = null
var attack_timer: float = 0.0
var is_placed: bool = false
var kill_count: int = 0             # enemies killed by this tower
# Per-tower targeting mode override (BTD5-style). -1 = use data.target_mode
# default; 0-3 = override with FIRST/LAST/CLOSEST/STRONGEST. Player cycles
# this via the tower-info panel; persists with the tower instance.
var target_mode_override: int = -1
# BTD5-style active ability cooldown (Tier 1C). Tracked in seconds.
# Tower's tier 3+ unlocks an active ability (per-tower implementation in
# trigger_active_ability). 0 = ready, > 0 = on cooldown.
var ability_cooldown_remaining: float = 0.0
# Triple-fire effect tracker for Lemurius "Banana-Storm" ability:
# while > 0, _attack() spawns 3 projectiles instead of 1.
var ability_triple_fire_remaining: float = 0.0

# Computed stats (base + upgrades)
var effective_damage: float = 0.0
var effective_range: float = 0.0
var effective_speed: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var range_indicator: Node2D = $RangeIndicator
@onready var attack_origin: Marker2D = $AttackOrigin
@onready var detection_area: Area2D = $DetectionArea

var _enemies_in_range: Array = []
var _projectile_scene: PackedScene
# Script reference cached for identity-check in _attack(). Using get_script()
# comparison is more reliable than has_method() in Godot 4 headless — has_method
# can spuriously return false during GDScript VM pressure at high time_scale.
var _projectile_script: Script
# Cached tier-pip geometry — recomputed on upgrade(), reused in _draw
# so per-frame trig is avoided. ROADMAP PERF #7. Stored as
# Array[Array] with entries [position: Vector2, tint: Color].
var _pip_cache: Array = []
# Per-instance shuffled taunt sub-pool — exhausted before reshuffling so
# two towers of the same type never chorus the same line (ROADMAP #11).
var _taunt_pool: Array = []
# Guard so rapid-fire attacks don't stack pulse tweens on the sprite scale.
var _is_attack_pulsing: bool = false
# Tracked so we can kill it before freeing the glow node on tier changes,
# preventing the lambda from accessing a freed Node2D.
var _glow_pulse_tween: Tween = null
# Fitted sprite scale from _update_visual — tweens use this as the idle
# baseline instead of data.sprite_scale. Friend photos are ~1024px so the
# fit scale is ~0.12, not 1.0; tweens returning to data.sprite_scale made
# towers fill the screen on first attack.
var _baseline_scale: Vector2 = Vector2.ONE

# Active pair-synergy bonus (see SynergyTable). Empty = no synergy active.
# Keys: range_mul, dmg_mul, atk_speed_mul, slow_dur_add, pierce_add, label.
var _synergy_bonus: Dictionary = {}

# Love-tap easter egg: 7 taps within 3s triggers a personal Swiss German voice-line.
var _love_tap_count: int = 0
var _love_tap_window_start: float = 0.0
var _love_tap_cd_remaining: float = 0.0
const _LOVE_TAP_THRESHOLD: int = 7
const _LOVE_TAP_WINDOW: float = 3.0
const _LOVE_TAP_COOLDOWN: float = 30.0

# Taunt memes — one per character. Randomly floated above the tower every
# 6-12s while placed, to give each friend some personality. Strings are
# exactly what each friend would actually yell in the scenario.
const TAUNTS: Dictionary = {
	"basic": ["BIO BANANE!", "CHF 2.95/kg!", "Monet x17!", "Fairtrade!", "Rundschwanz!"],
	"sniper": ["ATSCHII!", "Pollen-Zeit!", "Blueme-Power!", "Heuschnupfe weg!", "Magic!"],
	"splash": ["EXOTHERMI!", "pH 0!", "REAGIERT!", "SÄURE!", "Erlenmeyer!"],
	"cordula": ["Helau!", "Konfetti!", "VOLLEY!", "Fasnachts-Power!", "Ahoi!"],
	"slow": ["LOTTO!", "CHF 2.50!", "Zunge raus!", "Chläbrig!", "Gopfriedstutz!"],
}


func _ready() -> void:
	_projectile_scene = preload("res://scenes/projectiles/base_projectile.tscn")
	_projectile_script = preload("res://scripts/projectiles/base_projectile.gd")
	if data:
		_apply_data()
		_update_visual()
		_update_range_collider()
	# Kick off the random taunt loop — only fires when is_placed=true
	_start_taunt_loop()
	# Gentle idle life — breathing scale + slight bob. Staggered per
	# tower (random offset) so 5 placed towers don't pulse in lockstep.
	_start_idle_animation()
	# Circle clip shader: all tower sprites appear as circular portraits.
	# Fixes inconsistency where newer towers (Joe/Justus/Seve) rendered as
	# opaque rectangular cards while original towers used transparent-BG PNGs.
	if sprite and sprite.material == null:
		var mat := ShaderMaterial.new()
		mat.shader = preload("res://assets/shaders/circle_clip.gdshader")
		sprite.material = mat


func _start_idle_animation() -> void:
	# Breathing + bob loop on the Sprite2D. Kept subtle (~3% scale,
	# 1.5px bob) so it reads as "alive" without being distracting.
	# Uses a local baseline captured AFTER _apply_data applies its own
	# scale, so tower-specific sizing (data.sprite_scale) is preserved.
	if sprite == null:
		return
	var base_y: float = sprite.position.y
	# Per-tower phase offset so the herd doesn't sync up
	var phase: float = randf() * PI * 2.0
	# Stagger cycle length a touch for variety
	var cycle: float = randf_range(1.8, 2.4)
	# Idle animation only bobs position — NEVER touches sprite.scale.
	# The attack/upgrade/sell tweens all animate sprite.scale, and running
	# a looping scale tween here caused runaway compounding (tower filled
	# the screen when shooting). Position-only bob is enough "alive".
	var bob := create_tween().set_loops()
	bob.set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_SINE)
	bob.tween_interval((phase + PI * 0.5) / (PI * 2.0) * cycle)
	bob.tween_property(sprite, "position:y", base_y - 1.5, cycle * 0.5)
	bob.tween_property(sprite, "position:y", base_y, cycle * 0.5)


func _start_taunt_loop() -> void:
	# Idempotency guard (agent-audit #5) — matches the pattern used by
	# HUD's ThreatTimer. Prevents stacked timers if _ready were to run
	# twice for any reason.
	if has_node("TauntTimer"):
		return
	var t := Timer.new()
	t.name = "TauntTimer"
	t.wait_time = randf_range(6.0, 12.0)
	t.one_shot = false
	t.autostart = true
	add_child(t)
	t.timeout.connect(_maybe_taunt.bind(t))


func _maybe_taunt(t: Timer) -> void:
	# Re-randomize interval so taunts don't line up
	t.wait_time = randf_range(6.0, 12.0)
	if not is_placed or not data:
		return
	# Skip during active spawning — taunt labels allocate a Label + tween
	# per fire, adding GC pressure right when the frame budget is tightest
	# (stress waves). ROADMAP PERF #6.
	var wm: Node = get_tree().get_first_node_in_group("wave_manager")
	if wm != null and "is_spawning" in wm and wm.is_spawning:
		return
	var lines: Array = TAUNTS.get(data.id, [])
	if lines.is_empty():
		return
	# 60% chance to actually fire, so it feels spontaneous
	if randf() > 0.6:
		return
	# Refill the per-instance shuffled pool when exhausted so same-type
	# towers cycle through all lines before repeating any (ROADMAP #11).
	if _taunt_pool.is_empty():
		_taunt_pool = lines.duplicate()
		_taunt_pool.shuffle()
	_float_taunt(_taunt_pool.pop_back())


func _float_taunt(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(1, 0.95, 0.6))
	lbl.add_theme_color_override("font_outline_color", Color(0.15, 0.05, 0, 0.9))
	lbl.add_theme_constant_override("outline_size", 3)
	# Default taunt position — centered above the tower. If the tower is
	# near the edge, nudge the label inward so the text stays on screen.
	var local_x: float = -60.0
	var vp_rect := get_viewport().get_visible_rect()
	var screen_pos_left: float = global_position.x + local_x
	var screen_pos_right: float = screen_pos_left + 120.0
	if screen_pos_left < 10.0:
		local_x += (10.0 - screen_pos_left)
	elif screen_pos_right > vp_rect.size.x - 10.0:
		local_x -= (screen_pos_right - (vp_rect.size.x - 10.0))
	lbl.position = Vector2(local_x, -70)
	lbl.size = Vector2(120, 22)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.z_index = 18
	add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", -110.0, 1.6)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.6)
	tw.chain().tween_callback(lbl.queue_free)


# Called by game_level on every tap that lands on this tower.
# Counts rapid taps; at threshold shows a personal voice-line bubble.
func on_tapped() -> void:
	if _love_tap_cd_remaining > 0.0:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if now - _love_tap_window_start > _LOVE_TAP_WINDOW:
		_love_tap_count = 0
		_love_tap_window_start = now
	_love_tap_count += 1
	if _love_tap_count >= _LOVE_TAP_THRESHOLD:
		_love_tap_count = 0
		_love_tap_cd_remaining = _LOVE_TAP_COOLDOWN
		_show_love_line()


func _show_love_line() -> void:
	if not data:
		return
	var lines: Array = EasterEggLines.get_lines(data.id)
	if lines.is_empty():
		return
	var line: String = lines[randi() % lines.size()]
	var lbl := Label.new()
	lbl.text = line
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.5, 0.95, 1.0))
	lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.1, 0.2, 0.9))
	lbl.add_theme_constant_override("outline_size", 3)
	var local_x := -70.0
	var vp_rect := get_viewport().get_visible_rect()
	var screen_left := global_position.x + local_x
	var screen_right := screen_left + 140.0
	if screen_left < 10.0:
		local_x += (10.0 - screen_left)
	elif screen_right > vp_rect.size.x - 10.0:
		local_x -= (screen_right - (vp_rect.size.x - 10.0))
	lbl.position = Vector2(local_x, -90)
	lbl.size = Vector2(140, 26)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.z_index = 20
	add_child(lbl)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(lbl, "position:y", -130.0, 1.2)
	tw.tween_property(lbl, "modulate:a", 0.0, 1.2)
	tw.chain().tween_callback(lbl.queue_free)


func _apply_data() -> void:
	_recalculate_stats()
	_rebuild_pip_cache()


func _refresh_synergies() -> void:
	if not data or not is_placed:
		return
	var old_label: String = _synergy_bonus.get("label", "")
	_synergy_bonus = {}
	for tower_node in get_tree().get_nodes_in_group("towers"):
		var other := tower_node as BaseTower
		if other == null or other == self or not other.data:
			continue
		if global_position.distance_squared_to(other.global_position) > 22500.0:  # 150² px
			continue
		var bonus: Dictionary = SynergyTable.find_bonus(data.id, other.data.id)
		if not bonus.is_empty():
			_synergy_bonus = bonus.duplicate()
			break
	_recalculate_stats()
	_update_range_collider()
	if _synergy_bonus.get("label", "") != old_label:
		queue_redraw()


func _recalculate_stats() -> void:
	if not data:
		return
	effective_damage = data.damage
	effective_range = data.attack_range
	effective_speed = data.attack_speed

	if data.has_branching_upgrades():
		for i in path_a_tier:
			if i < data.path_a_damage_bonus.size():
				effective_damage += data.path_a_damage_bonus[i]
			if i < data.path_a_range_bonus.size():
				effective_range += data.path_a_range_bonus[i]
			if i < data.path_a_speed_bonus.size():
				effective_speed += data.path_a_speed_bonus[i]
		for i in path_b_tier:
			if i < data.path_b_damage_bonus.size():
				effective_damage += data.path_b_damage_bonus[i]
			if i < data.path_b_range_bonus.size():
				effective_range += data.path_b_range_bonus[i]
			if i < data.path_b_speed_bonus.size():
				effective_speed += data.path_b_speed_bonus[i]
	else:
		for i in upgrade_level:
			if i < data.upgrade_damage_bonus.size():
				effective_damage += data.upgrade_damage_bonus[i]
			if i < data.upgrade_range_bonus.size():
				effective_range += data.upgrade_range_bonus[i]
			if i < data.upgrade_speed_bonus.size():
				effective_speed += data.upgrade_speed_bonus[i]

	# Apply buff from nearby support towers
	var buff_damage := 0.0
	var buff_speed := 0.0
	for tower_node in get_tree().get_nodes_in_group("towers"):
		var tower := tower_node as BaseTower
		if tower == self or tower == null or not tower.data:
			continue
		if tower.data.buff_range > 0.0:
			if global_position.distance_to(tower.global_position) <= tower.data.buff_range:
				buff_damage += tower.data.buff_damage_pct
				buff_speed += tower.data.buff_speed_pct

	effective_damage *= (1.0 + buff_damage)
	effective_speed *= (1.0 + buff_speed)

	# Pair-synergy multipliers applied last (on top of all other bonuses).
	if not _synergy_bonus.is_empty():
		effective_range *= _synergy_bonus.get("range_mul", 1.0)
		effective_damage *= _synergy_bonus.get("dmg_mul", 1.0)
		effective_speed *= _synergy_bonus.get("atk_speed_mul", 1.0)


func _process(delta: float) -> void:
	if not is_placed or not data:
		return

	# Tick love-tap cooldown for all placed towers (farm/support included).
	if _love_tap_cd_remaining > 0.0:
		_love_tap_cd_remaining = maxf(0.0, _love_tap_cd_remaining - delta)

	# Farm + support towers have no offensive loop (ROADMAP #38). Idle bob
	# tween keeps them "alive"; gold/buff effects fire from signal hooks.
	if data.gold_per_round > 0 or data.is_support:
		return

	# Clean up dead enemies from range list, also drop any that strayed out
	# of range without firing area_exited (common when physics lags at high
	# time_scale — Area2D positions trail the enemy's visual global_position).
	var valid_enemies: Array = []
	for e in _enemies_in_range:
		if is_instance_valid(e) and not e.is_dead:
			if global_position.distance_to(e.global_position) <= effective_range + 30.0:
				valid_enemies.append(e)
	_enemies_in_range = valid_enemies

	# Always-on direct distance scan: catches enemies missed by Area2D when
	# physics lags at high time_scale. Running unconditionally (not just when
	# list is empty) ensures towers don't miss enemies that Area2D partially
	# detected — e.g. Area2D fires area_entered for 2 of 5 enemies in range,
	# list is non-empty, conditional fallback skips, 3 enemies never targeted.
	if effective_range > 0.0:
		for enemy_node in get_tree().get_nodes_in_group("enemies"):
			var enemy := enemy_node as BaseEnemy
			if enemy == null or enemy.is_dead or enemy in _enemies_in_range:
				continue
			if global_position.distance_to(enemy.global_position) <= effective_range:
				_enemies_in_range.append(enemy)

	# Find target
	current_target = _find_target()

	# Juice: sprite visibly turns toward the active target. Attack origin
	# rotates fully (for projectile spawn direction). Sprite clamped to
	# ±35° so chibi heads stay readable (not fully upside-down when
	# enemy is to the left), with snappy 8× lerp for "tracking feel".
	if current_target and attack_origin:
		var dir := current_target.global_position - global_position
		attack_origin.rotation = dir.angle()
		var target_tilt := clampf(dir.angle(), -0.6, 0.6)
		if sprite:
			sprite.rotation = lerpf(sprite.rotation, target_tilt, 8.0 * delta)
	elif sprite:
		# No target: ease back to neutral
		sprite.rotation = lerpf(sprite.rotation, 0.0, 4.0 * delta)

	# Attack
	# Tick ability cooldowns + triple-fire timer (Tier 1C — active abilities)
	if ability_cooldown_remaining > 0.0:
		ability_cooldown_remaining = maxf(0.0, ability_cooldown_remaining - delta)
	if ability_triple_fire_remaining > 0.0:
		ability_triple_fire_remaining = maxf(0.0, ability_triple_fire_remaining - delta)

	attack_timer -= delta
	# When ability_triple_fire_remaining > 0, fire 3× as fast (Banana-Storm
	# active ability for Lemurius t3+; future towers can use the same hook).
	var fire_speed_mul: float = 3.0 if ability_triple_fire_remaining > 0.0 else 1.0
	var _atk_period: float = 1.0 / (effective_speed * fire_speed_mul)
	# Use while + += so multiple attacks fire correctly in a single large-delta
	# frame (required at high time_scale where delta > 1/attack_speed).
	# Using += instead of = prevents discarding timer overshoot, which caused
	# towers to fire at half the correct rate at 8× time_scale on CI (issue #619).
	while attack_timer <= 0.0 and current_target:
		_attack()
		attack_timer += _atk_period
		if attack_timer <= 0.0:
			current_target = _find_target()
			if not current_target:
				break


func _is_valid_projectile(p: Node) -> bool:
	if p == null or not is_instance_valid(p):
		return false
	# Primary: script identity (reliable under normal conditions).
	if _projectile_script != null and p.get_script() == _projectile_script:
		return true
	# Secondary: property-presence check. More reliable than has_method() in
	# headless Godot 4 at 8× time_scale where GDScript VM pressure can cause
	# has_method() to return false for valid nodes. A node with `damage` and
	# `speed` properties is a functionally valid BaseProjectile regardless of
	# whether the script identity matches (e.g. post-CACHE_MODE_IGNORE reload).
	if "damage" in p and "speed" in p:
		return true
	# Tertiary: has_method fallback (least reliable — kept as last resort).
	return p.has_method("setup")


func has_camo_detection() -> bool:
	if data and data.can_detect_camo:
		return true
	# Share detection with nearby detector towers (buff-range scoped).
	for tn in get_tree().get_nodes_in_group("towers"):
		if tn == self:
			continue
		if tn is BaseTower and tn.data and tn.data.can_detect_camo and tn.data.buff_range > 0.0:
			if global_position.distance_to(tn.global_position) <= tn.data.buff_range:
				return true
	return false


func _find_target() -> BaseEnemy:
	if _enemies_in_range.is_empty():
		return null

	# Filter flying + camo (ROADMAP #50). Camo enemies are invisible
	# unless this tower has detection or a nearby tower with detection
	# + buff_range that reaches us shares it.
	var detects_camo: bool = has_camo_detection()
	var valid: Array = []
	for e in _enemies_in_range:
		var enemy := e as BaseEnemy
		if enemy == null or enemy.is_dead:
			continue
		if not data.can_target_flying and enemy.data and enemy.data.is_flying:
			continue
		if enemy.data and enemy.data.is_camo and not detects_camo:
			continue
		valid.append(enemy)

	if valid.is_empty():
		return null

	# Use per-tower override if set, else fall back to data default.
	# BTD5-style: each placed tower remembers its own targeting choice.
	var mode: int = target_mode_override if target_mode_override >= 0 else int(data.target_mode)
	match mode:
		TowerData.TargetMode.FIRST:
			var best: BaseEnemy = valid[0]
			for e in valid:
				if e.progress_ratio > best.progress_ratio:
					best = e
			return best
		TowerData.TargetMode.LAST:
			var best: BaseEnemy = valid[0]
			for e in valid:
				if e.progress_ratio < best.progress_ratio:
					best = e
			return best
		TowerData.TargetMode.CLOSEST:
			var best: BaseEnemy = valid[0]
			var best_dist := global_position.distance_squared_to(best.global_position)
			for e in valid:
				var d := global_position.distance_squared_to(e.global_position)
				if d < best_dist:
					best = e
					best_dist = d
			return best
		TowerData.TargetMode.STRONGEST:
			var best: BaseEnemy = valid[0]
			for e in valid:
				if e.health > best.health:
					best = e
			return best

	return valid[0]


func _attack() -> void:
	if not current_target:
		return
	# Double check target is still valid
	if not is_instance_valid(current_target) or current_target.is_dead:
		current_target = null
		return

	# Projectile spawns from per-tower offset (Amösius tongue from mouth,
	# Lemurius bananas from hand, etc). Falls back to attack_origin marker
	# then to tower center.
	var origin_pos: Vector2
	if data.projectile_origin_offset != Vector2.ZERO:
		origin_pos = global_position + data.projectile_origin_offset
	elif attack_origin:
		origin_pos = attack_origin.global_position
	else:
		origin_pos = global_position

	# Per-tower + per-tier shoot voice (ROADMAP #24)
	var shoot_tier: int = max(path_a_tier, path_b_tier) if data.has_branching_upgrades() else upgrade_level
	SfxManager.play_shoot(data.id, shoot_tier)

	# Quick attack-pulse on the sprite — punches scale 1.0→1.10→1.0 over
	# 0.12s. Makes the tower feel "alive" when shooting. Cheap, no allocs.
	# Skipped during a tween chain to avoid stacking with upgrade/place anims.
	if sprite and not _is_attack_pulsing:
		_is_attack_pulsing = true
		var base_scale: Vector2 = _baseline_scale if _baseline_scale != Vector2.ZERO else sprite.scale
		var pulse := sprite.create_tween()
		pulse.tween_property(sprite, "scale", base_scale * 1.10, 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		pulse.tween_property(sprite, "scale", base_scale, 0.07).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		pulse.tween_callback(func(): _is_attack_pulsing = false)

	# Cordula cone burst (ROADMAP #38). Any enemy within data.cone_half_angle
	# of the aim direction takes 60% damage instantly, in addition to the
	# main projectile hit. No visible extra projectile — the main burst
	# animation already reads as an arc.
	if data.cone_half_angle > 0.0 and current_target:
		var aim: Vector2 = (current_target.global_position - global_position).normalized()
		var range_sq: float = data.attack_range * data.attack_range
		for enemy_node in get_tree().get_nodes_in_group("enemies"):
			var enemy := enemy_node as BaseEnemy
			if enemy == null or enemy == current_target or enemy.is_dead:
				continue
			var delta: Vector2 = enemy.global_position - global_position
			if delta.length_squared() > range_sq:
				continue
			var angle_to: float = acos(clamp(aim.dot(delta.normalized()), -1.0, 1.0))
			if angle_to <= data.cone_half_angle:
				var cone_was_alive: bool = not enemy.is_dead
				enemy.take_damage(effective_damage * 0.6, data.damage_type, self)
				enemy.show_hit_reaction()
				if cone_was_alive and enemy.is_dead:
					kill_count += 1
	# Muzzle flash — colored burst in the direction of the target
	if EffectPlayer and is_instance_valid(current_target):
		var flash_dir := (current_target.global_position - origin_pos).normalized()
		var style: String = data.projectile_style if "projectile_style" in data else ""
		EffectPlayer.spawn_muzzle_flash(origin_pos, flash_dir, data.projectile_color, style)
	# Attack animation — squash-and-stretch that returns to the idle
	# baseline. We can't read sprite.scale live because the idle
	# breathing loop is tweening it; instead we derive the baseline
	# from data.sprite_scale (or fall back to Vector2.ONE).
	if sprite:
		var base_sc: Vector2 = _baseline_scale
		var atk_tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		atk_tween.tween_property(sprite, "scale", Vector2(base_sc.x * 0.88, base_sc.y * 1.18), 0.06)
		atk_tween.tween_property(sprite, "scale", Vector2(base_sc.x * 1.22, base_sc.y * 0.92), 0.08)
		atk_tween.tween_property(sprite, "scale", base_sc, 0.14)

	# Prefer the pool to avoid instantiate/queue_free churn at scale.
	# Falls back to instantiation if pool is unavailable (loading order).
	# Script identity (_projectile_script) is checked instead of has_method()
	# because has_method() can spuriously return false in headless Godot at
	# high time_scale when the GDScript VM is under pressure (#647).
	var projectile: Node = null
	if ProjectilePool and ProjectilePool.has_method("acquire"):
		projectile = ProjectilePool.acquire()

	# Validate the pool-returned node. Checks:
	#   (a) null / freed instance
	#   (b) script detached (scene-transition race — issue #647)
	#   (c) wrong script (shouldn't happen, but guard it)
	if not _is_valid_projectile(projectile):
		if projectile != null and is_instance_valid(projectile):
			# Discard without recycling — a broken node must not re-enter pool.
			projectile.queue_free()
		# Fresh instantiation from cached scene.
		projectile = _projectile_scene.instantiate()
		var scene_root := get_tree().current_scene
		if scene_root == null:
			projectile.queue_free()
			return
		scene_root.add_child(projectile)
		# If even a fresh instance is broken, the cached PackedScene may have
		# a stale script reference. Force a cache-bypass reload from disk.
		if not _is_valid_projectile(projectile):
			projectile.queue_free()
			var fresh_scene := ResourceLoader.load(
				"res://scenes/projectiles/base_projectile.tscn",
				"", ResourceLoader.CACHE_MODE_IGNORE
			) as PackedScene
			if fresh_scene == null:
				push_error("[tower] projectile scene unloadable — aborting shot")
				return
			# Also refresh the cached references so future shots work.
			_projectile_scene = fresh_scene
			projectile = _projectile_scene.instantiate()
			scene_root.add_child(projectile)
			# Update _projectile_script to match the freshly-loaded scene's script.
			# CACHE_MODE_IGNORE produces a new Script object with different identity
			# from the old cached _projectile_script — updating here lets the next
			# shot's identity check pass without falling back to has_method.
			var refreshed := projectile.get_script() as Script
			if refreshed != null:
				_projectile_script = refreshed
			# Only abort if the node is literally null/freed — GDScript VM
			# pressure in headless CI at 8× time_scale can cause spurious
			# has_method()/property-check failures on a perfectly valid node,
			# which previously aborted every shot and produced kills=0 (#770).
			if projectile == null or not is_instance_valid(projectile):
				push_error("[tower] projectile scene permanently broken — aborting shot")
				return
	elif not projectile.is_inside_tree():
		# Pool returned a valid+scripted node that wasn't added to the tree
		# (prewarm is deferred — possible on wave-1 in headless CI).
		# An unparented node cannot _process() → projectile never moves → 0 kills.
		var scene_root := get_tree().current_scene
		if scene_root:
			scene_root.add_child(projectile)
		else:
			projectile.queue_free()
			return
	# Credit kills from this projectile back to us (used by tower-info
	# panel for the per-tower kill counter)
	projectile.set_meta("source_tower", self)
	# Crit roll (ROADMAP #38). Kühne pulls 2× damage at configured
	# chance; other towers skip by default (crit_chance = 0).
	var outbound_damage: float = effective_damage
	if data.crit_chance > 0.0 and randf() < data.crit_chance:
		outbound_damage *= data.crit_multiplier
		if current_target and current_target.has_method("flash_crit"):
			current_target.flash_crit()
	projectile.setup(
		origin_pos,
		current_target,
		outbound_damage,
		data.damage_type,
		data.projectile_color,
		data.is_splash,
		data.splash_radius,
		data.splash_damage_pct,
		data.slow_amount,
		data.slow_duration + _synergy_bonus.get("slow_dur_add", 0.0),
		data.projectile_style,
		data.leaves_ground_pool,
		data.ground_pool_duration,
		data.ground_pool_damage_per_tick,
		data.ground_pool_radius,
		shoot_tier
	)
	# Carry pierce budget across to the projectile (Lemurius).
	# Banana-Volleyball synergy (JoJo+Lemurius) adds +1 pierce via _synergy_bonus.
	if "remaining_pierce" in projectile:
		projectile.remaining_pierce = max(0, data.pierce_count - 1 + _synergy_bonus.get("pierce_add", 0))
	# Amösius pull fraction.
	if "pull_path_fraction" in projectile:
		projectile.pull_path_fraction = data.pull_path_fraction


func upgrade() -> bool:
	if upgrade_level >= data.upgrade_costs.size():
		return false

	var cost: int = data.upgrade_costs[upgrade_level]
	if not CurrencyManager.spend_gold(cost):
		return false

	upgrade_level += 1
	_recalculate_stats()
	_update_range_collider()
	_update_visual()
	_apply_tier_scale()
	_rebuild_pip_cache()
	queue_redraw()  # refresh tier pips from cache
	tower_upgraded.emit(self, upgrade_level)

	SfxManager.play_upgrade()
	# Upgrade celebration animation
	if sprite:
		var base_sc: Vector2 = _baseline_scale
		var upg_tween := create_tween()
		upg_tween.tween_property(sprite, "scale", base_sc * 1.3, 0.15)
		upg_tween.tween_property(sprite, "scale", base_sc, 0.2)
		upg_tween.parallel().tween_property(sprite, "modulate", Color(1.5, 1.3, 0.5), 0.15)
		upg_tween.tween_property(sprite, "modulate", Color.WHITE, 0.2)
	if EffectPlayer and EffectPlayer.has_method("spawn_place_sparkles"):
		EffectPlayer.spawn_place_sparkles(global_position)

	# Floating upgrade text
	var upg_label := Label.new()
	if upgrade_level <= data.upgrade_names.size():
		upg_label.text = data.upgrade_names[upgrade_level - 1]
	else:
		upg_label.text = "UPGRÄDET!"
	upg_label.add_theme_font_size_override("font_size", 16)
	upg_label.add_theme_color_override("font_color", Color(1, 0.85, 0.1))
	upg_label.add_theme_color_override("font_outline_color", Color.BLACK)
	upg_label.add_theme_constant_override("outline_size", 3)
	upg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	upg_label.position = Vector2(-50, -60)
	upg_label.z_index = 20
	add_child(upg_label)
	var lbl_tween := create_tween()
	lbl_tween.set_parallel(true)
	lbl_tween.tween_property(upg_label, "position:y", -100.0, 1.0)
	lbl_tween.tween_property(upg_label, "modulate:a", 0.0, 1.0)
	lbl_tween.chain().tween_callback(upg_label.queue_free)

	return true


func flash_earn(amount: int) -> void:
	var label := Label.new()
	label.text = "+%d G" % amount
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(1, 0.9, 0.1))
	label.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0, 1))
	label.add_theme_constant_override("outline_size", 3)
	label.position = Vector2(-20, -60)
	label.z_index = 12
	add_child(label)
	var tw := create_tween().set_parallel(true)
	tw.tween_property(label, "position:y", -95.0, 0.7)
	tw.tween_property(label, "modulate:a", 0.0, 0.7)
	tw.chain().tween_callback(label.queue_free)


func play_place_animation() -> void:
	if sprite == null:
		return
	# CRITICAL FIX: previously tweened `self.scale` to `_baseline_scale`,
	# which is the SPRITE's scale ratio (~0.47 for friend photos at
	# target_size=240). That left the placed tower at scale=0.47 while
	# the ghost (which never ran this anim) stayed at scale=1.0 — placed
	# tower was visibly HALF the size of the ghost. The whole-tower
	# scale should always be 1.0; only sprite.scale carries the size
	# fitting. So tween self.scale from ZERO → ONE for the pop, sprite
	# already has the correct size.
	scale = Vector2.ZERO
	var tw := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(self, "scale", Vector2(1.15, 1.15), 0.18)
	tw.tween_property(self, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE)
	# Gold sparkle particles at the tower base — "deployed" feedback.
	if EffectPlayer and EffectPlayer.has_method("spawn_place_sparkles"):
		EffectPlayer.spawn_place_sparkles(global_position)


func sell() -> void:
	# Leave the group immediately so synergy scans triggered by tower_sold
	# don't count this tower as still present.
	remove_from_group("towers")
	var refund: int
	if data.has_branching_upgrades():
		refund = data.get_sell_value_branched(path_a_tier, path_b_tier)
	else:
		refund = data.get_sell_value(upgrade_level)
	CurrencyManager.add_gold(refund)
	tower_sold.emit(self)
	is_placed = false  # stop attacking
	SfxManager.play_sell()
	# Shrink animation before removing
	var sell_tween := create_tween()
	sell_tween.tween_property(self, "scale", Vector2.ZERO, 0.3).set_ease(Tween.EASE_IN)
	sell_tween.tween_callback(queue_free)


func can_upgrade() -> bool:
	if upgrade_level >= data.upgrade_costs.size():
		return false
	return CurrencyManager.can_afford(data.upgrade_costs[upgrade_level])


func get_upgrade_cost() -> int:
	if upgrade_level >= data.upgrade_costs.size():
		return -1
	return data.upgrade_costs[upgrade_level]


# -- Branching upgrades (BTD5-style) --

func can_upgrade_path(path_letter: String) -> bool:
	if not data or not data.has_branching_upgrades():
		return false
	var tier := path_a_tier if path_letter == "a" else path_b_tier
	var costs: Array[int] = data.path_a_costs if path_letter == "a" else data.path_b_costs
	if tier >= costs.size():
		return false
	return CurrencyManager.can_afford(costs[tier])


func get_path_upgrade_cost(path_letter: String) -> int:
	if not data or not data.has_branching_upgrades():
		return -1
	var tier := path_a_tier if path_letter == "a" else path_b_tier
	var costs: Array[int] = data.path_a_costs if path_letter == "a" else data.path_b_costs
	if tier >= costs.size():
		return -1
	return costs[tier]


func get_path_next_tier_name(path_letter: String) -> String:
	if not data or not data.has_branching_upgrades():
		return ""
	var tier := path_a_tier if path_letter == "a" else path_b_tier
	var names: Array[String] = data.path_a_tier_names if path_letter == "a" else data.path_b_tier_names
	if tier >= names.size():
		return ""
	return names[tier]


func upgrade_path(path_letter: String) -> bool:
	if not can_upgrade_path(path_letter):
		return false
	var cost := get_path_upgrade_cost(path_letter)
	if not CurrencyManager.spend_gold(cost):
		return false
	if path_letter == "a":
		path_a_tier += 1
	else:
		path_b_tier += 1
	upgrade_level = path_a_tier + path_b_tier  # keep legacy counter in sync for sell_value, etc.
	_maybe_swap_tier3_sprite(path_letter)
	_recalculate_stats()
	_update_range_collider()
	_apply_path_tint()
	_apply_tier_scale()
	_rebuild_pip_cache()
	queue_redraw()  # refresh tier pips from cache
	tower_upgraded.emit(self, upgrade_level)
	SfxManager.play_upgrade()

	if sprite:
		var base_sc2: Vector2 = _baseline_scale
		# Capture the tint _apply_path_tint() just set so the flash animation
		# returns to it instead of resetting to WHITE (which erased the tint).
		var target_modulate: Color = sprite.modulate
		var upg_tween := create_tween()
		upg_tween.tween_property(sprite, "scale", base_sc2 * 1.2, 0.15)
		upg_tween.tween_property(sprite, "scale", base_sc2, 0.2)
		upg_tween.parallel().tween_property(sprite, "modulate", Color(1.45, 1.3, 0.6), 0.15)
		upg_tween.tween_property(sprite, "modulate", target_modulate, 0.2)
	if EffectPlayer and EffectPlayer.has_method("spawn_place_sparkles"):
		EffectPlayer.spawn_place_sparkles(global_position)

	var upg_label := Label.new()
	var tier_name := ""
	if path_letter == "a" and path_a_tier > 0 and path_a_tier - 1 < data.path_a_tier_names.size():
		tier_name = data.path_a_tier_names[path_a_tier - 1]
	elif path_letter == "b" and path_b_tier > 0 and path_b_tier - 1 < data.path_b_tier_names.size():
		tier_name = data.path_b_tier_names[path_b_tier - 1]
	upg_label.text = tier_name if tier_name != "" else "UPGRÄDET!"
	upg_label.add_theme_font_size_override("font_size", 18)
	upg_label.add_theme_color_override("font_color", Color(1, 0.85, 0.1))
	upg_label.add_theme_color_override("font_outline_color", Color.BLACK)
	upg_label.add_theme_constant_override("outline_size", 3)
	upg_label.position = Vector2(-80, -60)
	upg_label.z_index = 20
	add_child(upg_label)
	var lbl_tween := create_tween()
	lbl_tween.set_parallel(true)
	lbl_tween.tween_property(upg_label, "position:y", -100.0, 1.0)
	lbl_tween.tween_property(upg_label, "modulate:a", 0.0, 1.0)
	lbl_tween.chain().tween_callback(upg_label.queue_free)

	return true


func _apply_path_tint() -> void:
	if not sprite or not data or not data.has_branching_upgrades():
		return
	if path_a_tier == 0 and path_b_tier == 0:
		sprite.modulate = Color.WHITE
		return
	var max_tier: int = max(path_a_tier, path_b_tier)
	# Strength/brightness LUT. Brightness < 1.0 darkens the sprite so the
	# hue shift reads clearly from across the map — pure strength change is
	# subtle on bright sprites. Tier 1 brightness 0.88 = 12% darker (was 1.0,
	# invisible on bright textures per playtest-feedback #630/#646/#660).
	var strength: float = 1.0
	var brightness: float = 0.82
	match max_tier:
		1:
			strength = 1.0
			brightness = 0.82
		2:
			strength = 1.0
			brightness = 0.76
		_:  # 3+
			strength = 1.0
			brightness = 0.70
	# Give path-B tiers 1.5× blend weight so investing in B is clearly
	# visible even when A is at max tier (playtest-feedback #562).
	# When both paths are invested, boost brightness so dual-path towers
	# look rewarded rather than darker (combined_tier > max_tier → extra
	# brightness at 0.06 per extra tier, capped at 0.95).
	var combined_tier: int = path_a_tier + path_b_tier
	if path_a_tier > 0 and path_b_tier > 0 and combined_tier > max_tier:
		brightness = minf(brightness + 0.06 * (combined_tier - max_tier), 0.95)
	# Per-tier hue rotation: each additional B-path tier beyond T1 shifts the
	# hue by 18° and boosts saturation by 10%, making B1/B2/B3 visually
	# distinct even when A is already at max tier (fixes playtest-feedback #666).
	# A-path gets a smaller 12°/8% shift for symmetry.
	var effective_b_tint: Color = data.path_b_tint
	if path_b_tier >= 2:
		var extra: int = path_b_tier - 1
		var bh: float = fmod(data.path_b_tint.h + (18.0 / 360.0) * extra, 1.0)
		effective_b_tint = Color.from_hsv(bh, minf(data.path_b_tint.s + 0.10 * extra, 1.0), data.path_b_tint.v)
	var effective_a_tint: Color = data.path_a_tint
	if path_a_tier >= 2:
		var extra: int = path_a_tier - 1
		var ah: float = fmod(data.path_a_tint.h + (12.0 / 360.0) * extra, 1.0)
		effective_a_tint = Color.from_hsv(ah, minf(data.path_a_tint.s + 0.08 * extra, 1.0), data.path_a_tint.v)
	var a_weight: float = float(path_a_tier)
	var b_weight: float = float(path_b_tier) * 1.5
	var total: float = a_weight + b_weight
	var blended: Color = effective_a_tint * (a_weight / total) + effective_b_tint * (b_weight / total)
	var tinted: Color = Color.WHITE.lerp(blended, strength)
	sprite.modulate = Color(tinted.r * brightness, tinted.g * brightness, tinted.b * brightness, tinted.a)


func _apply_tier_scale() -> void:
	# Per-tier sprite scale — user directive: upgrades need to READ from
	# across the map, not require squinting. Each tier adds ~8%/16%/25%
	# to the baseline scale. Also tween the change so it reads as a
	# satisfying growth on purchase.
	if sprite == null:
		return
	var tier: int = max(path_a_tier, path_b_tier)
	if not (data and data.has_branching_upgrades()):
		tier = upgrade_level
	var scale_factor: float = 1.0
	match tier:
		0: scale_factor = 1.0
		1: scale_factor = 1.08
		2: scale_factor = 1.18
		_: scale_factor = 1.28   # tier 3+
	var target: Vector2 = _baseline_scale * scale_factor
	# Pop tween: quick bounce past target, settle back — "level up!" feel
	var tw := create_tween()
	tw.tween_property(sprite, "scale", target * 1.15, 0.14).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(sprite, "scale", target, 0.18).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_update_tier_glow(tier)
	_update_tier_hat(tier)


func _update_tier_hat(tier: int) -> void:
	# Procedural crown (path A) or badge (path B) drawn above the tower head
	# at tier >= 1. Hat scales with tier scale. ROADMAP D8.
	var old_hat: Node2D = get_node_or_null("TierHat")
	if old_hat:
		old_hat.queue_free()
	if tier <= 0 or data == null:
		return

	var is_path_a: bool = path_b_tier <= path_a_tier or not data.has_branching_upgrades()
	var col_a: Color = data.path_a_tint if data.has_branching_upgrades() else Color(1.0, 0.85, 0.1)
	var col_b: Color = data.path_b_tint if data.has_branching_upgrades() else Color(0.45, 0.80, 1.0)

	var scale_factors: Array = [1.0, 1.08, 1.18, 1.28]
	var sf: float = scale_factors[clampi(tier, 0, 3)]
	# Hat sits at the top of the sprite. target_size/2 = 65px is the visual
	# half-height (set in _update_visual target_size=130). Extra -4px gap.
	var hat_y: float = -(65.0 * sf + 4.0)

	var hat_node := Node2D.new()
	hat_node.name = "TierHat"
	hat_node.position = Vector2(0.0, hat_y)
	hat_node.z_index = 3
	hat_node.set_meta("tier", tier)
	hat_node.set_meta("is_path_a", is_path_a)
	hat_node.set_meta("col_a", col_a)
	hat_node.set_meta("col_b", col_b)
	hat_node.set_script(_hat_script())
	add_child(hat_node)

	# Pop-in animation — bounces into view on upgrade
	hat_node.scale = Vector2.ZERO
	var ht := create_tween()
	ht.tween_property(hat_node, "scale", Vector2(1.25, 1.25), 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	ht.tween_property(hat_node, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_SINE)


func _hat_script() -> Script:
	# Inline script — crown for path A, badge/sash for path B.
	# Tier 1 = small, tier 2 = medium, tier 3 = elaborate.
	var src := """
extends Node2D
func _draw() -> void:
	var tier: int = get_meta("tier", 1)
	var is_a: bool = get_meta("is_path_a", true)
	var col: Color = get_meta("col_a", Color(1,0.85,0.1)) if is_a else get_meta("col_b", Color(0.45,0.8,1))
	var s: float = 0.62 + tier * 0.19
	var dark := Color(col.r*0.35, col.g*0.35, col.b*0.35, 1.0)
	if is_a:
		_draw_crown(tier, col, dark, s)
	else:
		_draw_band(tier, col, dark, s)

func _draw_crown(tier: int, col: Color, dark: Color, s: float) -> void:
	var w := 20.0 * s
	var bh := 5.0 * s
	var sh := (8.0 + tier * 3.5) * s
	var ns: int = tier + 2
	var sp := w / ns
	# Base bar with outline
	draw_rect(Rect2(-w*0.5, -bh, w, bh), dark)
	draw_rect(Rect2(-w*0.5+1.5, -bh+1.5, w-3.0, bh-1.5), col)
	# Spikes
	for i in ns:
		var cx := -w*0.5 + sp*(i + 0.5)
		var pts := PackedVector2Array([Vector2(cx - sp*0.36, -bh), Vector2(cx, -bh - sh), Vector2(cx + sp*0.36, -bh)])
		draw_polygon(pts, PackedColorArray([col, col, col]))
	# Gem on tallest spike (tier 2+)
	if tier >= 2:
		var gy := -bh - sh * 0.8
		draw_circle(Vector2(0.0, gy), 3.2*s, Color(1.0, 0.2, 0.2, 0.95))
		draw_arc(Vector2(0.0, gy), 3.2*s, 0.0, TAU, 16, Color(1,1,1,0.85), 1.2)

func _draw_band(tier: int, col: Color, dark: Color, s: float) -> void:
	var w := 22.0 * s
	var h := 6.5 * s
	# Outline then fill
	draw_rect(Rect2(-w*0.5, -h*0.5, w, h), dark)
	draw_rect(Rect2(-w*0.5+1.5, -h*0.5+1.5, w-3.0, h-3.0), col)
	# Stars: 1 at tier 1, 2 at tier 2, 3 at tier 3
	for i in tier:
		var sx: float = 0.0
		if tier > 1:
			sx = (-0.5 + float(i + 1) / float(tier + 1)) * w * 1.1
		draw_circle(Vector2(sx, 0.0), 3.8*s, Color(1, 1, 0.65, 0.95))
		draw_circle(Vector2(sx, 0.0), 2.0*s, Color(1, 0.82, 0.1, 1.0))
"""
	var scr := GDScript.new()
	scr.source_code = src
	scr.reload()
	return scr


func _update_tier_glow(tier: int) -> void:
	# Per-tier glow ring (ROADMAP #23). Ring radius + alpha scale with
	# tier so upgrades READ from across the map. Uses a single Node2D
	# with custom _draw cached as _glow_node; recreated on tier change.
	# Kill the old pulse tween BEFORE freeing the glow node so its looping
	# lambda cannot fire on a freed Node2D (was: "Lambda capture freed" CI spam).
	if _glow_pulse_tween != null and _glow_pulse_tween.is_valid():
		_glow_pulse_tween.kill()
	_glow_pulse_tween = null
	var glow: Node2D = get_node_or_null("TierGlow")
	if glow:
		glow.queue_free()
	if tier <= 0 or data == null:
		return
	glow = Node2D.new()
	glow.name = "TierGlow"
	glow.z_index = -2  # below sprite
	var ring_color: Color = data.projectile_color
	ring_color.a = 0.0  # alpha driven by _draw
	var tier_radius: float = 30.0 + tier * 14.0
	var tier_alpha: float = 0.25 + tier * 0.15
	var pulse_speed: float = 2.0 + tier * 0.5
	glow.set_meta("ring_color", ring_color)
	glow.set_meta("radius", tier_radius)
	glow.set_meta("alpha", tier_alpha)
	glow.set_script(_glow_script())
	add_child(glow)
	# Pulse tween — stored in _glow_pulse_tween so it can be killed on
	# the next tier change before the old glow node is freed.
	_glow_pulse_tween = create_tween().set_loops()
	_glow_pulse_tween.tween_method(func(v: float): glow.modulate.a = v, 0.55, 1.0, 1.0 / pulse_speed).set_trans(Tween.TRANS_SINE)
	_glow_pulse_tween.tween_method(func(v: float): glow.modulate.a = v, 1.0, 0.55, 1.0 / pulse_speed).set_trans(Tween.TRANS_SINE)


func _glow_script() -> Script:
	# Tiny inline script so the glow Node2D draws its own ring without
	# needing a dedicated .gd file — keeps the feature self-contained.
	# Perf: 2 layers × 20 seg (was 5 × 48) — same soft-glow look, 83% fewer
	# draw calls per frame. Tween still pulses modulate.a for the beat.
	var src := """
extends Node2D
func _draw() -> void:
	var r: float = get_meta(\"radius\", 40.0)
	var c: Color = get_meta(\"ring_color\", Color.YELLOW)
	var a: float = get_meta(\"alpha\", 0.4)
	draw_arc(Vector2.ZERO, r * 0.88, 0.0, TAU, 20, Color(c.r, c.g, c.b, a * 0.72), 5.0, true)
	draw_arc(Vector2.ZERO, r * 1.12, 0.0, TAU, 20, Color(c.r, c.g, c.b, a * 0.28), 3.5, true)
"""
	var s := GDScript.new()
	s.source_code = src
	s.reload()
	return s


func show_range(visible_flag: bool) -> void:
	if range_indicator:
		range_indicator.visible = visible_flag


func _update_visual() -> void:
	if not sprite:
		return

	var tex: Texture2D = null

	# Priority order:
	# 1. Dev-picker preferred variant (set via DevMenu)
	# 2. v2 cartoon art if it shipped via art-request (e.g. cordula_v2.png)
	# 3. Friend photo (uploaded by user)
	# 4. data.custom_texture (default cartoon)
	if GameManager and GameManager.has_method("get_preferred_variant"):
		var pref_path: String = GameManager.get_preferred_variant("towers/%s" % data.id)
		if pref_path != "" and ResourceLoader.exists(pref_path):
			tex = load(pref_path)
	if tex == null and data.friend_character_id != "":
		var v2_id := data.friend_character_id.replace("friend_", "")
		var v2_path := "res://assets/textures/towers/%s_v2.png" % v2_id
		if ResourceLoader.exists(v2_path):
			tex = load(v2_path)
	if tex == null and data.friend_character_id != "":
		var photo := GameManager.get_friend_photo(data.friend_character_id)
		if photo:
			tex = photo
	if tex == null and data.custom_texture:
		tex = data.custom_texture

	if tex:
		sprite.texture = tex
		var max_dim := maxf(tex.get_width(), tex.get_height())
		# Portrait textures (AI-generated img2img or uploaded friend photos)
		# fill the entire texture area with a face; max_dim is typically
		# 1024px or larger. Cartoon sprites (lemurius.png, amosius.png) leave
		# ~70% transparent padding; max_dim is 512px or smaller.
		# Use 72px target for portraits so the visible face matches the
		# visual weight of Lemurius's ~40px cartoon character in its 130px circle.
		# Also treat ImageTexture (from get_friend_photo()) as portrait regardless
		# of size since it's always a user-uploaded photo.
		var is_portrait := (tex is ImageTexture) or (max_dim >= 900)
		var target_size := 72.0 if is_portrait else 130.0
		if max_dim > 0:
			var s := target_size / max_dim
			_baseline_scale = Vector2(s, s)
		else:
			# get_width() returned 0 — headless/dummy renderer hasn't
			# initialized the texture yet. Use a conservative fallback
			# so the sprite doesn't render at infinite scale.
			_baseline_scale = Vector2(target_size / 512.0, target_size / 512.0)
		sprite.scale = _baseline_scale
		sprite.modulate = Color.WHITE
		# LINEAR_WITH_MIPMAPS smooths jagged edges from background removal.
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	else:
		_baseline_scale = Vector2.ONE
		if data and "sprite_scale" in data and typeof(data.sprite_scale) == TYPE_VECTOR2:
			_baseline_scale = data.sprite_scale
		sprite.scale = _baseline_scale
		sprite.modulate = data.base_color
	# Draw base pedestal under tower
	queue_redraw()


func _draw() -> void:
	if not is_placed:
		return
	# Procedural pedestal — replaced 3 stacked draw_circle rings with a
	# layered design: soft drop shadow + ground disc + bevel highlight
	# arc + thin gold accent ring. Reads as "professional museum
	# pedestal" rather than "3 brown circles". Sized for 130px sprite.
	var ground_y: float = 16.0
	# Layer 1: wide soft drop shadow (elliptical via Y-squashed circle)
	draw_circle(Vector2(0, ground_y), 36.0, Color(0, 0, 0, 0.18))
	draw_circle(Vector2(0, ground_y - 1), 28.0, Color(0, 0, 0, 0.32))
	# Layer 2: stone disc base (radial-feel via 3 concentric rings,
	# darker at the rim for vignette).
	draw_circle(Vector2.ZERO, 32.0, Color(0.16, 0.13, 0.10, 0.85))  # rim shadow
	draw_circle(Vector2.ZERO, 30.0, Color(0.34, 0.27, 0.20, 1.0))   # mid stone
	draw_circle(Vector2.ZERO, 26.0, Color(0.50, 0.42, 0.32, 1.0))   # inner stone
	# Layer 3: gold accent ring — thin, reads as polished trim
	draw_arc(Vector2.ZERO, 30.0, 0, TAU, 48, Color(1.0, 0.78, 0.22, 0.85), 1.5, true)
	# Layer 4: bevel highlight — top arc only, gives 3D feel
	draw_arc(Vector2(-1, -2), 28.0, PI * 1.05, PI * 1.95, 28, Color(1, 0.95, 0.78, 0.40), 2.5, true)
	# Layer 5: tiny inner highlight dot for "glint"
	draw_circle(Vector2(-8, -10), 2.5, Color(1, 0.98, 0.85, 0.45))
	# Tier pips — replay the precomputed cache. Positions + tints are
	# refreshed in `_rebuild_pip_cache()` on upgrade so _draw never calls
	# cos()/sin() per frame. ROADMAP PERF #7.
	for entry in _pip_cache:
		var p: Vector2 = entry[0]
		var tint: Color = entry[1]
		draw_circle(p, 6.0, Color(0, 0, 0, 0.55))
		draw_circle(p, 4.5, tint)
	# Synergie-Combo badge — gold star above the tower when a pair synergy is active
	if not _synergy_bonus.is_empty():
		_draw_synergy_badge()


func _draw_synergy_badge() -> void:
	# 5-pointed gold star (12×12 px), positioned top-right of the pedestal.
	const GOLD: Color = Color(1.0, 0.824, 0.478, 1.0)   # #FFD27A
	const OUTLINE: Color = Color(0.58, 0.44, 0.14, 0.9)
	const R_OUT: float = 7.0
	const R_IN: float = 3.0
	var cx: float = 24.0  # right of center so it doesn't overlap tier hat
	var cy: float = -68.0  # above the sprite baseline
	var pts := PackedVector2Array()
	for i in 10:
		var a: float = -PI * 0.5 + (float(i) * PI / 5.0)
		var r: float = R_OUT if i % 2 == 0 else R_IN
		pts.append(Vector2(cx + cos(a) * r, cy + sin(a) * r))
	draw_colored_polygon(pts, GOLD)
	var loop := pts.duplicate()
	loop.append(pts[0])
	draw_polyline(loop, OUTLINE, 1.0)


func _rebuild_pip_cache() -> void:
	_pip_cache.clear()
	if not data:
		return
	const RING_R: float = 36.0  # matches the 32-radius pedestal
	const SPREAD: float = 0.22
	if data.has_branching_upgrades():
		_append_pip_arc(path_a_tier, -PI * 0.92, 1.0, data.path_a_tint, RING_R, SPREAD)
		_append_pip_arc(path_b_tier, -PI * 0.08, -1.0, data.path_b_tint, RING_R, SPREAD)
	elif upgrade_level > 0:
		_append_pip_arc(upgrade_level, -PI * 0.5, 1.0, Color(1, 0.9, 0.3), RING_R, SPREAD)


func _append_pip_arc(tier: int, base_angle: float, dir: float, tint: Color, ring_r: float, spread: float) -> void:
	if tier <= 0:
		return
	for i in tier:
		var a: float = base_angle + dir * spread * float(i)
		var p := Vector2(cos(a), sin(a)) * ring_r
		_pip_cache.append([p, tint])


func _update_range_collider() -> void:
	if detection_area and detection_area.has_node("CollisionShape2D"):
		var col_shape: CollisionShape2D = detection_area.get_node("CollisionShape2D")
		var circle := CircleShape2D.new()
		circle.radius = effective_range
		col_shape.shape = circle

	if range_indicator and range_indicator.has_method("set_radius"):
		range_indicator.set_radius(effective_range)
	if range_indicator and range_indicator.has_method("set_tint") and data and data.projectile_color.a > 0.01:
		range_indicator.set_tint(data.projectile_color)


func _on_detection_area_area_entered(area: Area2D) -> void:
	var enemy := area.get_parent()
	# Dedupe: pool reuse can re-fire area_entered for an already-tracked
	# enemy when the HitBox was deactivated + reactivated while still
	# overlapping our DetectionArea (area_exited may skip on pool-park).
	# Audit P1: duplicate entries were biasing target-mode selection.
	if enemy is BaseEnemy and enemy not in _enemies_in_range:
		_enemies_in_range.append(enemy)


func _on_detection_area_area_exited(area: Area2D) -> void:
	var enemy := area.get_parent()
	if enemy is BaseEnemy:
		_enemies_in_range.erase(enemy)


func _maybe_swap_tier3_sprite(path_letter: String) -> void:
	# At tier 1/2/3 on either path, try to swap the tower sprite to the
	# dedicated tier-specific variant (e.g. basic_t1a.png, basic_t2b.png,
	# basic_t3a.png). Falls back silently to whatever's currently set if
	# the asset doesn't exist — the next-lower-tier sprite stays.
	# Order of preference at any given tier T:
	#   1. <id>_t<T><path>.png  (tier-specific upgrade art)
	#   2. existing sprite      (no swap, keep current)
	# Art-request #263 fills in tier 1/2 variants for the full matrix.
	if not sprite or not data:
		return
	var tier := path_a_tier if path_letter == "a" else path_b_tier
	if tier < 1:
		return
	var tex_path := "res://assets/textures/towers/%s_t%d%s.png" % [data.id, tier, path_letter]
	if not ResourceLoader.exists(tex_path):
		return
	var new_tex: Texture2D = load(tex_path)
	if new_tex == null:
		return
	sprite.texture = new_tex
	# Re-fit baseline using same portrait/cartoon heuristic as _update_visual:
	# tier-swap art ≥ 900px max-dim = portrait (72px); cartoon art < 900px = 130px.
	var max_dim := maxf(new_tex.get_width(), new_tex.get_height())
	var target_swap := 72.0 if max_dim >= 900 else 130.0
	var s := target_swap / max_dim if max_dim > 0 else target_swap / 512.0
	_baseline_scale = Vector2(s, s)
	sprite.scale = _baseline_scale


# --- Targeting mode helpers (per-tower BTD5-style) ---

func cycle_target_mode() -> void:
	# Cycle through FIRST → LAST → CLOSEST → STRONGEST → back to FIRST.
	# Called from the tower-info panel's targeting button.
	var current: int = target_mode_override if target_mode_override >= 0 else int(data.target_mode)
	target_mode_override = (current + 1) % 4
	# Force immediate retarget so the new mode applies on next tick
	current_target = null
	if SfxManager:
		SfxManager.play_click()


func get_target_mode_label() -> String:
	# Swiss German labels matching BTD5's First/Last/Strong/Close.
	var mode: int = target_mode_override if target_mode_override >= 0 else int(data.target_mode)
	match mode:
		TowerData.TargetMode.FIRST:     return "Erschti"   # First (farthest along path)
		TowerData.TargetMode.LAST:      return "Letschti"  # Last (closest to spawn)
		TowerData.TargetMode.CLOSEST:   return "Nöchschti" # Closest to tower
		TowerData.TargetMode.STRONGEST: return "Stärchsti" # Strongest (most HP)
		_: return "Erschti"


# --- Active abilities (BTD5-style, Tier 1C) ---

func get_max_tier() -> int:
	# Highest tier this tower has reached on either path. Used to gate
	# active-ability availability (only tier 3+ unlock abilities).
	return max(path_a_tier, path_b_tier)


func has_active_ability() -> bool:
	if not data:
		return false
	if get_max_tier() < 3:
		return false
	return data.id in ["basic", "sniper", "splash", "cordula", "slow"]


func get_ability_label() -> String:
	if not data:
		return ""
	match data.id:
		"basic":   return "BANANI-STURM"  # 5s triple-fire (60s CD)
		"sniper":  return "POLLEN-WOLKE"  # placeholder for future
		"splash":  return "MEGA-SPRITZ"   # placeholder
		"cordula": return "VOLLEY-TORNADO" # placeholder
		"slow":    return "ZUNGE-RUCK"    # placeholder
	return ""


func get_ability_cd_max() -> float:
	if not data:
		return 60.0
	match data.id:
		"basic":   return 60.0
		"sniper":  return 90.0
		"splash":  return 120.0
		"cordula": return 90.0
		"slow":    return 60.0
	return 60.0


func can_trigger_ability() -> bool:
	return has_active_ability() and ability_cooldown_remaining <= 0.0


func trigger_active_ability() -> bool:
	# Returns true if the ability actually fired. Per-tower implementations
	# below; fallback is "fire 1 quick volley + reset cooldown" so missing
	# implementations are at least non-broken.
	if not can_trigger_ability():
		return false
	ability_cooldown_remaining = get_ability_cd_max()
	match data.id:
		"basic":
			# Banani-Sturm: 5s of 3× fire rate
			ability_triple_fire_remaining = 5.0
			_float_taunt("BANANI-STURM!")
		"sniper":
			# Pollen-Wolke: 6s sustained 3× fire rate — methodical burst
			ability_triple_fire_remaining = 6.0
			_float_taunt("POLLEN-WOLKE!")
		"splash":
			# Mega-Spritz: 4s of 3× AoE barrages
			ability_triple_fire_remaining = 4.0
			_float_taunt("MEGA-SPRITZ!")
		"cordula":
			# Volley-Tornado: 5s rapid-fire volley
			ability_triple_fire_remaining = 5.0
			_float_taunt("VOLLEY-TORNADO!")
		"slow":
			# Zunge-Ruck: 4s 3× slow bursts — stacks debuff on every enemy
			ability_triple_fire_remaining = 4.0
			_float_taunt("ZUNGE-RUCK!")
		_:
			ability_triple_fire_remaining = 3.0
	if SfxManager and SfxManager.has_method("play_upgrade"):
		SfxManager.play_upgrade()
	return true
