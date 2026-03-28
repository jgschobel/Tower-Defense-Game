extends Node

## Manages in-game currency (gold) earned from killing enemies and spent on towers.

signal gold_changed(new_amount: int)

var gold: int = 0
var total_gold_earned: int = 0

# Starting gold per level (can be overridden by level data)
var _level_starting_gold: Dictionary = {
	1: 200,
	2: 250,
	3: 300,
	4: 350,
	5: 400,
	6: 450,
	7: 500,
	8: 550,
	9: 600,
	10: 700,
}


func reset_for_level(level_id: int) -> void:
	gold = _level_starting_gold.get(level_id, 200)
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
