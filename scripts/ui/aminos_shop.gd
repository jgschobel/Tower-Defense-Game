extends Control

## Aminos permanent-upgrade shop (ROADMAP #48).
##
## Reached from the main menu. Lists AminosManager-aware upgrade nodes;
## the player spends Aminos (persistent currency earned on level clear)
## on permanent unlocks that apply at start_level() via
## GameManager.apply_aminos_modifiers().

# Each entry: id, cost, icon (ASCII abbreviation), title, desc, prereq (optional id)
# Emoji icons removed — bundled web font renders them as tofu boxes.
const NODES: Array = [
	{"id": "gold_plus_25",    "cost": 20,  "icon": "G+", "title": "Mini Start-Bonus",   "desc": "+25 Start-Gold jedes Level"},
	{"id": "gold_plus_50",    "cost": 45,  "icon": "G+", "title": "Grosse Start-Bonus", "desc": "+50 Start-Gold jedes Level"},
	{"id": "life_plus_1",     "cost": 35,  "icon": "HP", "title": "Zusätzlichs Läbe",  "desc": "+1 Start-Läbe in jedem Level"},
	{"id": "life_plus_2",     "cost": 80,  "icon": "HP", "title": "Härtere Hand",      "desc": "+2 Start-Läbe in jedem Level", "prereq": "life_plus_1"},
	{"id": "tower_disc_5",    "cost": 40,  "icon": "%",  "title": "Mini Rabatt",        "desc": "Türm sind 5% billiger"},
	{"id": "tower_disc_10",   "cost": 90,  "icon": "%",  "title": "Grosse Rabatt",      "desc": "Türm sind 10% billiger", "prereq": "tower_disc_5"},
	{"id": "upgrade_disc_10", "cost": 60,  "icon": "Up", "title": "Upgrade-Rabatt",     "desc": "Upgrades sind 10% billiger"},
	{"id": "farm_plus_10",    "cost": 55,  "icon": "GW", "title": "Farm-Boost",         "desc": "+10 Gold/Welle für Banani-Hof"},
	{"id": "crit_plus_5",     "cost": 70,  "icon": "X!", "title": "Glücks-Hand",        "desc": "+5% Krit-Chance für alli Türm"},
	{"id": "pierce_plus_1",   "cost": 75,  "icon": ">>", "title": "Banane-Pierce",      "desc": "Lemurius Bananen durchstäche 1 Feind meh"},
	{"id": "aminos_x1_5",     "cost": 150, "icon": "**", "title": "Aminos-Multiplikator", "desc": "1.5× Aminos-Bonus (Endgame-Node)"},
]


func _ready() -> void:
	# Background — warm dark gradient backdrop
	var bg := ColorRect.new()
	bg.color = Color(0.10, 0.08, 0.07, 1.0)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	_build()


