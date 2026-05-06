extends Control

## Level selection screen with background art.

@onready var level_grid: GridContainer = $MarginContainer/VBoxContainer/GridBackdrop/GridPad/LevelGrid
@onready var bg: TextureRect = $Background


func _ready() -> void:
	# Try to load level select background
	var bg_path := "res://assets/textures/ui/levelselect_bg.png"
	if bg and ResourceLoader.exists(bg_path):
		bg.texture = load(bg_path)
	# Style the grid backdrop so buttons always contrast against background art
	var backdrop := get_node_or_null("MarginContainer/VBoxContainer/GridBackdrop") as PanelContainer
	if backdrop:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.04, 0.06, 0.12, 0.72)
		sb.border_color = Color(0.30, 0.38, 0.55, 0.6)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(8)
		backdrop.add_theme_stylebox_override("panel", sb)
	_populate_levels()
	_show_totals()


func _show_totals() -> void:
	# Top-right total stars + kills summary so the player sees their
	# cumulative progress while browsing levels.
	if has_node("TotalsBadge"):
		return
	var lbl := Label.new()
	lbl.name = "TotalsBadge"
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var max_stars: int = GameManager.MAX_LEVELS * 3
	lbl.text = "Sterne: %d/%d  K.O.: %d" % [GameManager.total_stars, max_stars, GameManager.total_kills]
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(1, 0.9, 0.4))
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 3)
	lbl.anchors_preset = Control.PRESET_TOP_RIGHT
	lbl.anchor_left = 1.0
	lbl.anchor_right = 1.0
	lbl.offset_left = -260
	lbl.offset_top = 20
	lbl.offset_right = -20
	lbl.offset_bottom = 50
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(lbl)


