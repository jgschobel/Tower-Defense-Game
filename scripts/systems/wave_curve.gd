extends Node
class_name WaveCurve

## BTD5-inspired difficulty curve (ROADMAP #43). Single source of truth
## for what a "typical" wave-N looks like across the 30-wave extension
## planned in #20. level_data builders + the wave simulator read from
## this table so tuning changes ripple through every level.
##
## Each entry describes a wave archetype at that position in the arc:
##   - enemy_count: rough spawn count target
##   - composition: enemy_id -> weight (normalized to count)
##   - tag: human-readable label (warmup / threat / boss / gauntlet)
##   - multiplier: global HP/speed scaler applied to this wave
##
## Levels should feel familiar at equivalent wave numbers. L7 wave 10
## and L2 wave 10 should both be a "first real threat" moment, even
## if the specific enemies differ. This is the thing BTD5 does that
## makes 50-wave arcs feel crafted instead of random.

const CURVE: Array = [
	# wave 0-4 — warmup
	{"tag": "warmup", "count": 6,  "comp": {"basic": 1.0}, "mult": 1.0},
	{"tag": "warmup", "count": 8,  "comp": {"basic": 0.8, "fast": 0.2}, "mult": 1.0},
	{"tag": "warmup", "count": 10, "comp": {"basic": 0.6, "fast": 0.4}, "mult": 1.0},
	{"tag": "warmup", "count": 12, "comp": {"fast": 1.0}, "mult": 1.0},
	{"tag": "warmup", "count": 14, "comp": {"basic": 0.5, "fast": 0.5}, "mult": 1.05},
	# wave 5-9 — first real threat
	{"tag": "threat", "count": 14, "comp": {"fast": 0.6, "swarm": 0.4}, "mult": 1.05},
	{"tag": "threat", "count": 16, "comp": {"swarm": 1.0}, "mult": 1.05},
	{"tag": "threat", "count": 10, "comp": {"tank": 0.7, "basic": 0.3}, "mult": 1.10},
	{"tag": "threat", "count": 18, "comp": {"fast": 0.5, "swarm": 0.5}, "mult": 1.10},
	{"tag": "threat", "count": 12, "comp": {"tank": 0.4, "healer": 0.2, "basic": 0.4}, "mult": 1.15},
	# wave 10-14 — mid-game
	{"tag": "mid",    "count": 16, "comp": {"tank": 0.3, "healer": 0.2, "swarm": 0.5}, "mult": 1.15},
	{"tag": "mid",    "count": 20, "comp": {"flying": 0.6, "fast": 0.4}, "mult": 1.15},
	{"tag": "mid",    "count": 18, "comp": {"healer": 0.3, "tank": 0.3, "fast": 0.4}, "mult": 1.20},
	{"tag": "mid",    "count": 22, "comp": {"swarm": 0.5, "flying": 0.3, "fast": 0.2}, "mult": 1.20},
	{"tag": "mid",    "count": 14, "comp": {"tank": 0.5, "healer": 0.3, "flying": 0.2}, "mult": 1.25},
	# wave 15-19 — escalation
	{"tag": "esc",    "count": 20, "comp": {"tank": 0.3, "flying": 0.3, "healer": 0.2, "fast": 0.2}, "mult": 1.25},
	{"tag": "esc",    "count": 24, "comp": {"swarm": 0.6, "flying": 0.4}, "mult": 1.30},
	{"tag": "esc",    "count": 16, "comp": {"boss": 0.05, "tank": 0.4, "healer": 0.2, "fast": 0.35}, "mult": 1.30},
	{"tag": "esc",    "count": 26, "comp": {"fast": 0.4, "swarm": 0.4, "flying": 0.2}, "mult": 1.30},
	{"tag": "esc",    "count": 20, "comp": {"tank": 0.4, "healer": 0.3, "flying": 0.3}, "mult": 1.35},
	# wave 20 — first boss
	{"tag": "boss",   "count": 12, "comp": {"boss": 0.2, "tank": 0.4, "fast": 0.4}, "mult": 1.35},
	# wave 21-24 — post-boss escalation
	{"tag": "post",   "count": 24, "comp": {"swarm": 0.5, "flying": 0.3, "fast": 0.2}, "mult": 1.40},
	{"tag": "post",   "count": 22, "comp": {"tank": 0.4, "healer": 0.3, "flying": 0.3}, "mult": 1.40},
	{"tag": "post",   "count": 26, "comp": {"fast": 0.4, "swarm": 0.3, "flying": 0.3}, "mult": 1.45},
	{"tag": "post",   "count": 20, "comp": {"tank": 0.5, "healer": 0.3, "fast": 0.2}, "mult": 1.45},
	# wave 25 — boss+minions
	{"tag": "boss2",  "count": 18, "comp": {"boss": 0.15, "tank": 0.35, "healer": 0.2, "fast": 0.3}, "mult": 1.50},
	# wave 26-29 — final push
	{"tag": "final",  "count": 28, "comp": {"flying": 0.5, "swarm": 0.5}, "mult": 1.55},
	{"tag": "final",  "count": 24, "comp": {"tank": 0.4, "healer": 0.3, "flying": 0.3}, "mult": 1.55},
	{"tag": "final",  "count": 30, "comp": {"fast": 0.3, "swarm": 0.4, "flying": 0.3}, "mult": 1.60},
	# wave 30 — gauntlet finale
	{"tag": "gauntlet", "count": 24, "comp": {"boss": 0.2, "tank": 0.3, "healer": 0.2, "flying": 0.15, "fast": 0.15}, "mult": 1.70},
]


static func get_archetype(wave_index: int) -> Dictionary:
	# Clamp to table size so levels with fewer waves still read a
	# sensible archetype (they'll typically use the last entry).
	var idx: int = clampi(wave_index, 0, CURVE.size() - 1)
	return CURVE[idx]


static func build_wave(wave_index: int, overrides: Dictionary = {}) -> Dictionary:
	# Compose a wave dict in the format level_data expects
	# ({"groups": [{enemy_id, count, spawn_delay}, ...]}). Overrides
	# let a specific level swap compositions (e.g. L2 replaces basic
	# with fast for thematic openers — ROADMAP #36).
	var arch: Dictionary = get_archetype(wave_index)
	var count: int = arch.get("count", 10)
	var comp: Dictionary = arch.get("comp", {"basic": 1.0})
	if overrides.has("comp"):
		comp = overrides["comp"]
	if overrides.has("count"):
		count = overrides["count"]
	var groups: Array = []
	for enemy_id in comp.keys():
		var weight: float = comp[enemy_id]
		var group_count: int = max(1, int(round(count * weight)))
		var delay: float = _default_delay(enemy_id)
		groups.append({
			"enemy_id": enemy_id,
			"count": group_count,
			"spawn_delay": delay,
		})
	return {"groups": groups}


static func _default_delay(enemy_id: String) -> float:
	match enemy_id:
		"swarm": return 0.14
		"fast":  return 0.22
		"basic": return 0.35
		"flying": return 0.24
		"tank":  return 0.55
		"healer": return 0.5
		"boss":  return 3.0
		_: return 0.4
