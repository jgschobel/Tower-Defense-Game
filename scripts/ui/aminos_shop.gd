extends Control

## Aminos permanent-upgrade shop (ROADMAP #48).
##
## Reached from the main menu. Lists AminosManager-aware upgrade nodes;
## the player spends Aminos (persistent currency earned on level clear)
## on permanent unlocks that apply at start_level() via
## GameManager.apply_aminos_modifiers().
##
## Intentionally lightweight — one scroll list of rows, a balance
## counter at top, close button. No branching tree yet; node unlock
## order is purely by cost.

const NODES: Array = [
	{"id": "gold_plus_25",     "cost": 20,  "label": "+25 Start-Gold jedes Level"},
	{"id": "gold_plus_50",     "cost": 45,  "label": "+50 Start-Gold jedes Level"},
	{"id": "life_plus_1",      "cost": 35,  "label": "+1 Start-Läbe"},
	{"id": "life_plus_2",      "cost": 80,  "label": "+2 Start-Läbe (requires life_plus_1)"},
	{"id": "tower_disc_5",     "cost": 40,  "label": "-5% Turm-Buy-Chöste"},
	{"id": "tower_disc_10",    "cost": 90,  "label": "-10% Turm-Buy-Chöste (requires tower_disc_5)"},
	{"id": "upgrade_disc_10",  "cost": 60,  "label": "-10% Upgrade-Chöste"},
	{"id": "farm_plus_10",     "cost": 55,  "label": "+10 Gold/Welle für Farm-Türm"},
	{"id": "crit_plus_5",      "cost": 70,  "label": "+5% Krit-Chance für alli Türm"},
	{"id": "pierce_plus_1",    "cost": 75,  "label": "Lemurius bananen durchstäche 1 meh"},
	{"id": "aminos_x1_5",      "cost": 150, "label": "1.5× Aminos-Bonus (end-game node)"},
]


func _ready() -> void:
	_build()


func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 40
	root.offset_right = -40
	root.offset_top = 40
	root.offset_bottom = -40
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var title := Label.new()
	title.text = "Aminos-Lade"
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	root.add_child(title)

	var balance_label := Label.new()
	balance_label.name = "BalanceLabel"
	balance_label.add_theme_font_size_override("font_size", 20)
	_refresh_balance(balance_label)
	root.add_child(balance_label)
	if AminosManager:
		AminosManager.aminos_changed.connect(func(_v): _refresh_balance(balance_label))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 12
	root.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 6)
	scroll.add_child(list)

	for node_spec in NODES:
		list.add_child(_row(node_spec))

	var close := Button.new()
	close.text = "Zrugg"
	close.custom_minimum_size = Vector2(200, 52)
	close.pressed.connect(func():
		SfxManager.play_click()
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	root.add_child(close)


func _refresh_balance(lbl: Label) -> void:
	var bal: int = AminosManager.balance if AminosManager else 0
	var tot: int = AminosManager.total_earned if AminosManager else 0
	lbl.text = "Du hesch  %d  Aminos  ·  total verdient  %d" % [bal, tot]


func _row(spec: Dictionary) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 64)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)
	var label := Label.new()
	label.text = spec.label
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.add_theme_font_size_override("font_size", 15)
	row.add_child(label)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(160, 44)
	var owned: bool = AminosManager.is_unlocked(spec.id) if AminosManager else false
	if owned:
		btn.text = "Gchauft"
		btn.disabled = true
	else:
		btn.text = "%d Aminos" % int(spec.cost)
		btn.pressed.connect(func():
			if AminosManager and AminosManager.unlock_node(spec.id, int(spec.cost)):
				SfxManager.play_upgrade()
				btn.text = "Gchauft"
				btn.disabled = true
			else:
				# F13: red flash + toast when insufficient Aminos
				SfxManager.play_hit()
				var orig: Color = btn.modulate
				btn.modulate = Color(1.6, 0.3, 0.3)
				var tw := btn.create_tween()
				tw.tween_property(btn, "modulate", orig, 0.45)
				var toast := Label.new()
				toast.text = "Z'wenig Aminos!"
				toast.add_theme_font_size_override("font_size", 16)
				toast.add_theme_color_override("font_color", Color(1, 0.35, 0.35))
				toast.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
				toast.add_theme_constant_override("outline_size", 3)
				toast.z_index = 30
				btn.add_child(toast)
				toast.position = Vector2(0, -28)
				var tw2 := toast.create_tween().set_parallel(true)
				tw2.tween_property(toast, "position:y", -50.0, 0.6)
				tw2.tween_property(toast, "modulate:a", 0.0, 0.6).set_delay(0.2)
				tw2.chain().tween_callback(toast.queue_free))
	row.add_child(btn)
	return panel
