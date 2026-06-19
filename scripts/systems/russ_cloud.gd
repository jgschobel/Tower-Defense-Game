class_name RussCloud
extends Node2D

## "Russ-Wolke" (soot cloud) — left behind by a Röschti-Bombe when it
## dies. Towers within `radius` get `debuff_mult` applied to their
## `effective_speed` while inside the cloud; the multiplier clears the
## frame they leave or the frame the cloud expires.
##
## The cloud is a sibling of enemies/towers (added to the GameLevel
## node), not a child of the dying enemy, so it survives EnemyPool
## release. It self-frees after `duration` seconds.
##
## Multiple overlapping clouds compose multiplicatively per tower
## (each cloud knocks effective_speed further down) which is what we
## want — the player who lets several Röschti-Bombe stack in one
## chokepoint pays harder.

const SAMPLE_HZ: float = 12.0  # per-tower scan rate; 12 Hz is plenty
const FADE_IN: float = 0.18
const FADE_OUT: float = 0.45

var radius: float = 100.0
var duration: float = 3.0
var debuff_mult: float = 0.55
var elapsed: float = 0.0
var _scan_accum: float = 0.0
var _affected: Dictionary = {}  # tower -> true while inside

# Drawing state
var _phase: float = 0.0
var _puff_seeds: Array = []
var _radius_sq: float = 0.0


func _ready() -> void:
	add_to_group("russ_clouds")
	z_index = 4  # above path, below tower portraits
	_radius_sq = radius * radius
	# Stable per-cloud puff layout so the cloud doesn't shimmer randomly
	# every frame. 7 puffs gives enough mass without busy noise.
	_puff_seeds.clear()
	for i in 7:
		var ang: float = randf() * TAU
		var r: float = sqrt(randf()) * radius * 0.55
		_puff_seeds.append({
			"pos": Vector2(cos(ang), sin(ang)) * r,
			"size": randf_range(14.0, 24.0),
			"phase": randf() * TAU,
		})


func _process(delta: float) -> void:
	elapsed += delta
	_phase += delta
	queue_redraw()
	if elapsed >= duration:
		_clear_all_affected()
		queue_free()
		return

	_scan_accum += delta
	if _scan_accum < 1.0 / SAMPLE_HZ:
		return
	_scan_accum = 0.0

	var now_inside: Dictionary = {}
	for tower_node in get_tree().get_nodes_in_group("towers"):
		if tower_node == null or not is_instance_valid(tower_node):
			continue
		if not "debuff_speed_mult" in tower_node:
			continue
		var d_sq: float = (tower_node.global_position - global_position).length_squared()
		if d_sq <= _radius_sq:
			now_inside[tower_node] = true
			# Compose multiplicatively across overlapping clouds —
			# but only once per cloud per tower per frame.
			var current: float = tower_node.debuff_speed_mult
			# Reset per-frame floor on first cloud touching this tower,
			# then chain-multiply. We rely on `_clear_all_affected` to
			# restore 1.0 when the tower leaves.
			if not _affected.has(tower_node):
				tower_node.debuff_speed_mult = current * debuff_mult
				_affected[tower_node] = true

	# Towers that LEFT the cloud since last tick — restore their mult.
	for prev_tower in _affected.keys():
		if not now_inside.has(prev_tower):
			if is_instance_valid(prev_tower) and "debuff_speed_mult" in prev_tower:
				# Undo this cloud's contribution. If multiple clouds were
				# stacking we'll likely just snap to 1.0; the survivor
				# cloud's next scan tick re-applies its own mult.
				prev_tower.debuff_speed_mult = clampf(prev_tower.debuff_speed_mult / debuff_mult, 0.0, 1.0)
				if absf(prev_tower.debuff_speed_mult - 1.0) < 0.001:
					prev_tower.debuff_speed_mult = 1.0
			_affected.erase(prev_tower)


func _clear_all_affected() -> void:
	for tower in _affected.keys():
		if is_instance_valid(tower) and "debuff_speed_mult" in tower:
			tower.debuff_speed_mult = clampf(tower.debuff_speed_mult / debuff_mult, 0.0, 1.0)
			if absf(tower.debuff_speed_mult - 1.0) < 0.001:
				tower.debuff_speed_mult = 1.0
	_affected.clear()


func _draw() -> void:
	# Ease alpha in then out so the cloud doesn't pop on/off.
	var t: float = elapsed
	var alpha: float = 1.0
	if t < FADE_IN:
		alpha = t / FADE_IN
	elif t > duration - FADE_OUT:
		alpha = clampf((duration - t) / FADE_OUT, 0.0, 1.0)

	# Outer haze disc — translucent dark grey.
	var haze: Color = Color(0.16, 0.13, 0.11, 0.30 * alpha)
	draw_circle(Vector2.ZERO, radius, haze)

	# Inner core — slightly oranged (charred-grease tint) so it reads
	# as "Russ" not generic smoke.
	var core: Color = Color(0.35, 0.22, 0.16, 0.38 * alpha)
	draw_circle(Vector2.ZERO, radius * 0.55, core)

	# Smoke puffs — animate by phase-modulated size so the cloud
	# breathes. Caps at ~7 puffs, all pre-seeded.
	for puff in _puff_seeds:
		var size: float = puff.size * (0.85 + 0.18 * sin(_phase * 2.0 + puff.phase))
		var puff_col: Color = Color(0.25, 0.18, 0.14, 0.55 * alpha)
		draw_circle(puff.pos, size, puff_col)
		draw_circle(puff.pos, size * 0.62, Color(0.45, 0.32, 0.22, 0.45 * alpha))

	# Dashed warning ring on the radius boundary so the player can see
	# "this is bad" instead of guessing where the slow starts.
	var ring_col: Color = Color(0.95, 0.55, 0.18, 0.55 * alpha)
	var dash_count: int = 28
	for i in dash_count:
		if i % 2 != 0:
			continue
		var a1: float = (float(i) / dash_count) * TAU + _phase * 0.4
		var a2: float = (float(i + 1) / dash_count) * TAU + _phase * 0.4
		var p1: Vector2 = Vector2(cos(a1), sin(a1)) * radius
		var p2: Vector2 = Vector2(cos(a2), sin(a2)) * radius
		draw_line(p1, p2, ring_col, 2.0)
