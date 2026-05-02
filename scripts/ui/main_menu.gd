extends Control

## Main menu for Affoltern Banani Raubzug.

var _lore_panel: Control = null


func _ready() -> void:
	Engine.time_scale = 1.0
	# Continuous music — don't stop on menu entry. MusicManager auto-
	# switches to the "menu" track via GameManager.game_state_changed.
	GameManager.set_state(GameManager.GameState.MENU)
	_style_title()
	_show_run_stats()
	_style_menu_buttons()


func _style_title() -> void:
	var title: Label = get_node_or_null("HBox/MenuPanel/VBox/Title")
	if title:
		title.add_theme_font_size_override("font_size", 44)
		title.add_theme_color_override("font_color", Color(1, 0.92, 0.25))
		title.add_theme_color_override("font_outline_color", Color(0.20, 0.08, 0))
		title.add_theme_constant_override("outline_size", 8)
		# Subtle scale-pulse so the title feels alive without being noisy
		title.pivot_offset = title.size * 0.5
		var pulse := title.create_tween().set_loops()
		pulse.tween_property(title, "scale", Vector2(1.04, 1.04), 1.6).set_trans(Tween.TRANS_SINE)
		pulse.tween_property(title, "scale", Vector2.ONE, 1.6).set_trans(Tween.TRANS_SINE)
	var subtitle: Label = get_node_or_null("HBox/MenuPanel/VBox/Subtitle")
	if subtitle:
		subtitle.add_theme_font_size_override("font_size", 18)
		subtitle.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
		subtitle.add_theme_color_override("font_outline_color", Color(0.15, 0.05, 0))
		subtitle.add_theme_constant_override("outline_size", 3)


func _style_menu_buttons() -> void:
	# Apply warm dark style with gold hover to all menu buttons. Was
	# default Godot grey-on-grey which looked unfinished next to the
	# rich AI illustration.
	for path in [
		"HBox/MenuPanel/VBox/PlayButton",
		"HBox/MenuPanel/VBox/LoreButton",
		"HBox/MenuPanel/VBox/OptionsButton",
		"HBox/MenuPanel/VBox/QuitButton",
	]:
		var btn = get_node_or_null(path)
		if btn:
			_style_menu_button(btn)
	# Insert a prominent Aminos-Lade button between Raubzug and Gschicht
	# so it's discoverable from the main menu (was a small corner button
	# the user kept missing).
	var vbox: VBoxContainer = get_node_or_null("HBox/MenuPanel/VBox")
	if vbox and not vbox.has_node("AminosMainButton"):
		var aminos_main := Button.new()
		aminos_main.name = "AminosMainButton"
		aminos_main.text = "✨ AMINOS-LADE"
		aminos_main.custom_minimum_size = Vector2(0, 56)
		aminos_main.pressed.connect(_on_aminos_button_pressed)
		_style_menu_button(aminos_main)
		# Brighter gold accent so it stands apart from the main flow
		var sb_a := StyleBoxFlat.new()
		sb_a.bg_color = Color(0.22, 0.17, 0.06, 0.96)
		sb_a.border_color = Color(1.0, 0.80, 0.20, 1.0)
		sb_a.border_width_left = 2
		sb_a.border_width_right = 2
		sb_a.border_width_top = 1
		sb_a.border_width_bottom = 2
		sb_a.corner_radius_top_left = 10
		sb_a.corner_radius_top_right = 10
		sb_a.corner_radius_bottom_left = 10
		sb_a.corner_radius_bottom_right = 10
		sb_a.content_margin_left = 14
		sb_a.content_margin_right = 14
		sb_a.content_margin_top = 8
		sb_a.content_margin_bottom = 8
		aminos_main.add_theme_stylebox_override("normal", sb_a)
		aminos_main.add_theme_color_override("font_color", Color(1, 0.92, 0.45))
		vbox.add_child(aminos_main)
		# Place it second (right after "RAUBZUG STARTE")
		var play_btn := vbox.get_node_or_null("PlayButton")
		if play_btn:
			vbox.move_child(aminos_main, play_btn.get_index() + 1)