func _populate_levels() -> void:
	for child in level_grid.get_children():
		child.queue_free()

	# Per-level accent colours (match campaign theming)
	var level_colors := {
		1: Color(0.95, 0.80, 0.30), 2: Color(0.45, 0.75, 1.00),
		3: Color(1.00, 0.65, 0.25), 4: Color(0.75, 0.50, 1.00),
		5: Color(1.00, 0.30, 0.25), 6: Color(0.40, 0.65, 0.55),
		7: Color(0.40, 0.85, 1.00), 8: Color(0.35, 0.60, 1.00),
		9: Color(0.65, 0.40, 1.00), 10: Color(1.00, 0.40, 0.35),
	}

	for i in range(1, GameManager.MAX_LEVELS + 1):
		var unlocked := i <= GameManager.levels_unlocked
		var stars: int = 0
		if GameManager.level_stars.has(i):
			stars = GameManager.level_stars.get(i, 0)
		elif GameManager.level_stars.has(str(i)):
			stars = GameManager.level_stars.get(str(i), 0)

		var accent: Color = level_colors.get(i, Color.WHITE)
		if not unlocked:
			accent = Color(0.45, 0.45, 0.50)

		# VBoxContainer wrapper: circle button on top, name label below
		var vbox := VBoxContainer.new()
		vbox.alignment = BoxContainer.ALIGNMENT_CENTER
		vbox.add_theme_constant_override("separation", 4)
		vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER

		# Circular button — uses StyleBoxFlat for all visual states
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(90, 90)
		btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		btn.disabled = not unlocked
		btn.flat = true

		var sb_normal := StyleBoxFlat.new()
		sb_normal.bg_color = accent.darkened(0.38)
		sb_normal.border_color = accent.lightened(0.1)
		sb_normal.set_border_width_all(5)
		sb_normal.shadow_color = Color(0.0, 0.0, 0.0, 0.6)
		sb_normal.shadow_size = 6
		sb_normal.set_corner_radius_all(45)
		btn.add_theme_stylebox_override("normal", sb_normal)

		var sb_hover := StyleBoxFlat.new()
		sb_hover.bg_color = accent.darkened(0.20)
		sb_hover.border_color = accent.lightened(0.35)
		sb_hover.set_border_width_all(6)
		sb_hover.shadow_color = Color(0.0, 0.0, 0.0, 0.5)
		sb_hover.shadow_size = 8
		sb_hover.set_corner_radius_all(45)
		btn.add_theme_stylebox_override("hover", sb_hover)

		var sb_pressed := StyleBoxFlat.new()
		sb_pressed.bg_color = accent.darkened(0.10)
		sb_pressed.border_color = accent.lightened(0.5)
		sb_pressed.set_border_width_all(7)
		sb_pressed.set_corner_radius_all(45)
		btn.add_theme_stylebox_override("pressed", sb_pressed)

		var sb_disabled := StyleBoxFlat.new()
		sb_disabled.bg_color = Color(0.32, 0.34, 0.46)
		sb_disabled.border_color = Color(0.68, 0.70, 0.84)
		sb_disabled.set_border_width_all(3)
		sb_disabled.shadow_color = Color(0.0, 0.0, 0.0, 0.7)
		sb_disabled.shadow_size = 5
		sb_disabled.set_corner_radius_all(45)
		btn.add_theme_stylebox_override("disabled", sb_disabled)

		# Level number — large, centred inside the circle. Locked levels
		# show "—" (em-dash, universally renderable) instead of the 🔒
		# emoji which tofus on Android phones with stripped Noto Emoji.
		# The disabled stylebox already greys the button so the lock state
		# is unambiguous.
		var num_lbl := Label.new()
		num_lbl.text = str(i) if unlocked else "—"
		num_lbl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		num_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		num_lbl.add_theme_font_size_override("font_size", 32)
		num_lbl.add_theme_color_override("font_color", accent.lightened(0.55) if unlocked else Color(0.80, 0.82, 0.95))
		num_lbl.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
		num_lbl.add_theme_constant_override("outline_size", 4)
		num_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(num_lbl)

		# Stars — smaller text in the lower third of the circle
		var star_lbl := Label.new()
		star_lbl.text = _stars_text(stars) if unlocked else ""
		star_lbl.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		star_lbl.offset_top = -20
		star_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		star_lbl.add_theme_font_size_override("font_size", 12)
		star_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.2))
		star_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		btn.add_child(star_lbl)

		if unlocked:
			btn.pressed.connect(_on_level_pressed.bind(i))
			# Gentle idle brightness pulse so nodes look "alive" on the map
			var glow_tw := btn.create_tween().set_loops()
			glow_tw.tween_property(btn, "modulate", Color(1.15, 1.10, 1.05), 1.3).set_trans(Tween.TRANS_SINE)
			glow_tw.tween_property(btn, "modulate", Color.WHITE, 1.3).set_trans(Tween.TRANS_SINE)

		vbox.add_child(btn)

		# Level name label beneath the circle
		var name_lbl := Label.new()
		name_lbl.text = _get_level_name(i) if unlocked else "???"
		name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 11)
		name_lbl.add_theme_color_override("font_color", accent.lightened(0.3) if unlocked else Color(0.72, 0.74, 0.88))
		name_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		name_lbl.add_theme_constant_override("outline_size", 2)
		name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_lbl.custom_minimum_size = Vector2(100, 0)
		name_lbl.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(name_lbl)

		level_grid.add_child(vbox)


func _get_level_name(level_id: int) -> String:
	var path := "res://resources/level_data/level_%d.tres" % level_id
	if ResourceLoader.exists(path):
		var data = load(path)
		if data and data.level_name != "":
			return data.level_name
	return "Level %d" % level_id


func _stars_text(count: int) -> String:
	return "★".repeat(count) + "☆".repeat(3 - count)


func _on_level_pressed(level_id: int) -> void:
	SfxManager.play_click()
	# Show difficulty picker overlay before launching. Player picks
	# Easy/Normal/Hard → start_level called with chosen difficulty.
	_show_difficulty_picker(level_id)


