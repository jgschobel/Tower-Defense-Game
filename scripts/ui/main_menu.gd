extends Control

## Main menu for Affoltern Banani Raubzug.

var _ai_panel_scene: PackedScene = preload("res://scenes/ui/ai_generator_panel.tscn")
var _ai_panel: Control = null
var _lore_panel: Control = null


func _ready() -> void:
	GameManager.set_state(GameManager.GameState.MENU)


func _on_play_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/level_select.tscn")


func _on_settings_button_pressed() -> void:
	if _ai_panel == null:
		_ai_panel = _ai_panel_scene.instantiate()
		add_child(_ai_panel)
	_ai_panel.visible = true


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
	dimmer.color = Color(0, 0, 0, 0.8)
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

	# Title
	var title := Label.new()
	title.text = "THE SACRED LORE OF AFFOLTERN BANANI RAUBZUG"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(title)

	# Backstory
	var backstory := Label.new()
	backstory.text = """In the quiet suburb of Affoltern, Zürich, two unlikely heroes share a flat above the Migros supermarket on Wehntalerstrasse.

One fateful Tuesday evening, they returned from their weekly Apéro at Biergarten Affoltern to find the Migros in CHAOS. The shelves were alive. The Cervelats were marching. The Brötli were screaming.

And at the center of it all, floating above the self-checkout machines, was DER M-TEUFEL — The Migros Devil himself. A demonic entity made of expired Cumulus points and broken shopping cart wheels.

"Your banana discount is REVOKED!" he screamed.

Lemurius dropped her Alnatura smoothie.
Amösius's tongue went dry.

This was personal."""
	backstory.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vbox.add_child(backstory)

	# Character bios
	for char_id in Lore.CHARACTER_BIOS:
		var bio_data: Dictionary = Lore.CHARACTER_BIOS[char_id]
		var bio_label := Label.new()
		bio_label.text = "--- %s ---\n%s" % [bio_data.name, bio_data.bio]
		bio_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(bio_label)

	# Enemy lore
	var enemy_title := Label.new()
	enemy_title.text = "--- THE CURSED PRODUCTS ---"
	enemy_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(enemy_title)

	for enemy_id in Lore.ENEMY_LORE:
		var enemy_label := Label.new()
		enemy_label.text = Lore.ENEMY_LORE[enemy_id]
		enemy_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vbox.add_child(enemy_label)

	# Close button
	var close_btn := Button.new()
	close_btn.text = "Close the Sacred Texts"
	close_btn.anchors_preset = Control.PRESET_BOTTOM_WIDE
	close_btn.anchor_top = 1.0
	close_btn.anchor_bottom = 1.0
	close_btn.offset_top = -60
	close_btn.offset_left = 30
	close_btn.offset_right = -30
	close_btn.pressed.connect(func() -> void: panel.visible = false)
	panel.add_child(close_btn)

	return panel
