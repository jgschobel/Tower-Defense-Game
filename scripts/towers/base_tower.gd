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
# Cached tier-pip geometry — recomputed on upgrade(), reused in _draw
# so per-frame trig is avoided. ROADMAP PERF #7. Stored as
# Array[Array] with entries [position: Vector2, tint: Color].
var _pip_cache: Array = []
# Fitted sprite scale from _update_visual — tweens use this as the idle
# baseline instead of data.sprite_scale. Friend photos are ~1024px so the
# fit scale is ~0.12, not 1.0; tweens returning to data.sprite_scale made
# towers fill the screen on first attack.
var _baseline_scale: Vector2 = Vector2.ONE

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
	if data:
		_apply_data()
		_update_visual()
		_update_range_collider()
	# Kick off the random taunt loop — only fires when is_placed=true
	_start_taunt_loop()
	# Gentle idle life — breathing scale + slight bob. Staggered per
	# tower (random offset) so 5 placed towers don't pulse in lockstep.
	_start_idle_animation()


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
	_float_taunt(lines[randi() % lines.size()])


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


func _apply_data() -> void:
	_recalculate_stats()
	_rebuild_pip_cache()


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


func _process(delta: float) -> void:
	if not is_placed or not data:
		return

	# Farm + support towers have no offensive loop (ROADMAP #38). Idle bob
	# tween keeps them "alive"; gold/buff effects fire from signal hooks.
	if data.gold_per_round > 0 or data.is_support:
		return

	# Clean up dead enemies from range list
	var valid_enemies: Array = []
	for e in _enemies_in_range:
		if is_instance_valid(e) and not e.is_dead:
			valid_enemies.append(e)
	_enemies_in_range = valid_enemies

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
	attack_timer -= delta
	if attack_timer <= 0.0 and current_target:
		_attack()
		attack_timer = 1.0 / effective_speed


func _find_target() -> BaseEnemy:
	if _enemies_in_range.is_empty():
		return null

	# Filter flying if can't target them
	var valid: Array = []
	for e in _enemies_in_range:
		var enemy := e as BaseEnemy
		if enemy == null:
			continue
		if not data.can_target_flying and enemy.data and enemy.data.is_flying:
			continue
		valid.append(enemy)

	if valid.is_empty():
		return null

	match data.target_mode:
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
	# Muzzle flash — colored burst in the direction of the target
	if EffectPlayer and is_instance_valid(current_target):
		var flash_dir := (current_target.global_position - origin_pos).normalized()
		EffectPlayer.spawn_muzzle_flash(origin_pos, flash_dir, data.projectile_color)
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
	# Falls back to instantiation if pool is unavailable (loading order)
	var projectile: Node = null
	if ProjectilePool and ProjectilePool.has_method("acquire"):
		projectile = ProjectilePool.acquire()
	if projectile == null or not is_instance_valid(projectile):
		projectile = _projectile_scene.instantiate()
		var scene_root := get_tree().current_scene
		if scene_root:
			scene_root.add_child(projectile)
		else:
			# Pathological case — no current scene. Bail rather than crash.
			projectile.queue_free()
			return
	# Credit kills from this projectile back to us (used by tower-info
	# panel for the per-tower kill counter)
	projectile.set_meta("source_tower", self)
	# setup() must not throw. If it does, quietly release the projectile.
	if projectile.has_method("setup"):
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
			data.slow_duration,
			data.projectile_style,
			data.leaves_ground_pool,
			data.ground_pool_duration,
			data.ground_pool_damage_per_tick,
			data.ground_pool_radius
		)
		# Carry pierce budget across to the projectile (Lemurius).
		if "remaining_pierce" in projectile:
			projectile.remaining_pierce = max(0, data.pierce_count - 1)
	else:
		push_warning("[tower] projectile has no setup() — releasing")
		if ProjectilePool:
			ProjectilePool.release(projectile)
		else:
			projectile.queue_free()


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


