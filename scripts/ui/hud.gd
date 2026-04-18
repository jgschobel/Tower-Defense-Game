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
@onready var enemy_count_label: Label = $TopBar/HBox/EnemyCountLabel
@onready var speed_button: Button = $TopBar/HBox/SpeedButton
@onready var pause_button: Button = $TopBar/HBox/PauseButton
@onready var next_wave_button: Button = $BottomPanel/BottomBar/ButtonRow/NextWaveButton
@onready var cancel_button: Button = $BottomPanel/BottomBar/ButtonRow/CancelButton
@onready var tower_shop: HBoxContainer = $BottomPanel/BottomBar/TowerShop
@onready var tower_info: PanelContainer = $TowerInfo

var tower_data_list: Array = []
var _cost_labels: Array = []
var _game_speed: float = 1.0
var _selected_tower: BaseTower = null
var _is_placing: bool = false

var _shop_tower_ids: Array = ["basic", "sniper", "splash", "cordula", "slow"]


func _ready() -> void:
	CurrencyManager.gold_changed.connect(_on_gold_changed)
	GameManager.lives_changed.connect(_on_lives_changed)

	_on_gold_changed(CurrencyManager.gold)
	_on_lives_changed(GameManager.lives)
	_populate_tower_shop()
	_apply_safe_area()

	if tower_info:
		tower_info.visible = false
	cancel_button.visible = false


var _safe_area_applied: bool = false

func _apply_safe_area() -> void:
	# Idempotent guard: without this, running twice (rotation, re-init)
	# stacks offsets and pushes the UI off-screen. Audit #2.
	if _safe_area_applied:
		return
	var safe_rect := DisplayServer.get_display_safe_area()
	var screen_size := DisplayServer.window_get_size()
	var inset_left := safe_rect.position.x
	var inset_right := screen_size.x - (safe_rect.position.x + safe_rect.size.x)
	var inset_top := safe_rect.position.y
	var inset_bottom := screen_size.y - (safe_rect.position.y + safe_rect.size.y)
	if inset_left == 0 and inset_right == 0 and inset_top == 0 and inset_bottom == 0:
		_safe_area_applied = true
		return
	var top_bar: PanelContainer = $TopBar
	top_bar.offset_left = float(inset_left)
	top_bar.offset_right = float(-inset_right)
	top_bar.offset_top = float(inset_top)
	top_bar.offset_bottom = float(inset_top) + 65.0
	var bottom_panel: PanelContainer = $BottomPanel
	bottom_panel.offset_left = float(inset_left)
	bottom_panel.offset_right = float(-inset_right)
	bottom_panel.offset_top = -220.0 - float(inset_bottom)
	bottom_panel.offset_bottom = float(-inset_bottom)
	_safe_area_applied = true


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
		_cost_labels.append(cost_label)

		btn.add_child(vbox)
		tower_shop.add_child(btn)


func update_wave_info(current: int, total: int) -> void:
	if wave_label:
		if current == 0:
			wave_label.text = "Bereit"
		else:
			wave_label.text = "Welle %d/%d" % [current, total]
			# Wave announcement — big text that fades
			_show_wave_announcement(current, total)


func _show_wave_announcement(current: int, _total: int) -> void:
	var announce := Label.new()
	announce.text = "WELLE %d!" % current
	announce.add_theme_font_size_override("font_size", 52)
	announce.add_theme_color_override("font_color", Color(1, 0.9, 0.2))
	announce.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0))
	announce.add_theme_constant_override("outline_size", 5)
	announce.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	announce.anchors_preset = Control.PRESET_CENTER
	announce.anchor_left = 0.5
	announce.anchor_top = 0.4
	announce.anchor_right = 0.5
	announce.anchor_bottom = 0.4
	announce.offset_left = -150
	announce.offset_right = 150
	announce.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(announce)
	# For later waves (7+), make the text red and bigger
	if current >= 7:
		announce.add_theme_color_override("font_color", Color(1, 0.3, 0.2))
		announce.add_theme_font_size_override("font_size", 60)
	var tween := announce.create_tween()
	tween.tween_property(announce, "modulate:a", 0.0, 1.5).set_delay(0.5)
	tween.tween_callback(announce.queue_free)


func show_next_wave_button(visible_flag: bool) -> void:
	if next_wave_button:
		next_wave_button.visible = visible_flag
		if visible_flag:
			# Pulse animation to draw attention
			var pulse := next_wave_button.create_tween().set_loops(3)
			pulse.tween_property(next_wave_button, "modulate", Color(1.3, 1.2, 0.8), 0.4)
			pulse.tween_property(next_wave_button, "modulate", Color.WHITE, 0.4)