func _show_difficulty_picker(level_id: int) -> void:
	# Lazy-build a modal overlay with three difficulty buttons. Dismisses
	# on selection or background tap. Reads multipliers from GameManager
	# so the buttons can show their reward / risk preview.
	if has_node("DifficultyPicker"):
		return
	var dim := ColorRect.new()
	dim.name = "DifficultyPicker"
	dim.color = Color(0, 0, 0, 0.72)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(dim)
	var center := PanelContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	center.anchor_left = 0.5
	center.anchor_top = 0.5
	center.anchor_right = 0.5
	center.anchor_bottom = 0.5
	center.offset_left = -260
	center.offset_right = 260
	center.offset_top = -180
	center.offset_bottom = 180
	center.add_theme_stylebox_override("panel", DesignTokens.panel_box(DesignTokens.COL_STROKE_STRONG, DesignTokens.RADIUS_L, DesignTokens.SP_XL))
	dim.add_child(center)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", DesignTokens.SP_M)
	center.add_child(col)
	var heading := Label.new()
	heading.text = "Schwierigkeit wähle"
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	DesignTokens.style_heading(heading, DesignTokens.FONT_HEADING)
	col.add_child(heading)
	var subtitle := Label.new()
	subtitle.text = "Höchere Schwierigkeit = meh Aminos + meh Gold"
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	DesignTokens.style_label(subtitle, DesignTokens.FONT_LABEL_SM, true)
	col.add_child(subtitle)
	# Three buttons: Easy / Normal / Hard with diamond-shape SVG icon
	# (E/N/H badges with semantic gradient: blue/gold/red).
	var configs := [
		{"diff": GameManager.Difficulty.EASY,   "label": "EIFACH", "svg": "difficulty_easy",   "subtitle": "Chli langsamer · 0.5× Aminos · 0.8× Gold · max 2★",    "primary": false},
		{"diff": GameManager.Difficulty.NORMAL, "label": "NORMAL", "svg": "difficulty_normal", "subtitle": "Standard · 1.0× Aminos · 1.0× Gold · max 3★",         "primary": true},
		{"diff": GameManager.Difficulty.HARD,   "label": "BRUTAL", "svg": "difficulty_hard",   "subtitle": "Brutal · 1.75× Aminos · 1.35× Gold · min 1★ gratis", "primary": false},
	]
	for cfg in configs:
		var btn := Button.new()
		btn.text = cfg.label + "\n" + cfg.subtitle
		btn.custom_minimum_size = Vector2(0, 70)
		btn.icon = IconLibrary.get_icon(cfg.svg)
		btn.expand_icon = false
		btn.icon_alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.add_theme_constant_override("icon_max_width", 44)
		DesignTokens.style_button(btn, cfg.primary, DesignTokens.FONT_LABEL)
		btn.pressed.connect(_launch_level.bind(level_id, cfg.diff))
		col.add_child(btn)
	var cancel := Button.new()
	cancel.text = "Abbreche"
	cancel.custom_minimum_size = Vector2(0, 40)
	DesignTokens.style_button(cancel, false, DesignTokens.FONT_LABEL_SM)
	cancel.pressed.connect(func():
		dim.queue_free())
	col.add_child(cancel)
	dim.gui_input.connect(func(ev):
		# Click outside the panel = cancel
		if ev is InputEventMouseButton and ev.pressed:
			var local: Vector2 = ev.position - center.global_position
			if local.x < 0 or local.y < 0 or local.x > center.size.x or local.y > center.size.y:
				dim.queue_free())


func _launch_level(level_id: int, difficulty: int) -> void:
	SfxManager.play_click()
	GameManager.start_level(level_id, difficulty)
	get_tree().change_scene_to_file("res://scenes/ui/story_screen.tscn")


func _on_back_button_pressed() -> void:
	SfxManager.play_click()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
