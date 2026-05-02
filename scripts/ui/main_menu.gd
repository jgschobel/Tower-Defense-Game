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
		DesignTokens.style_heading(title, DesignTokens.FONT_TITLE)
		title.add_theme_constant_override("outline_size", DesignTokens.OUTLINE_TITLE)
		# Hold the title still — pulsing was distracting per user "looks
		# unprofessional" feedback. Pro games don't pulse their titles.
	var subtitle: Label = get_node_or_null("HBox/MenuPanel/VBox/Subtitle")
	if subtitle:
		DesignTokens.style_label(subtitle, DesignTokens.FONT_LABEL_LG, true)


func _style_menu_buttons() -> void:
	# Primary CTA = "RAUBZUG STARTE" gets the gold-rim treatment, others
	# get the muted secondary style. Visual hierarchy: the player's eye
	# lands on PLAY first.
	var play_btn = get_node_or_null("HBox/MenuPanel/VBox/PlayButton")
	if play_btn:
		DesignTokens.style_button(play_btn, true, DesignTokens.FONT_LABEL_LG)
	for path in [
		"HBox/MenuPanel/VBox/LoreButton",
		"HBox/MenuPanel/VBox/OptionsButton",
		"HBox/MenuPanel/VBox/QuitButton",
	]:
		var btn = get_node_or_null(path)
		if btn:
			DesignTokens.style_button(btn, false, DesignTokens.FONT_LABEL_LG)
	# Aminos-Lade as a secondary item (no longer "shouty" gold — fits
	# the minimalist hierarchy where only PLAY pops).
	var vbox: VBoxContainer = get_node_or_null("HBox/MenuPanel/VBox")
	if vbox and not vbox.has_node("AminosMainButton"):
		var aminos_main := Button.new()
		aminos_main.name = "AminosMainButton"
		aminos_main.text = "AMINOS-LADE"
		aminos_main.custom_minimum_size = Vector2(0, 52)
		aminos_main.pressed.connect(_on_aminos_button_pressed)
		DesignTokens.style_button(aminos_main, false, DesignTokens.FONT_LABEL_LG)
		vbox.add_child(aminos_main)
		var play_idx := vbox.get_node_or_null("PlayButton")
		if play_idx:
			vbox.move_child(aminos_main, play_idx.get_index() + 1)


func _show_run_stats() -> void:
	# Small corner stats badge showing persistent progress: total stars
	# across all levels + lifetime kills. Returning players see their
	# cumulative damage to the M-Tüüfel grow between sessions.
	if has_node("RunStats"):
		return
	# Persistent progress badge — clean panel using design tokens.
	var stats_panel := PanelContainer.new()
	stats_panel.name = "RunStats"
	stats_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stats_panel.anchors_preset = Control.PRESET_TOP_LEFT
	stats_panel.offset_left = DesignTokens.SP_L
	stats_panel.offset_top = DesignTokens.SP_L
	stats_panel.add_theme_stylebox_override("panel", DesignTokens.panel_box(DesignTokens.COL_STROKE_NORMAL, DesignTokens.RADIUS_S, DesignTokens.SP_M))
	var stats_v := VBoxContainer.new()
	stats_v.add_theme_constant_override("separation", DesignTokens.SP_XS)
	stats_panel.add_child(stats_v)
	var max_stars: int = GameManager.MAX_LEVELS * 3
	var stars_lbl := Label.new()
	stars_lbl.text = "★ %d / %d" % [GameManager.total_stars, max_stars]
	DesignTokens.style_label(stars_lbl, DesignTokens.FONT_LABEL_LG)
	stars_lbl.add_theme_color_override("font_color", DesignTokens.COL_GOLD)
	stats_v.add_child(stars_lbl)
	var kills_lbl := Label.new()
	kills_lbl.text = "⚔ %d Kills" % GameManager.total_kills
	DesignTokens.style_label(kills_lbl, DesignTokens.FONT_LABEL_SM, true)
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
