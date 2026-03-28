extends CanvasLayer

## In-game HUD showing gold, lives, wave info, and tower shop.

signal tower_selected_for_placement(tower_data: Resource)
signal placement_cancelled
signal next_wave_requested
signal pause_requested
signal auto_wave_toggled(enabled: bool)

@onready var gold_icon: TextureRect = $TopBar/HBox/GoldIcon
@onready var gold_label: Label = $TopBar/HBox/GoldLabel
@onready var lives_label: Label = $TopBar/HBox/LivesLabel
@onready var wave_label: Label = $TopBar/HBox/WaveLabel
@onready var speed_button: Button = $TopBar/HBox/SpeedButton
@onready var pause_button: Button = $TopBar/HBox/PauseButton
@onready var next_wave_button: Button = $BottomPanel/BottomBar/ButtonRow/NextWaveButton
@onready var cancel_button: Button = $BottomPanel/BottomBar/ButtonRow/CancelButton
@onready var tower_shop: HBoxContainer = $BottomPanel/BottomBar/TowerShop
@onready var tower_info: PanelContainer = $TowerInfo

var tower_data_list: Array = []
var _game_speed: float = 1.0
var _selected_tower: BaseTower = null
var _is_placing: bool = false

var _shop_tower_ids: Array = ["basic", "sniper", "splash", "slow", "support"]


func _ready() -> void:
	CurrencyManager.gold_changed.connect(_on_gold_changed)
	GameManager.lives_changed.connect(_on_lives_changed)

	_on_gold_changed(CurrencyManager.gold)
	_on_lives_changed(GameManager.lives)
	_populate_tower_shop()

	if tower_info:
		tower_info.visible = false
	cancel_button.visible = false


func _populate_tower_shop() -> void:
	for tower_id in _shop_tower_ids:
		var data_path := "res://resources/tower_data/%s.tres" % tower_id
		if not ResourceLoader.exists(data_path):
			continue
		var td: TowerData = load(data_path)
		tower_data_list.append(td)

		var btn := Button.new()
		btn.custom_minimum_size = Vector2(125, 140)
		btn.pressed.connect(_on_tower_button_pressed.bind(td))

		var vbox := VBoxContainer.new()
		vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 4)

		if td.custom_texture:
			var icon := TextureRect.new()
			icon.texture = td.custom_texture
			icon.custom_minimum_size = Vector2(85, 85)
			icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
			icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(icon)
		else:
			# Placeholder colored rect for towers without custom art
			var placeholder := ColorRect.new()
			placeholder.custom_minimum_size = Vector2(60, 60)
			placeholder.color = td.base_color
			placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
			vbox.add_child(placeholder)

		var name_label := Label.new()
		name_label.text = td.display_name
		name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_label.add_theme_font_size_override("font_size", 14)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(name_label)

		var cost_label := Label.new()
		cost_label.text = "%d" % td.buy_cost
		cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cost_label.add_theme_font_size_override("font_size", 12)
		cost_label.add_theme_color_override("font_color", Color(1, 0.9, 0.3))
		cost_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(cost_label)

		btn.add_child(vbox)
		tower_shop.add_child(btn)


func update_wave_info(current: int, total: int) -> void:
	if wave_label:
		wave_label.text = "Wave %d/%d" % [current, total]


func show_next_wave_button(visible_flag: bool) -> void:
	if next_wave_button:
		next_wave_button.visible = visible_flag


func set_placing(placing: bool) -> void:
	_is_placing = placing
	cancel_button.visible = placing
	if placing:
		next_wave_button.visible = false


func show_tower_info(tower: BaseTower) -> void:
	_selected_tower = tower
	tower.show_range(true)
	if tower_info:
		tower_info.visible = true
		_refresh_tower_info()


func hide_tower_info() -> void:
	if _selected_tower:
		_selected_tower.show_range(false)
		_selected_tower = null
	if tower_info:
		tower_info.visible = false


func _refresh_tower_info() -> void:
	if not _selected_tower or not _selected_tower.data or not tower_info:
		return

	var td := _selected_tower.data
	var name_lbl: Label = tower_info.get_node_or_null("VBox/NameLabel")
	var stats_lbl: Label = tower_info.get_node_or_null("VBox/StatsLabel")
	var upgrade_btn: Button = tower_info.get_node_or_null("VBox/HBox/UpgradeButton")
	var sell_btn: Button = tower_info.get_node_or_null("VBox/HBox/SellButton")

	if name_lbl:
		name_lbl.text = "%s (Lv %d)" % [td.display_name, _selected_tower.upgrade_level + 1]
	if stats_lbl:
		stats_lbl.text = "DMG: %.0f  SPD: %.1f  RNG: %.0f" % [
			_selected_tower.effective_damage,
			_selected_tower.effective_speed,
			_selected_tower.effective_range,
		]
	if upgrade_btn:
		var cost := _selected_tower.get_upgrade_cost()
		if cost < 0:
			upgrade_btn.text = "MAX"
			upgrade_btn.disabled = true
		else:
			upgrade_btn.text = "Upgrade %d" % cost
			upgrade_btn.disabled = not _selected_tower.can_upgrade()
	if sell_btn:
		var sell_val := td.get_sell_value(_selected_tower.upgrade_level)
		sell_btn.text = "Sell %d" % sell_val


func _on_gold_changed(amount: int) -> void:
	if gold_label:
		gold_label.text = " %d" % amount
	for i in tower_shop.get_child_count():
		if i < tower_data_list.size():
			var btn: Button = tower_shop.get_child(i)
			btn.disabled = not CurrencyManager.can_afford(tower_data_list[i].buy_cost)
	if _selected_tower:
		_refresh_tower_info()


func _on_lives_changed(amount: int) -> void:
	if lives_label:
		lives_label.text = "%d HP" % amount


func _on_tower_button_pressed(td: TowerData) -> void:
	hide_tower_info()
	tower_selected_for_placement.emit(td)
	set_placing(true)


func _on_next_wave_button_pressed() -> void:
	next_wave_requested.emit()
	show_next_wave_button(false)


func _on_cancel_button_pressed() -> void:
	set_placing(false)
	placement_cancelled.emit()


func _on_pause_button_pressed() -> void:
	pause_requested.emit()


func _on_auto_button_toggled(toggled_on: bool) -> void:
	auto_wave_toggled.emit(toggled_on)


func _on_speed_button_pressed() -> void:
	if _game_speed == 1.0:
		_game_speed = 2.0
	elif _game_speed == 2.0:
		_game_speed = 3.0
	else:
		_game_speed = 1.0
	Engine.time_scale = _game_speed
	if speed_button:
		speed_button.text = "%dx" % int(_game_speed)


func _on_upgrade_button_pressed() -> void:
	if _selected_tower:
		_selected_tower.upgrade()
		_refresh_tower_info()


func _on_sell_button_pressed() -> void:
	if _selected_tower:
		_selected_tower.sell()
		hide_tower_info()


func _on_close_button_pressed() -> void:
	hide_tower_info()
