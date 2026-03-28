extends Control

## Game over / Victory popup shown when a level ends.

@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var stars_label: Label = $Panel/VBoxContainer/StarsLabel
@onready var message_label: Label = $Panel/VBoxContainer/MessageLabel
@onready var retry_button: Button = $Panel/VBoxContainer/HBoxContainer/RetryButton
@onready var next_button: Button = $Panel/VBoxContainer/HBoxContainer/NextButton
@onready var menu_button: Button = $Panel/VBoxContainer/HBoxContainer/MenuButton


func show_victory(stars: int) -> void:
	visible = true
	if title_label:
		title_label.text = "VICTORY!"
	if stars_label:
		stars_label.text = "*".repeat(stars) + "-".repeat(3 - stars)
	if message_label:
		if stars == 3:
			message_label.text = "Perfect! Not a scratch!"
		elif stars == 2:
			message_label.text = "Well done!"
		else:
			message_label.text = "Close call... but you made it!"
	if next_button:
		next_button.visible = GameManager.current_level < GameManager.MAX_LEVELS


func show_defeat() -> void:
	visible = true
	if title_label:
		title_label.text = "DEFEATED"
	if stars_label:
		stars_label.text = ""
	if message_label:
		message_label.text = "They broke through! Try again?"
	if next_button:
		next_button.visible = false


func _on_retry_button_pressed() -> void:
	Engine.time_scale = 1.0
	GameManager.start_level(GameManager.current_level)
	get_tree().reload_current_scene()


func _on_next_button_pressed() -> void:
	Engine.time_scale = 1.0
	var next_level := GameManager.current_level + 1
	GameManager.start_level(next_level)
	var path := "res://scenes/game/level_%d.tscn" % next_level
	if ResourceLoader.exists(path):
		get_tree().change_scene_to_file(path)
	else:
		get_tree().change_scene_to_file("res://scenes/game/game.tscn")


func _on_menu_button_pressed() -> void:
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
