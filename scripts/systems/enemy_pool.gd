extends Node

## EnemyPool — pre-allocates a pool of BaseEnemy instances.
## Addresses playtest-feedback #52 (22 FPS min in stress scenario).
##
## WaveManager calls `EnemyPool.acquire(data, path)` instead of
## instantiating. Enemies call `EnemyPool.release(self)` on death or
## end-of-path instead of queue_free.
##
## Falls back to instantiation if pool is exhausted — never hard-fails.

const POOL_SIZE: int = 60
const ENEMY_SCENE_PATH: String = "res://scenes/enemies/base_enemy.tscn"

var _free: Array = []
var _scene: PackedScene = null
var _container: Node = null


func _ready() -> void:
	_scene = load(ENEMY_SCENE_PATH) as PackedScene
	if _scene == null:
		push_warning("[EnemyPool] scene missing — pool disabled")
		return
	call_deferred("_prewarm")


func _prewarm() -> void:
	_container = Node.new()
	_container.name = "EnemyPoolContainer"
	get_tree().root.add_child(_container)
	for i in POOL_SIZE:
		var e = _scene.instantiate()
		_deactivate(e)
		_container.add_child(e)
		_free.append(e)


func acquire(data, path_node) -> Node:
	var e: Node
	var from_pool := false
	if _free.is_empty():
		if _scene == null:
			return null
		e = _scene.instantiate()
	else:
		e = _free.pop_back()
		if e.get_parent() == _container:
			_container.remove_child(e)
		from_pool = true
	# Mark origin so release() knows whether to pool-park or queue_free.
	# Mixing pool + non-pool instances was audit finding #5.
	e.set_meta("pooled", from_pool)
	path_node.add_child(e)
	e.data = data
	if e.has_method("reset_for_pool"):
		e.call("reset_for_pool")
	_activate(e)
	return e


func release(e: Node) -> void:
	if e == null or not is_instance_valid(e):
		return
	# Double-release guard (audit #6)
	if e in _free:
		return
	# Non-pooled instances just free themselves
	if not e.has_meta("pooled") or not e.get_meta("pooled"):
		e.queue_free()
		return
	if _container == null:
		e.queue_free()
		return
	if e.get_parent():
		e.get_parent().remove_child(e)
	_container.add_child(e)
	_deactivate(e)
	_free.append(e)


func _activate(e: Node) -> void:
	if e is Node2D:
		e.visible = true
	e.set_process(true)
	e.set_physics_process(true)
	# Path progress reset is handled by reset_for_pool() on the enemy


func _deactivate(e: Node) -> void:
	if e is Node2D:
		e.visible = false
	e.set_process(false)
	e.set_physics_process(false)


func stats() -> Dictionary:
	return {
		"pool_size": POOL_SIZE,
		"free": _free.size(),
		"in_use": POOL_SIZE - _free.size(),
	}
