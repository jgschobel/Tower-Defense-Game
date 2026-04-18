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

var _free: Array = []
var _scene: PackedScene = null
var _container: Node = null


func _ready() -> void:
	_scene = load(PROJECTILE_SCENE_PATH) as PackedScene
	if _scene == null:
		push_warning("[ProjectilePool] scene missing — pool disabled")
		return
	# Defer instantiation so we don't fight with the game scene loading
	call_deferred("_prewarm")


func _prewarm() -> void:
	_container = Node.new()
	_container.name = "ProjectilePoolContainer"
	get_tree().root.add_child(_container)
	for i in POOL_SIZE:
		var p = _scene.instantiate()
		_deactivate(p)
		_container.add_child(p)
		_free.append(p)


func acquire() -> Node2D:
	if _free.is_empty():
		# Pool exhausted — instantiate a fresh one (still better than
		# throwing away an active projectile). Mark it as NOT pooled
		# so future release calls queue_free instead of pool-parking.
		if _scene:
			var p = _scene.instantiate()
			if _container:
				_container.add_child(p)
			p.set_meta("pooled", false)
			return p
		return null
	var p = _free.pop_back()
	p.set_meta("pooled", true)
	_activate(p)
	return p


func release(p: Node) -> void:
	if p == null or not is_instance_valid(p):
		return
	# Guard against double-release (audit #6): if already back in pool
	# (in _free or already deactivated), bail silently.
	if p in _free:
		return
	# Only genuinely pooled instances should return to the pool.
	# Non-pooled (lazy-instantiated when pool was exhausted) just free.
	if not p.has_meta("pooled") or not p.get_meta("pooled"):
		p.queue_free()
		return
	if p.get_parent() != _container and _container != null:
		p.get_parent().remove_child(p)
		_container.add_child(p)
	_deactivate(p)
	_free.append(p)


func _activate(p: Node) -> void:
	if p is Node2D:
		p.visible = true
	if p is Area2D:
		p.monitoring = true
		p.monitorable = true
	p.set_process(true)
	p.set_physics_process(true)


func _deactivate(p: Node) -> void:
	if p is Node2D:
		p.visible = false
	if p is Area2D:
		p.monitoring = false
		p.monitorable = false
	p.set_process(false)
	p.set_physics_process(false)
	# Reset transient state via a `reset()` method on the projectile,
	# if it implements one
	if p.has_method("reset_for_pool"):
		p.call("reset_for_pool")


# Diagnostic (optional)
func stats() -> Dictionary:
	return {
		"pool_size": POOL_SIZE,
		"free": _free.size(),
		"in_use": POOL_SIZE - _free.size(),
	}