func _style_menu_button(btn: Button) -> void:
	var base := StyleBoxFlat.new()
	base.bg_color = Color(0.18, 0.16, 0.14, 0.92)
	base.border_color = Color(0.55, 0.42, 0.18, 0.85)
	base.border_width_left = 1
	base.border_width_right = 1
	base.border_width_top = 1
	base.border_width_bottom = 1
	base.corner_radius_top_left = 10
	base.corner_radius_top_right = 10
	base.corner_radius_bottom_left = 10
	base.corner_radius_bottom_right = 10
	base.content_margin_left = 14
	base.content_margin_right = 14
	base.content_margin_top = 8
	base.content_margin_bottom = 8
	var hover := base.duplicate() as StyleBoxFlat
	hover.bg_color = Color(0.32, 0.24, 0.10, 1.0)
	hover.border_color = Color(1.0, 0.82, 0.20, 1.0)
	var pressed := base.duplicate() as StyleBoxFlat
	pressed.bg_color = Color(0.46, 0.32, 0.10, 1.0)
	pressed.border_color = Color.WHITE
	btn.add_theme_stylebox_override("normal", base)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_color_override("font_color", Color(1.0, 0.92, 0.78))
	btn.add_theme_color_override("font_hover_color", Color(1.0, 0.95, 0.45))
	btn.add_theme_font_size_override("font_size", 22)


func _show_run_stats() -> void:
	# Small corner stats badge showing persistent progress: total stars
	# across all levels + lifetime kills. Returning players see their
	# cumulative damage to the M-Tüüfel grow between sessions.
	if has_node("RunStats"):
		return
	# Stats badge — wrap in a styled PanelContainer so the persistent
	# progress reads as a real HUD element instead of floating text in
	# the corner. Two rows: ★ stars line + ⚔ kills line.
	var stats_panel := PanelContainer.new()
	stats_panel.name = "RunStats"
	stats_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_panel.anchors_preset = Control.PRESET_TOP_LEFT
	stats_panel.offset_left = 16
	stats_panel.offset_top = 16
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.10, 0.08, 0.06, 0.85)
	sb.border_color = Color(0.95, 0.78, 0.18, 0.75)
	sb.border_width_left = 2
	sb.border_width_right = 1
	sb.border_width_top = 1
	sb.border_width_bottom = 1
	sb.corner_radius_top_left = 8
	sb.corner_radius_top_right = 8
	sb.corner_radius_bottom_left = 8
	sb.corner_radius_bottom_right = 8
	sb.content_margin_left = 12
	sb.content_margin_right = 14
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	stats_panel.add_theme_stylebox_override("panel", sb)
	var stats_v := VBoxContainer.new()
	stats_v.add_theme_constant_override("separation", 2)
	stats_panel.add_child(stats_v)
	var max_stars: int = GameManager.MAX_LEVELS * 3
	var stars_lbl := Label.new()
	stars_lbl.text = "★ Sterne: %d / %d" % [GameManager.total_stars, max_stars]
	stars_lbl.add_theme_font_size_override("font_size", 17)
	stars_lbl.add_theme_color_override("font_color", Color(1, 0.92, 0.45))
	stats_v.add_child(stars_lbl)
	var kills_lbl := Label.new()
	kills_lbl.text = "⚔ Kills: %d" % GameManager.total_kills
	kills_lbl.add_theme_font_size_override("font_size", 15)
	kills_lbl.add_theme_color_override("font_color", Color(0.95, 0.75, 0.35))
	stats_v.add_child(kills_lbl)
	add_child(stats_panel)

	# (Aminos-Lade now lives in the main menu button column via
	# _style_menu_buttons — no longer a small corner button)


func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/level_select.tscn")


func _on_aminos_button_pressed() -> void:
	# Routed from a button added dynamically by _show_run_stats
	# (ROADMAP #48). Kept as a named handler so the Editor can also
	# wire a .tscn button to it if a manual button is added later.
	SfxManager.play_click()
	get_tree().change_scene_to_file("res://scenes/ui/aminos_shop.tscn")


