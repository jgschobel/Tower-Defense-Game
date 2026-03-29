extends Control

## Main menu for Affoltern Banani Raubzug.

var _lore_panel: Control = null


func _ready() -> void:
	Engine.time_scale = 1.0
	MusicManager.stop_music()
	GameManager.set_state(GameManager.GameState.MENU)


func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/level_select.tscn")


func _on_lore_button_pressed() -> void:
	if _lore_panel == null:
		_lore_panel = _create_lore_panel()
		add_child(_lore_panel)
	_lore_panel.visible = true


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
