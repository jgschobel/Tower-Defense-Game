extends Node

## Live registry of every alive enemy in the scene.
##
## Replaces `get_tree().get_nodes_in_group("enemies")` — that call is
## O(n) AND allocates a new Array AND walks the SceneTree. Towers were
## calling it once per tower per frame, which scaled to ~100k iterations
## per second in stress waves (perf agent audit: 12-15 fps at 80 enemies).
##
## Pattern: BaseEnemy.acquire/_ready → register(self).
##          BaseEnemy.die/_exit_tree → unregister(self).
## Callers iterate `alive` (no allocation, no scan).
##
## Expected savings: +20 fps at stress baseline (80 enemies × 20 towers).

var alive: Array = []


func register(enemy: Node) -> void:
	if enemy != null and not alive.has(enemy):
		alive.append(enemy)


func unregister(enemy: Node) -> void:
	# erase is O(n) but the alternative (swap-pop) reorders, which breaks
	# spawn-order iteration consumers rely on. The registry is small
	# (~80 enemies max) so the erase cost is negligible vs the alloc-per-
	# frame this replaces.
	alive.erase(enemy)


## Cheap predicate for "are there any enemies on screen".
func has_any() -> bool:
	return not alive.is_empty()


## Find enemies within `radius` of `from`. Callers should still test
## is_dead/is_instance_valid because the registry can briefly carry a
## node mid-death-tween before unregister fires.
func get_in_range(from: Vector2, radius: float, results: Array = []) -> Array:
	results.clear()
	var r_sq: float = radius * radius
	for n in alive:
		if n == null or not is_instance_valid(n):
			continue
		if "is_dead" in n and n.is_dead:
			continue
		var dx: float = n.global_position.x - from.x
		var dy: float = n.global_position.y - from.y
		if dx * dx + dy * dy <= r_sq:
			results.append(n)
	return results
