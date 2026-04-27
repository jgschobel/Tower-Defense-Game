extends Node

## Aminos — persistent per-clear currency (ROADMAP #48).
##
## Earned on level clear (scaling with level_id + stars), spent in the
## aminos shop on permanent upgrades (future PR). Separate from in-run
## gold + from Spezial-Münzen. Saved to user://aminos.save as JSON.

signal aminos_changed(new_amount: int)

const SAVE_PATH := "user://aminos.save"

var balance: int = 0
var total_earned: int = 0
var unlocked_nodes: Array = []
var cleared_levels: Array = []  # level_ids already awarded (F11 — no re-award on replay)


func _ready() -> void:
	_load()


func add(amount: int, _source: String = "") -> void:
	if amount <= 0:
		return
	balance += amount
	total_earned += amount
	aminos_changed.emit(balance)
	_save()


func spend(amount: int) -> bool:
	if balance < amount:
		return false
	balance -= amount
	aminos_changed.emit(balance)
	_save()
	return true


func can_afford(amount: int) -> bool:
	return balance >= amount


func is_unlocked(node_id: String) -> bool:
	return node_id in unlocked_nodes


func unlock_node(node_id: String, cost: int) -> bool:
	if is_unlocked(node_id):
		return false
	if not spend(cost):
		return false
	unlocked_nodes.append(node_id)
	_save()
	return true


## Called from GameManager.complete_level(). Yield = 5 per level clear +
## 3 per star earned on that clear. Capped at 1 award per level_id —
## replaying an already-cleared level grants no additional Aminos (F11).
func award_for_level_clear(level_id: int, stars: int) -> int:
	if level_id in cleared_levels:
		return 0
	cleared_levels.append(level_id)
	var yield_amount: int = 5 + level_id + (stars * 3)
	add(yield_amount, "level_%d_clear" % level_id)
	return yield_amount


func _save() -> void:
	var payload := {
		"balance": balance,
		"total_earned": total_earned,
		"unlocked_nodes": unlocked_nodes,
		"cleared_levels": cleared_levels,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(payload))
		f.close()


func _load() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if parsed is Dictionary:
		balance = int(parsed.get("balance", 0))
		total_earned = int(parsed.get("total_earned", 0))
		var nodes: Variant = parsed.get("unlocked_nodes", [])
		if nodes is Array:
			unlocked_nodes = nodes
		var cleared: Variant = parsed.get("cleared_levels", [])
		if cleared is Array:
			cleared_levels = cleared
