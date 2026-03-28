extends Control

## Level selection screen. Shows levels 1-10 with star ratings and lock states.

@onready var level_grid: GridContainer = $MarginContainer/VBoxContainer/LevelGrid


func _ready() -> void:
	_populate_levels()


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
		else:
			btn.modulate = Color(0.5, 0.5, 0.5, 0.8)

		level_grid.add_child(btn)


func _get_level_name(level_id: int) -> String:
	var path := "res://resources/level_data/level_%d.tres" % level_id
	if ResourceLoader.exists(path):
		var data = load(path)
		if data and data.level_name != "":
			return data.level_name
	return "Level %d" % level_id


func _stars_text(count: int) -> String:
	if count == 3:
		return "***"
	elif count == 2:
		return "**-"
	elif count == 1:
		return "*--"
	else:
		return "---"


func _on_level_pressed(level_id: int) -> void:
	GameManager.start_level(level_id)
	# Go to story screen as a full scene change (not overlay)
	get_tree().change_scene_to_file("res://scenes/ui/story_screen.tscn")
	# The story screen will call setup() in its own _ready()
	# We pass the level_id via GameManager.current_level


func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
