extends Node

## ProjectilePool — pre-allocates a pool of BaseProjectile instances
## that can be checked out and returned instead of instantiated/freed
## every shot. Addresses playtest-feedback #45 (perf at scale).
##
## Towers call `ProjectilePool.acquire()` instead of instantiating.
## Projectiles call `ProjectilePool.release(self)` instead of queue_free.
##
## Falls back to instantiation if the pool is exhausted — never hard-fails.

const POOL_SIZE: int = 40
const PROJECTILE_SCENE_PATH: String = "res://scenes/projectiles/base_projectile.tscn"
const PROJECTILE_SCRIPT_PATH: String = "res://scripts/projectiles/base_projectile.gd"

var _free: Array = []
var _scene: PackedScene = null
var _container: Node = null
# Expected script reference — used to verify pool nodes haven't lost their
# script (which can happen in headless Godot when scene transitions coincide
# with in-flight projectile cleanup). More reliable than has_method().
var _expected_script: Script = null


func _ready() -> void:
	_scene = load(PROJECTILE_SCENE_PATH) as PackedScene
	if _scene == null:
		push_warning("[ProjectilePool] scene missing — pool disabled")
		return
	_expected_script = load(PROJECTILE_SCRIPT_PATH) as Script
	# Defer instantiation so we don't fight with the game scene loading
	call_deferred("_prewarm")


func _prewarm() -> void:
	_container = Node.new()
	_container.name = "ProjectilePoolContainer"
	get_tree().root.add_child(_container)
	for i in POOL_SIZE:
		var p = _scene.instantiate()
		# Add to tree BEFORE deactivate so reset_for_pool() can safely
		# set global_position (requires a scene-tree parent to resolve).
		_container.add_child(p)
		_deactivate(p)
		_free.append(p)


func acquire() -> Node2D:
	# Pop the first VALID projectile from _free. Older versions trusted
	# every slot; if any projectile had been queue_freed externally the
	# next acquire would crash (freed-ref → set_meta). Skip dead slots.
	while not _free.is_empty():
		var candidate = _free.pop_back()
		if candidate != null and is_instance_valid(candidate):
			# Guard against script-detached nodes. Null script = truly broken node.
			# Identity mismatch (post-CACHE_MODE_IGNORE reload) is verified with
			# a property-presence check before discarding — prevents depleting the
			# pool when CACHE_MODE_IGNORE produces a new Script identity object.
			var candidate_script = candidate.get_script()
			if candidate_script == null:
				push_warning("[ProjectilePool] slot script-null, destroying: %s" % candidate.get_class())
				candidate.queue_free()
				continue
			if _expected_script != null and candidate_script != _expected_script:
				# Identity mismatch — check properties before destroying.
				# Post-reload race: script IS attached but has a different identity
				# object than expected (common after CACHE_MODE_IGNORE reload).
				if "damage" in candidate and "speed" in candidate:
					# Functionally valid despite identity mismatch — accept it.
					candidate.set_meta("pooled", true)
					_activate(candidate)
					return candidate
				push_warning("[ProjectilePool] slot wrong/invalid script, destroying: %s" % candidate.get_class())
				candidate.queue_free()
				continue
			candidate.set_meta("pooled", true)
			_activate(candidate)
			return candidate
	# Pool exhausted (or all slots stale) — instantiate a fresh one.
	# Mark it as NOT pooled so release() queue_frees instead of parking.
	# Always parent the node: an unparented node cannot _process(), so a
	# projectile launched from it would never move or deal damage (#567).
	if _scene:
		var p = _scene.instantiate()
		if _container:
			_container.add_child(p)
		elif get_tree():
			get_tree().root.add_child(p)
		p.set_meta("pooled", false)
		return p
	return null


func release(p: Node) -> void:
	if p == null or not is_instance_valid(p):
		return
	# Guard against double-release (audit #6): if already back in pool
	# (in _free or already deactivated), bail silently.
	if p in _free:
		return
	# Only genuinely pooled instances should return to the pool.
	# Non-pooled (lazy-instantiated when pool was exhausted) just free.
	if not p.get_meta("pooled", false):
		p.queue_free()
		return
	# Guard against scene-transition race: when the game scene is freed,
	# in-flight projectiles (children of game scene) get queue_free()'d too.
	# If release() is called in the same frame, is_instance_valid(p) may still
	# return true, but the node's script can be in an inconsistent state.
	# Verify script identity before re-pooling; discard broken nodes instead.
	var p_script = p.get_script()
	if p_script == null:
		push_warning("[ProjectilePool] release: script detached, discarding node")
		return
	if _expected_script != null and p_script != _expected_script:
		# Identity mismatch — verify properties before discarding.
		if not ("damage" in p and "speed" in p):
			push_warning("[ProjectilePool] release: wrong script, discarding node")
			return
		# Functionally valid despite identity mismatch — allow re-pooling.
	if p.get_parent() != _container and _container != null:
		var parent := p.get_parent()
		# Guard: skip reparent if parent is no longer valid (freed during
		# scene transition). The node will be freed with its parent.
		if parent != null and not is_instance_valid(parent):
			return
		if parent != null:
			parent.remove_child(p)
		_container.add_child(p)
	_deactivate(p)
	_free.append(p)


func _activate(p: Node) -> void:
	p.process_mode = Node.PROCESS_MODE_INHERIT
	if p is Node2D:
		p.visible = true
	if p is Area2D:
		p.monitoring = true
		p.monitorable = true


func _deactivate(p: Node) -> void:
	if p is Area2D:
		p.monitoring = false
		p.monitorable = false
	if p is Node2D:
		p.visible = false
	# Reset before disabling so reset_for_pool() can still call process-
	# dependent methods (signal disconnects, tween kills, etc.)
	if p.has_method("reset_for_pool"):
		p.call("reset_for_pool")
	p.process_mode = Node.PROCESS_MODE_DISABLED


# Diagnostic (optional)
func stats() -> Dictionary:
	return {
		"pool_size": POOL_SIZE,
		"free": _free.size(),
		"in_use": POOL_SIZE - _free.size(),
	}
