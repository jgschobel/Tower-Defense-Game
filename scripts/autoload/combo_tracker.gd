extends Node

## Combo tracker (ROADMAP "ideas"). Rapid kills within COMBO_WINDOW
## stack a counter that multiplies gold rewards. Emits combo_changed
## (counter, multiplier) so HUD can render a streak badge.
##
## Autoloaded as ComboTracker. Enemies call `note_kill()` from
## base_enemy.die. CurrencyManager reads `current_multiplier()` when
## adding gold.

signal combo_changed(counter: int, multiplier: float)

const COMBO_WINDOW: float = 2.5

var _counter: int = 0
var _time_left: float = 0.0


func _process(delta: float) -> void:
	if _counter <= 0:
		return
	_time_left -= delta
	if _time_left <= 0.0:
		reset()


func note_kill() -> void:
	_counter += 1
	_time_left = COMBO_WINDOW
	combo_changed.emit(_counter, current_multiplier())


func reset() -> void:
	if _counter == 0:
		return
	_counter = 0
	_time_left = 0.0
	combo_changed.emit(0, 1.0)


func current_multiplier() -> float:
	# Thresholds: 0-4 = 1.0×, 5-9 = 1.5×, 10-19 = 2.0×, 20+ = 3.0×.
	if _counter >= 20:
		return 3.0
	if _counter >= 10:
		return 2.0
	if _counter >= 5:
		return 1.5
	return 1.0


func time_left() -> float:
	return maxf(_time_left, 0.0)
