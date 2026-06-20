extends Node

## Single global scheduler that fires taunts on placed towers.
##
## Replaces 1 Timer node per tower (20 towers = 20 always-running
## Timers per perf-agent audit 2026-06-20 finding) with 1 shared
## Timer that picks a random tower per tick.
##
## Each tick (3-7s real time): pick a random tower from the towers
## group, call its `_maybe_taunt_from_scheduler()` method. The tower
## decides whether to actually float a taunt (cooldown, taunt-pool,
## active-spawning suppression — same logic as before, just centralized).
##
## Net: 20 Timers → 1 Timer. Allocates one random pick per tick instead
## of every tower running its own timeout signal.

var _timer: Timer = null
const _MIN_INTERVAL: float = 3.0
const _MAX_INTERVAL: float = 7.0


func _ready() -> void:
	_timer = Timer.new()
	_timer.name = "GlobalTauntTimer"
	_timer.wait_time = randf_range(_MIN_INTERVAL, _MAX_INTERVAL)
	_timer.one_shot = false
	_timer.autostart = true
	add_child(_timer)
	_timer.timeout.connect(_on_tick)


func _on_tick() -> void:
	# Re-randomize interval so taunts don't fall on a beat
	_timer.wait_time = randf_range(_MIN_INTERVAL, _MAX_INTERVAL)
	# Cheap O(n) group walk — only runs at 3-7s intervals, not every
	# frame, so the cost is negligible vs the saved 19 always-running
	# Timer nodes.
	var towers: Array = get_tree().get_nodes_in_group("towers")
	if towers.is_empty():
		return
	var tower = towers[randi() % towers.size()]
	if tower == null or not is_instance_valid(tower):
		return
	if tower.has_method("_maybe_taunt_from_scheduler"):
		tower._maybe_taunt_from_scheduler()