func update_enemy_count(count: int) -> void:
	if enemy_count_label:
		if count > 0:
			enemy_count_label.text = "%d übrig" % count
		else:
			enemy_count_label.text = ""


func set_placing(placing: bool) -> void:
	_is_placing = placing
	cancel_button.visible = placing
	if placing:
		next_wave_button.visible = false
	else:
		# Restore the wave button when done placing
		cancel_button.visible = false
		next_wave_button.visible = true


func show_tower_info(tower: BaseTower) -> void:
	# Deselect previous
	if _selected_tower and is_instance_valid(_selected_tower):
		_selected_tower.modulate = Color.WHITE
		_selected_tower.show_range(false)
	_selected_tower = tower
	tower.show_range(true)
	# Glow effect on selected tower
	var glow := tower.create_tween().set_loops()
	glow.tween_property(tower, "modulate", Color(1.2, 1.2, 1.4), 0.5)
	glow.tween_property(tower, "modulate", Color.WHITE, 0.5)
	SfxManager.play_click()
	if tower_info:
		tower_info.visible = true
		_refresh_tower_info()


func hide_tower_info() -> void:
	if _selected_tower and is_instance_valid(_selected_tower):
		_selected_tower.show_range(false)
		_selected_tower.modulate = Color.WHITE
		_selected_tower = null
	if tower_info:
		tower_info.visible = false


func _unhandled_input(event: InputEvent) -> void:
	# Auto-hide tower info panel when user taps on empty map area. Audit
	# #3: the panel occludes the middle band of the map and towers
	# behind it can't be clicked. Tap-outside-to-close is BTD-style.
	if not tower_info or not tower_info.visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var panel_rect: Rect2 = Rect2(tower_info.global_position, tower_info.size)
		if not panel_rect.has_point(event.global_position):
			hide_tower_info()
	elif event is InputEventScreenTouch and event.pressed:
		var panel_rect_touch: Rect2 = Rect2(tower_info.global_position, tower_info.size)
		if not panel_rect_touch.has_point(event.position):
			hide_tower_info()


func _refresh_tower_info() -> void:
	if not _selected_tower or not _selected_tower.data or not tower_info:
		return

	var td := _selected_tower.data
	var name_lbl: Label = tower_info.get_node_or_null("VBox/NameLabel")
	var stats_lbl: Label = tower_info.get_node_or_null("VBox/StatsLabel")
	var upgrade_btn: Button = tower_info.get_node_or_null("VBox/HBox/UpgradeButton")
	var sell_btn: Button = tower_info.get_node_or_null("VBox/HBox/SellButton")

	if name_lbl:
		if td.has_branching_upgrades():
			name_lbl.text = "%s  (A%d / B%d)" % [
				td.display_name,
				_selected_tower.path_a_tier,
				_selected_tower.path_b_tier,
			]
		else:
			name_lbl.text = "%s (Lv %d)" % [td.display_name, _selected_tower.upgrade_level + 1]
	if stats_lbl:
		stats_lbl.text = "Schade: %.0f  Tempo: %.1f  Riichwiiti: %.0f" % [
			_selected_tower.effective_damage,
			_selected_tower.effective_speed,
			_selected_tower.effective_range,
		]

	if td.has_branching_upgrades():
		_refresh_branching_buttons(upgrade_btn)
	elif upgrade_btn:
		_ensure_linear_upgrade_button(upgrade_btn)
		var cost := _selected_tower.get_upgrade_cost()
		if cost < 0:
			upgrade_btn.text = "MAXIMUM"
			upgrade_btn.disabled = true
		else:
			upgrade_btn.text = "Verbessere %d" % cost
			upgrade_btn.disabled = not _selected_tower.can_upgrade()

	if sell_btn:
		var sell_val: int
		if td.has_branching_upgrades():
			sell_val = td.get_sell_value_branched(_selected_tower.path_a_tier, _selected_tower.path_b_tier)
		else:
			sell_val = td.get_sell_value(_selected_tower.upgrade_level)
		sell_btn.text = "Verchaufe %d" % sell_val


func _ensure_linear_upgrade_button(upgrade_btn: Button) -> void:
	upgrade_btn.visible = true
	var parent := upgrade_btn.get_parent()
	if parent:
		var path_a_btn: Button = parent.get_node_or_null("PathAButton")
		var path_b_btn: Button = parent.get_node_or_null("PathBButton")
		if path_a_btn:
			path_a_btn.visible = false
		if path_b_btn:
			path_b_btn.visible = false


