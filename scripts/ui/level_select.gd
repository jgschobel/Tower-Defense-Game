extends Control

## Level selection screen with background art.

@onready var level_grid: GridContainer = $MarginContainer/VBoxContainer/LevelGrid
@onready var bg: TextureRect = $Background


func _ready() -> void:
	# Try to load level select background
	var bg_path := "res://assets/textures/ui/levelselect_bg.png"
	if bg and ResourceLoader.exists(bg_path):
		bg.texture = load(bg_path)
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
	lbl.text = "★ %d / %d   ☠ %d" % [GameManager.total_stars, max_stars, GameManager.total_kills]
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

	for i in range(1, GameManager.MAX_LEVELS + 1):
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(0, 90)
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL

		var unlocked := i <= GameManager.levels_unlocked
		var stars: int = 0
		if GameManager.level_stars.has(i):
			stars = GameManager.level_stars.get(i, 0)
		elif GameManager.level_stars.has(str(i)):
			stars = GameManager.level_stars.get(str(i), 0)

		var level_name := _get_level_name(i)
		btn.text = "%d. %s\n%s" % [i, level_name, _stars_text(stars)]
		btn.disabled = not unlocked
		btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

		if unlocked:
			btn.pressed.connect(_on_level_pressed.bind(i))
			# Color hint per level theme
			var level_colors := {1: Color(0.9, 0.85, 0.7), 2: Color(0.7, 0.85, 1.0), 3: Color(0.95, 0.8, 0.6), 4: Color(0.8, 0.65, 0.85), 5: Color(1.0, 0.5, 0.4), 6: Color(0.5, 0.5, 0.6)}
			btn.modulate = level_colors.get(i, Color.WHITE)
		else:
			btn.modulate = Color(0.4, 0.4, 0.4, 0.6)

		level_grid.add_child(btn)


func _get_level_name(level_id: int) -> String:
	var path := "res://resources/level_data/level_%d.tres" % level_id
	if ResourceLoader.exists(path):
		var data = load(path)
		if data and data.level_name != "":
			return data.level_name
	return "Level %d" % level_id


func _stars_text(count: int) -> String:
	# Unicode stars — zero-asset visual upgrade over plain ASCII asterisks.
	return "★".repeat(count) + "☆".repeat(3 - count)


func _on_level_pressed(level_id: int) -> void:
	SfxManager.play_click()
	GameManager.start_level(level_id)
	get_tree().change_scene_to_file("res://scenes/ui/story_screen.tscn")


func _on_back_button_pressed() -> void:
	SfxManager.play_click()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
