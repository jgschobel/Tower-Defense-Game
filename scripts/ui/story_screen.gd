extends Control

## Story cutscene shown before each level. Typewriter text effect.

@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var subtitle_label: Label = $Panel/VBox/SubtitleLabel
@onready var story_label: Label = $Panel/VBox/ScrollContainer/StoryLabel
@onready var enemy_label: Label = $Panel/VBox/EnemyLabel
@onready var continue_button: Button = $Panel/VBox/ContinueButton

var _level_id: int = 1
var _full_text: String = ""
var _char_index: int = 0
var _typing: bool = false
var _chars_per_second: float = 40.0


func _ready() -> void:
	_level_id = GameManager.current_level
	var intro := Lore.get_level_intro(_level_id)

	if title_label:
		title_label.text = intro.title
	if subtitle_label:
		subtitle_label.text = intro.subtitle
	if enemy_label:
		enemy_label.text = "Enemies: %s" % intro.enemy_preview

	_full_text = intro.text
	_char_index = 0
	_typing = true
	if story_label:
		story_label.text = ""

	continue_button.text = "Skip..."


func _process(delta: float) -> void:
	if not _typing:
		return
	_char_index += int(_chars_per_second * delta)
	if _char_index >= _full_text.length():
		_char_index = _full_text.length()
		_typing = false
		continue_button.text = "LOS GEHT'S!"
	if story_label:
		story_label.text = _full_text.left(_char_index)


func _on_continue_button_pressed() -> void:
	if _typing:
		# Skip to end of text
		_typing = false
		_char_index = _full_text.length()
		if story_label:
			story_label.text = _full_text
		continue_button.text = "LOS GEHT'S!"
	else:
		# Start the level — change to the game scene
		var level_path := "res://scenes/game/level_%d.tscn" % _level_id
		if ResourceLoader.exists(level_path):
			get_tree().change_scene_to_file(level_path)
		else:
			get_tree().change_scene_to_file("res://scenes/game/game.tscn")
