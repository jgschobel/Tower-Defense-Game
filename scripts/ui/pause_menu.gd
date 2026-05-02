extends Control

## Pause menu overlay.


func _ready() -> void:
	# Force full-viewport size. When a Control is a direct child of a
	# Node2D (GameLevel here), Godot does NOT auto-size it from anchors
	# — the root rect collapses to 0×0 and the center-anchored Panel
	# ends up at screen origin (top-left). Explicitly snapping to the
	# viewport rect keeps the Panel's anchor math correct.
	_fit_viewport()
	get_viewport().size_changed.connect(_fit_viewport)
	# Style the central panel — was default transparent which made the
	# menu look like floating text on the dimmer. Now a proper rounded
	# dark panel with a warm gold border.
	var panel: PanelContainer = get_node_or_null("Panel")
	if panel:
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.12, 0.10, 0.08, 0.95)
		sb.border_color = Color(0.95, 0.78, 0.18, 0.85)
		sb.border_width_left = 2
		sb.border_width_right = 2
		sb.border_width_top = 2
		sb.border_width_bottom = 2
		sb.corner_radius_top_left = 14
		sb.corner_radius_top_right = 14
		sb.corner_radius_bottom_left = 14
		sb.corner_radius_bottom_right = 14
		sb.content_margin_left = 24
		sb.content_margin_right = 24
		sb.content_margin_top = 18
		sb.content_margin_bottom = 18
		panel.add_theme_stylebox_override("panel", sb)
	# Title gold tint
	var title: Label = get_node_or_null("Panel/VBox/Title")
	if title:
		title.add_theme_color_override("font_color", Color(1.0, 0.88, 0.25))
		title.add_theme_color_override("font_outline_color", Color(0.2, 0.1, 0))
		title.add_theme_constant_override("outline_size", 4)


func _fit_viewport() -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	size = vp_size
	position = Vector2.ZERO


func show_pause() -> void:
	visible = true
	_fit_viewport()  # re-snap in case viewport changed while hidden
	modulate = Color(1, 1, 1, 0)
	# Process this node while the tree is paused so the fade-in tween
	# can tick. The tween inherits from this node's process_mode.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 1.0, 0.2)
	get_tree().paused = true
	MusicManager.pause_music()


func hide_pause() -> void:
	visible = false
	get_tree().paused = false
	MusicManager.resume_music()


func _on_resume_button_pressed() -> void:
	SfxManager.play_click()
	hide_pause()
	GameManager.set_state(GameManager.GameState.PLAYING)


func _on_restart_button_pressed() -> void:
	SfxManager.play_click()
	get_tree().paused = false
	Engine.time_scale = 1.0
	GameManager.start_level(GameManager.current_level)
	get_tree().reload_current_scene()


func _on_options_button_pressed() -> void:
	# Open options menu on top of the pause overlay without un-pausing.
	# The options_menu autoloads its values from GameManager, no extra
	# wiring needed beyond instancing + reparenting.
	var options_scene: PackedScene = preload("res://scenes/ui/options_menu.tscn")
	var opts = options_scene.instantiate()
	opts.process_mode = Node.PROCESS_MODE_ALWAYS  # survive pause
	add_child(opts)
	if opts.has_signal("closed"):
		opts.closed.connect(func(): opts.queue_free())


func _on_quit_button_pressed() -> void:
	SfxManager.play_click()
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
