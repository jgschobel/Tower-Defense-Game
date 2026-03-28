extends Control

## Pause menu overlay.


func show_pause() -> void:
	visible = true
	get_tree().paused = true


func hide_pause() -> void:
	visible = false
	get_tree().paused = false


func _on_resume_button_pressed() -> void:
	hide_pause()
	GameManager.set_state(GameManager.GameState.PLAYING)


func _on_restart_button_pressed() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	GameManager.start_level(GameManager.current_level)
	get_tree().reload_current_scene()


func _on_quit_button_pressed() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
