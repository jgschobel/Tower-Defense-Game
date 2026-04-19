extends Node

## Manages in-game currency (gold) earned from killing enemies and spent on towers.

signal gold_changed(new_amount: int)

var gold: int = 0
var total_gold_earned: int = 0


func reset_for_level(_level_id: int) -> void:
	# Fallback only — GameManager.start_level reads starting_gold from the
	# level .tres directly and only hits this path if the .tres is missing.
	# Audit P2: the previous hard-coded per-level dict drifted from the
	# canonical .tres values (CM said L4=350, level_4.tres says 700).
	gold = 200
	gold_changed.emit(gold)


func add_gold(amount: int) -> void:
	gold += amount
	total_gold_earned += amount
	gold_changed.emit(gold)


func spend_gold(amount: int) -> bool:
	if gold >= amount:
		gold -= amount
		gold_changed.emit(gold)
		return true
	return false


func can_afford(amount: int) -> bool:
	return gold >= amount
