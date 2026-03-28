extends PanelContainer

## Shows info about a selected tower: stats, upgrade button, sell button.

signal upgrade_pressed(tower: Node2D)
signal sell_pressed(tower: Node2D)

@onready var name_label: Label = $VBox/NameLabel
@onready var stats_label: Label = $VBox/StatsLabel
@onready var upgrade_button: Button = $VBox/HBox/UpgradeButton
@onready var sell_button: Button = $VBox/HBox/SellButton

var _selected_tower: BaseTower = null


func show_tower(tower: BaseTower) -> void:
	_selected_tower = tower
	visible = true
	_refresh()


func hide_panel() -> void:
	_selected_tower = null
	visible = false


func _refresh() -> void:
	if not _selected_tower or not _selected_tower.data:
		return

	var td := _selected_tower.data
	if name_label:
		name_label.text = "%s (Lv %d)" % [td.display_name, _selected_tower.upgrade_level + 1]

	if stats_label:
		stats_label.text = "DMG: %.0f | SPD: %.1f | RNG: %.0f" % [
			_selected_tower.effective_damage,
			_selected_tower.effective_speed,
			_selected_tower.effective_range,
		]

	if upgrade_button:
		var cost := _selected_tower.get_upgrade_cost()
		if cost < 0:
			upgrade_button.text = "MAX"
			upgrade_button.disabled = true
		else:
			upgrade_button.text = "Upgrade (%d G)" % cost
			upgrade_button.disabled = not _selected_tower.can_upgrade()

	if sell_button:
		var sell_val := td.get_sell_value(_selected_tower.upgrade_level)
		sell_button.text = "Sell (%d G)" % sell_val


func _on_upgrade_button_pressed() -> void:
	if _selected_tower:
		upgrade_pressed.emit(_selected_tower)
		_selected_tower.upgrade()
		_refresh()


func _on_sell_button_pressed() -> void:
	if _selected_tower:
		sell_pressed.emit(_selected_tower)
		_selected_tower.sell()
		hide_panel()
