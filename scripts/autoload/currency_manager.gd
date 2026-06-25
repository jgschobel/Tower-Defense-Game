extends Node

## Manages in-game currency (gold) earned from killing enemies and spent on towers.

signal gold_changed(new_amount: int)
signal kombo_triggered

const _KOMBO_SPEND_THRESHOLD := 1000  # gold spent within window to trigger
const _KOMBO_WINDOW_MS := 3000        # 3s rolling window (real time)
const _KOMBO_DURATION_MS := 10000     # 10s kill-gold bonus window (real time)

var gold: int = 0
var total_gold_earned: int = 0
var wave_gold_earned: int = 0
var lifetime_kombos_triggered: int = 0

var _spend_window: Array = []   # [{t_ms: int, amount: int}]
var _kombo_until_ms: int = 0


func reset_for_level(_level_id: int) -> void:
	# Fallback only — GameManager.start_level reads starting_gold from the
	# level .tres directly and only hits this path if the .tres is missing.
	# Audit P2: the previous hard-coded per-level dict drifted from the
	# canonical .tres values (CM said L4=350, level_4.tres says 700).
	gold = 200
	gold_changed.emit(gold)
	_spend_window.clear()
	_kombo_until_ms = 0


func add_gold(amount: int) -> void:
	gold += amount
	total_gold_earned += amount
	wave_gold_earned += amount
	gold_changed.emit(gold)


func reset_wave_gold() -> void:
	wave_gold_earned = 0


func spend_gold(amount: int) -> bool:
	var effective: int = amount
	if GameManager and GameManager.consume_bon_discount():
		effective = maxi(1, amount / 2)
	if gold >= effective:
		gold -= effective
		gold_changed.emit(gold)
		_track_spend(effective)
		return true
	return false


func can_afford(amount: int) -> bool:
	return gold >= amount


func effective_cost(amount: int) -> int:
	if GameManager and GameManager.bon_discount_uses > 0:
		return maxi(1, amount / 2)
	return amount


func can_afford_effective(amount: int) -> bool:
	return gold >= effective_cost(amount)


## Returns 1.15 during an active Coupon-Kombo window, else 1.0.
func kill_gold_multiplier() -> float:
	return 1.15 if Time.get_ticks_msec() < _kombo_until_ms else 1.0


## Remaining milliseconds in the active kombo window (0 when inactive).
func kombo_remaining_ms() -> int:
	return maxi(0, _kombo_until_ms - Time.get_ticks_msec())


func _track_spend(amount: int) -> void:
	# Already in a kombo? Don't double-trigger; spending still counts for
	# the NEXT kombo after this window expires.
	if Time.get_ticks_msec() < _kombo_until_ms:
		return
	var now := Time.get_ticks_msec()
	_spend_window.append({"t": now, "amount": amount})
	# Evict entries older than the rolling 3s window
	var cutoff := now - _KOMBO_WINDOW_MS
	var i := 0
	while i < _spend_window.size():
		if _spend_window[i]["t"] < cutoff:
			_spend_window.remove_at(i)
		else:
			i += 1
	# Check threshold
	var total := 0
	for entry in _spend_window:
		total += entry["amount"]
	if total >= _KOMBO_SPEND_THRESHOLD:
		_spend_window.clear()
		_kombo_until_ms = Time.get_ticks_msec() + _KOMBO_DURATION_MS
		lifetime_kombos_triggered += 1
		kombo_triggered.emit()