func sell() -> void:
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
		var upg_tween := create_tween()
		upg_tween.tween_property(sprite, "scale", base_sc2 * 1.2, 0.15)
		upg_tween.tween_property(sprite, "scale", base_sc2, 0.2)

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
	# Per-tier visual delta fix (playtest-feedback #80): strength ramp alone
	# collapsed into near-identical greens at A1/A2/A3 because lerp(WHITE,
	# saturated_tint, 0.55..1.0) produces small perceptual steps on an
	# already-green target. We now also darken each step so the player
	# reads tier progression as "getting darker/richer", not just "slightly
	# different green". T1 = pastel, T2 = mid, T3 = rich-dark.
	var max_tier: int = max(path_a_tier, path_b_tier)
	# Lookup-table per tier for strength + brightness. Hand-tuned for
	# perceptual separation against Lemurius green and Cordula orange tints.
	var strength: float = 0.45
	var brightness: float = 1.0
	match max_tier:
		1:
			strength = 0.45
			brightness = 1.0
		2:
			strength = 0.85
			brightness = 0.88
		_:  # 3+
			strength = 1.0
			brightness = 0.72
	# Blend tints by their per-path weights
	var a_weight: float = float(path_a_tier)
	var b_weight: float = float(path_b_tier)
	var total: float = a_weight + b_weight
	var blended: Color = data.path_a_tint * (a_weight / total) + data.path_b_tint * (b_weight / total)
	var tinted: Color = Color.WHITE.lerp(blended, strength)
	# Apply brightness by scaling RGB (keep alpha)
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


func show_range(visible_flag: bool) -> void:
	if range_indicator:
		range_indicator.visible = visible_flag


func _update_visual() -> void:
	if not sprite:
		return

	var tex: Texture2D = null

	if data.friend_character_id != "":
		var photo := GameManager.get_friend_photo(data.friend_character_id)
		if photo:
			tex = photo

	if tex == null and data.custom_texture:
		tex = data.custom_texture

	if tex:
		sprite.texture = tex
		var max_dim := maxf(tex.get_width(), tex.get_height())
		var target_size := 90.0
		var s := target_size / max_dim
		_baseline_scale = Vector2(s, s)
		sprite.scale = _baseline_scale
		sprite.modulate = Color.WHITE
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
	# Soft ellipse drop-shadow BELOW the tower for grounding
	draw_circle(Vector2(0, 16), 32.0, Color(0, 0, 0, 0.25))
	# Stone pedestal rings — adds weight and separation from the background
	draw_circle(Vector2.ZERO, 38.0, Color(0.28, 0.22, 0.18, 0.55))
	draw_circle(Vector2.ZERO, 33.0, Color(0.48, 0.4, 0.32, 0.55))
	draw_circle(Vector2.ZERO, 29.0, Color(0.62, 0.52, 0.42, 0.35))
	# Thin highlight along top edge
	draw_arc(Vector2(-2, -2), 33.0, PI * 1.1, PI * 1.9, 24, Color(1, 0.95, 0.8, 0.25), 2.0)
	# Tier pips — replay the precomputed cache. Positions + tints are
	# refreshed in `_rebuild_pip_cache()` on upgrade so _draw never calls
	# cos()/sin() per frame. ROADMAP PERF #7.
	for entry in _pip_cache:
		var p: Vector2 = entry[0]
		var tint: Color = entry[1]
		draw_circle(p, 5.0, Color(0, 0, 0, 0.55))
		draw_circle(p, 3.5, tint)


func _rebuild_pip_cache() -> void:
	_pip_cache.clear()
	if not data:
		return
	const RING_R: float = 42.0
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
	# At tier 3 on either path, swap the tower sprite to the dedicated t3
	# variant (e.g. basic_t3a.png for Lemurius path-A tier 3). Falls back
	# silently if the asset doesn't exist for this tower.
	if not sprite or not data:
		return
	var tier := path_a_tier if path_letter == "a" else path_b_tier
	if tier < 3:
		return
	var tex_path := "res://assets/textures/towers/%s_t3%s.png" % [data.id, path_letter]
	if not ResourceLoader.exists(tex_path):
		return
	var new_tex: Texture2D = load(tex_path)
	if new_tex == null:
		return
	sprite.texture = new_tex
	# Re-fit baseline scale so the swapped sprite matches the existing fit size.
	var max_dim := maxf(new_tex.get_width(), new_tex.get_height())
	var s := 90.0 / max_dim
	_baseline_scale = Vector2(s, s)
	sprite.scale = _baseline_scale