func _on_lore_button_pressed() -> void:
	if _lore_panel == null:
		_lore_panel = _create_lore_panel()
		add_child(_lore_panel)
	_lore_panel.visible = true


var _options_instance: Node = null


func _on_options_button_pressed() -> void:
	SfxManager.play_click()
	# Guard against double-instancing if the user taps the button twice
	# before the first Options overlay animates in. Audit P2 #24.
	if _options_instance and is_instance_valid(_options_instance):
		return
	var opts_scene := load("res://scenes/ui/options_menu.tscn") as PackedScene
	if opts_scene:
		var inst = opts_scene.instantiate()
		_options_instance = inst
		add_child(inst)
		if inst.has_signal("closed"):
			inst.closed.connect(func():
				_options_instance = null)


func _on_quit_button_pressed() -> void:
	get_tree().quit()


func _create_lore_panel() -> Control:
	var panel := Control.new()
	panel.anchors_preset = Control.PRESET_FULL_RECT
	panel.anchor_right = 1.0
	panel.anchor_bottom = 1.0

	var dimmer := ColorRect.new()
	dimmer.anchors_preset = Control.PRESET_FULL_RECT
	dimmer.anchor_right = 1.0
	dimmer.anchor_bottom = 1.0
	dimmer.color = Color(0, 0, 0, 0.85)
	panel.add_child(dimmer)

	var scroll := ScrollContainer.new()
	scroll.anchors_preset = Control.PRESET_FULL_RECT
	scroll.anchor_right = 1.0
	scroll.anchor_bottom = 1.0
	scroll.offset_left = 30
	scroll.offset_top = 30
	scroll.offset_right = -30
	scroll.offset_bottom = -80
	panel.add_child(scroll)

	var vbox := VBoxContainer.new()
	vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vbox.add_theme_constant_override("separation", 20)
	scroll.add_child(vbox)

	var title := Label.new()
	title.text = "D'HEILIGI GSCHICHT"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	var backstory := Label.new()
	backstory.text = """Im ruhige Vorort Affoltern, Züri, teiled sich zwei unglaubliche Helde en Wohnig über de Migros a de Wehntalerstrass.

Eimol, an eme schicksalhafte Ziischtig-Abe, sind sie vom Apéro im Biergarten Affoltern zrugg cho und händ ihri gliebti Migros im totale CHAOS gfunde. D'Regäl sind läbig gsi. D'Cervelats sind marschiert. D'Brötli händ gschrien.

Über de Sälf-Tscheckout-Maschine isch DE M-TÜÜFEL gschwebt — en dämonischi Entität gmacht us abglaufene Cumulus-Punkte und kaputte Iichaufswage-Rädli.

\"Din Banane-Rabatt isch WIDERUEFE!\" het er gschrien.

D'Lemurius het ihri Alnatura Smoothie la falle. Em Amösius sini Zunge isch trochne worde.

Das isch persönlich gsi."""
	backstory.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(backstory)

	for char_id in Lore.CHARACTER_BIOS:
		var bio_data: Dictionary = Lore.CHARACTER_BIOS[char_id]
		var bio_label := Label.new()
		bio_label.text = "\n--- %s ---\n%s" % [bio_data.name, bio_data.bio]
		bio_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(bio_label)

	var enemy_title := Label.new()
	enemy_title.text = "\n--- D'VERFLUECHTE PRODUKT ---"
	enemy_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(enemy_title)

	for enemy_id in Lore.ENEMY_LORE:
		var enemy_label := Label.new()
		enemy_label.text = Lore.ENEMY_LORE[enemy_id]
		enemy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(enemy_label)

	var close_btn := Button.new()
	close_btn.text = "Heiligi Texte zuemache"
	close_btn.anchors_preset = Control.PRESET_BOTTOM_WIDE
	close_btn.anchor_top = 1.0
	close_btn.anchor_bottom = 1.0
	close_btn.offset_top = -60
	close_btn.offset_left = 30
	close_btn.offset_right = -30
	close_btn.pressed.connect(func() -> void: panel.visible = false)
	panel.add_child(close_btn)

	return panel