func _refresh_branching_buttons(linear_btn: Button) -> void:
	if not _selected_tower or not _selected_tower.data:
		return
	var td := _selected_tower.data
	var parent := linear_btn.get_parent() if linear_btn else tower_info.get_node_or_null("VBox/HBox")
	if parent == null:
		return
	if linear_btn:
		linear_btn.visible = false

	var path_a_btn: Button = parent.get_node_or_null("PathAButton")
	var path_b_btn: Button = parent.get_node_or_null("PathBButton")
	if path_a_btn == null:
		path_a_btn = Button.new()
		path_a_btn.name = "PathAButton"
		path_a_btn.custom_minimum_size = Vector2(0, 60)
		path_a_btn.pressed.connect(_on_path_a_button_pressed)
		parent.add_child(path_a_btn)
		# Put path buttons before the sell button
		var sell_idx := parent.get_node_or_null("SellButton")
		if sell_idx:
			parent.move_child(path_a_btn, sell_idx.get_index())
	if path_b_btn == null:
		path_b_btn = Button.new()
		path_b_btn.name = "PathBButton"
		path_b_btn.custom_minimum_size = Vector2(0, 60)
		path_b_btn.pressed.connect(_on_path_b_button_pressed)
		parent.add_child(path_b_btn)
		var sell_idx2 := parent.get_node_or_null("SellButton")
		if sell_idx2:
			parent.move_child(path_b_btn, sell_idx2.get_index())

	path_a_btn.visible = true
	path_b_btn.visible = true
	_style_path_button(path_a_btn, "a", td)
	_style_path_button(path_b_btn, "b", td)


func _style_path_button(btn: Button, path_letter: String, td: TowerData) -> void:
	var display: String = td.path_a_display if path_letter == "a" else td.path_b_display
	var tier := _selected_tower.path_a_tier if path_letter == "a" else _selected_tower.path_b_tier
	var cost := _selected_tower.get_path_upgrade_cost(path_letter)
	var tint: Color = td.path_a_tint if path_letter == "a" else td.path_b_tint
	if cost < 0:
		btn.text = "%s ⭐ MAX" % display
		btn.disabled = true
	else:
		var next_name := _selected_tower.get_path_next_tier_name(path_letter)
		btn.text = "↑ %s\n(%dg)" % [next_name if next_name != "" else display, cost]
		btn.disabled = not _selected_tower.can_upgrade_path(path_letter)
	btn.add_theme_color_override("font_color", tint)


func _on_path_a_button_pressed() -> void:
	if not _selected_tower:
		return
	if _selected_tower.upgrade_path("a"):
		_refresh_tower_info()


func _on_path_b_button_pressed() -> void:
	if not _selected_tower:
		return
	if _selected_tower.upgrade_path("b"):
		_refresh_tower_info()


func _on_gold_changed(amount: int) -> void:
	if gold_label:
		gold_label.text = "%d" % amount
	for i in tower_shop.get_child_count():
		if i < tower_data_list.size():
			var btn: Button = tower_shop.get_child(i)
			var affordable: bool = CurrencyManager.can_afford(tower_data_list[i].buy_cost)
			btn.disabled = not affordable
			if i < _cost_labels.size():
				var col := Color(1, 0.9, 0.3) if affordable else Color(1, 0.3, 0.2)
				_cost_labels[i].add_theme_color_override("font_color", col)
	if _selected_tower:
		_refresh_tower_info()


func _on_lives_changed(amount: int) -> void:
	if lives_label:
		lives_label.text = "%d Läbe" % amount


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


func show_toast(message: String) -> void:
	var toast := Label.new()
	toast.text = message
	toast.add_theme_font_size_override("font_size", 24)
	toast.add_theme_color_override("font_color", Color(1, 0.35, 0.2))
	toast.add_theme_color_override("font_outline_color", Color(0.1, 0.05, 0))
	toast.add_theme_constant_override("outline_size", 5)
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.anchor_left = 0.5
	toast.anchor_top = 0.62
	toast.anchor_right = 0.5
	toast.anchor_bottom = 0.62
	toast.offset_left = -160
	toast.offset_right = 160
	toast.grow_horizontal = Control.GROW_DIRECTION_BOTH
	add_child(toast)
	var tween := toast.create_tween()
	tween.tween_property(toast, "modulate:a", 0.0, 1.2).set_delay(0.4)
	tween.tween_callback(toast.queue_free)