func _build() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 60
	root.offset_right = -60
	root.offset_top = 32
	root.offset_bottom = -32
	root.add_theme_constant_override("separation", 14)
	add_child(root)

	# Title
	var title := Label.new()
	title.text = "Aminos-Lade"
	title.add_theme_font_size_override("font_size", 38)
	title.add_theme_color_override("font_color", Color(1, 0.88, 0.25))
	title.add_theme_color_override("font_outline_color", Color(0.25, 0.12, 0))
	title.add_theme_constant_override("outline_size", 5)
	root.add_child(title)

	# Balance row — coin icon + count + total
	var balance_label := Label.new()
	balance_label.name = "BalanceLabel"
	balance_label.add_theme_font_size_override("font_size", 22)
	balance_label.add_theme_color_override("font_color", Color(1, 0.92, 0.6))
	_refresh_balance(balance_label)
	root.add_child(balance_label)
	if AminosManager:
		AminosManager.aminos_changed.connect(func(_v): _refresh_balance(balance_label))

	# Scrolling list of upgrade rows
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 12
	root.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 8)
	scroll.add_child(list)

	for node_spec in NODES:
		list.add_child(_row(node_spec))

	# Close button — styled to match menu buttons
	var close := Button.new()
	close.text = "← Zrugg zum Menü"
	close.custom_minimum_size = Vector2(0, 56)
	_style_button(close, false)
	close.pressed.connect(func():
		SfxManager.play_click()
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	root.add_child(close)


func _refresh_balance(lbl: Label) -> void:
	var bal: int = AminosManager.balance if AminosManager else 0
	var tot: int = AminosManager.total_earned if AminosManager else 0
	lbl.text = "Du hesch  %d  Aminos    (total verdient: %d)" % [bal, tot]


func _row(spec: Dictionary) -> Control:
	var owned: bool = AminosManager.is_unlocked(spec.id) if AminosManager else false
	var prereq: String = spec.get("prereq", "")
	var prereq_met: bool = (prereq == "") or (AminosManager and AminosManager.is_unlocked(prereq))
	var balance: int = AminosManager.balance if AminosManager else 0
	var affordable: bool = balance >= int(spec.cost)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 76)

	# Per-state stylebox
	var sb := StyleBoxFlat.new()
	if owned:
		sb.bg_color = Color(0.12, 0.20, 0.10, 0.95)
		sb.border_color = Color(0.40, 0.85, 0.35, 0.85)
	elif not prereq_met:
		sb.bg_color = Color(0.13, 0.10, 0.08, 0.85)
		sb.border_color = Color(0.55, 0.45, 0.35, 0.45)
	elif affordable:
		sb.bg_color = Color(0.18, 0.15, 0.08, 0.95)
		sb.border_color = Color(1.0, 0.78, 0.22, 0.85)
	else:
		sb.bg_color = Color(0.13, 0.11, 0.10, 0.95)
		sb.border_color = Color(0.55, 0.45, 0.35, 0.65)
	sb.border_width_left = 2
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	panel.add_theme_stylebox_override("panel", sb)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.add_child(row)

	# Icon column
	var icon_lbl := Label.new()
	icon_lbl.text = spec.get("icon", "•")
	icon_lbl.add_theme_font_size_override("font_size", 32)
	icon_lbl.custom_minimum_size = Vector2(48, 0)
	icon_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if not prereq_met and not owned:
		icon_lbl.modulate = Color(0.5, 0.5, 0.5, 0.7)
	row.add_child(icon_lbl)

	# Text column (title + desc)
	var text_col := VBoxContainer.new()
	text_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_col.add_theme_constant_override("separation", 2)
	row.add_child(text_col)

	var title_lbl := Label.new()
	title_lbl.text = spec.get("title", spec.id)
	title_lbl.add_theme_font_size_override("font_size", 18)
	title_lbl.add_theme_color_override("font_color", Color(1, 0.95, 0.85) if (owned or prereq_met) else Color(0.7, 0.65, 0.6))
	text_col.add_child(title_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = spec.get("desc", "")
	desc_lbl.add_theme_font_size_override("font_size", 13)
	desc_lbl.add_theme_color_override("font_color", Color(0.8, 0.78, 0.7) if (owned or prereq_met) else Color(0.55, 0.50, 0.48))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	text_col.add_child(desc_lbl)

	# State badge / buy button column
	var state := Control.new()
	state.custom_minimum_size = Vector2(150, 0)
	state.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(state)
	state.add_child(_state_widget(spec, owned, prereq_met, affordable))

	return panel


func _state_widget(spec: Dictionary, owned: bool, prereq_met: bool, affordable: bool) -> Control:
	if owned:
		var lbl := Label.new()
		lbl.text = "[OK] Gchauft"
		lbl.add_theme_font_size_override("font_size", 17)
		lbl.add_theme_color_override("font_color", Color(0.5, 1.0, 0.4))
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 2)
		lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		lbl.offset_left = -60
		lbl.offset_right = 60
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return lbl
	if not prereq_met:
		# Prereq locked — show what's needed in human-readable form
		var prereq_id: String = spec.get("prereq", "")
		var prereq_title: String = _label_for_id(prereq_id)
		var lbl := Label.new()
		lbl.text = "[L] zerscht\n%s" % prereq_title
		lbl.add_theme_font_size_override("font_size", 12)
		lbl.add_theme_color_override("font_color", Color(0.85, 0.7, 0.4))
		lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		lbl.add_theme_constant_override("outline_size", 2)
		lbl.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
		lbl.offset_left = -70
		lbl.offset_right = 70
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		return lbl
	# Affordable or too-expensive: a buy button
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(140, 44)
	btn.text = "%d" % int(spec.cost)
	btn.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	btn.offset_left = -70
	btn.offset_right = 70
	btn.offset_top = -22
	btn.offset_bottom = 22
	_style_button(btn, affordable)
	btn.disabled = not affordable
	btn.pressed.connect(func(): _try_buy(spec, btn))
	return btn


func _try_buy(spec: Dictionary, btn: Button) -> void:
	if AminosManager and AminosManager.unlock_node(spec.id, int(spec.cost)):
		SfxManager.play_upgrade()
		# Rebuild the list so all rows refresh state (prereqs unlocked, affordability)
		for child in get_children():
			if child is VBoxContainer:
				child.queue_free()
		_build()
		return
	SfxManager.play_hit()
	var orig: Color = btn.modulate
	btn.modulate = Color(1.6, 0.3, 0.3)
	var tw := btn.create_tween()
	tw.tween_property(btn, "modulate", orig, 0.4)


func _label_for_id(node_id: String) -> String:
	for spec in NODES:
		if spec.id == node_id:
			return spec.get("title", node_id)
	return node_id


func _style_button(btn: Button, gold: bool) -> void:
	var base := StyleBoxFlat.new()
	if gold:
		base.bg_color = Color(0.32, 0.24, 0.08, 1.0)
		base.border_color = Color(1.0, 0.82, 0.20, 0.95)
	else:
		base.bg_color = Color(0.18, 0.16, 0.14, 1.0)
		base.border_color = Color(0.45, 0.40, 0.35, 0.85)
	base.border_width_left = 1
	base.border_width_right = 1
	base.border_width_top = 1
	base.border_width_bottom = 1
	base.corner_radius_top_left = 8
	base.corner_radius_top_right = 8
	base.corner_radius_bottom_left = 8
	base.corner_radius_bottom_right = 8
	base.content_margin_left = 12
	base.content_margin_right = 12
	base.content_margin_top = 6
	base.content_margin_bottom = 6
	var hover := base.duplicate() as StyleBoxFlat
	if gold:
		hover.bg_color = Color(0.46, 0.32, 0.10, 1.0)
		hover.border_color = Color(1, 0.95, 0.5, 1.0)
	else:
		hover.bg_color = Color(0.26, 0.22, 0.18, 1.0)
		hover.border_color = Color(0.7, 0.6, 0.5, 1.0)
	var pressed := base.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.55, 0.40, 0.12, 1.0) if gold else Color(0.36, 0.32, 0.28, 1.0)
	pressed.border_color = Color.WHITE
	var disabled := base.duplicate() as StyleBoxFlat
	disabled.bg_color = Color(0.10, 0.10, 0.10, 0.85)
	disabled.border_color = Color(0.30, 0.28, 0.26, 0.6)
	btn.add_theme_stylebox_override("normal", base)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", disabled)
	btn.add_theme_color_override("font_color", Color(1, 0.95, 0.55) if gold else Color(0.95, 0.92, 0.85))
	btn.add_theme_color_override("font_disabled_color", Color(0.55, 0.50, 0.45))
	btn.add_theme_font_size_override("font_size", 18)
