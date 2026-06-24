extends Control

## Options menu — master + music + SFX volume sliders. Values saved via GameManager.
## Accessible from main menu and pause menu.

signal closed

@onready var master_slider: HSlider = $Panel/VBox/MasterRow/MasterSlider
@onready var master_pct_label: Label = $Panel/VBox/MasterRow/MasterPct
@onready var music_slider: HSlider = $Panel/VBox/MusicRow/MusicSlider
@onready var music_pct_label: Label = $Panel/VBox/MusicRow/MusicPct
@onready var sfx_slider: HSlider = $Panel/VBox/SfxRow/SfxSlider
@onready var sfx_pct_label: Label = $Panel/VBox/SfxRow/SfxPct
@onready var close_button: Button = $Panel/VBox/CloseButton


func _ready() -> void:
	_apply_theme()
	# Standalone path (playtester UI tour / change_scene_to_file): set the
	# dimmer to a warm dark brown that matches COL_BG_DEEPEST so the screen
	# feels designed rather than a pure black void (#1195 re-opens #1191).
	# Overlay path (add_child from main_menu / pause_menu): reduce opacity
	# to 0.60 so the scene behind reads clearly — 0.78 was so opaque that
	# the dark main-menu background still looked pure-black (#1195).
	var dimmer := $Dimmer as ColorRect
	if dimmer:
		var is_overlay := get_parent() != get_tree().root
		if is_overlay:
			dimmer.color = Color(0, 0, 0, 0.60)
		else:
			# warm dark brown — not pure black, matches game palette
			dimmer.color = Color(0.06, 0.05, 0.04, 1.0)
	master_slider.value = GameManager.master_volume
	music_slider.value = GameManager.music_volume
	sfx_slider.value = GameManager.sfx_volume
	_refresh_labels()
	# _apply_theme() resizes MusicLabel and SfxLabel (style_label call), which
	# defers layout recalc on those HBoxContainers. The slider knob position is
	# computed from slider width at draw time; if layout hasn't finalized yet
	# the width is 0, placing the knob at pixel 0 regardless of value.
	# queue_redraw() schedules a redraw AFTER the deferred layout pass.
	master_slider.queue_redraw()
	music_slider.queue_redraw()
	sfx_slider.queue_redraw()


func _apply_theme() -> void:
	# Gradient overlay: warm amber at top → translucent dark at bottom.
	# Prior amber (0.28,0.20,0.07 @ 0.70) was effectively invisible over the
	# dark dimmer. Brightened to (0.55,0.38,0.14 @ 0.88) so the gradient
	# clearly marks "you're in a menu" even on an OLED screen (#1195).
	if not has_node("GradOverlay"):
		var gt := GradientTexture2D.new()
		var g := Gradient.new()
		g.set_color(0, Color(0.55, 0.38, 0.14, 0.88))
		g.set_color(1, Color(0.08, 0.06, 0.03, 0.55))
		gt.gradient = g
		gt.fill_from = Vector2(0.5, 0.0)
		gt.fill_to = Vector2(0.5, 1.0)
		gt.fill = GradientTexture2D.FILL_LINEAR
		var grad := TextureRect.new()
		grad.name = "GradOverlay"
		grad.texture = gt
		grad.set_anchors_preset(Control.PRESET_FULL_RECT)
		grad.expand_mode = TextureRect.EXPAND_FILL_STRETCH
		grad.stretch_mode = TextureRect.STRETCH_SCALE
		add_child(grad)
		move_child(grad, 1)  # After Dimmer (0), before Panel (2)
	# Give the panel a proper game-style background so it doesn't vanish
	# against the full-screen dimmer (fixes playtest issue #153).
	var panel := $Panel as PanelContainer
	if panel:
		panel.add_theme_stylebox_override("panel",
				DesignTokens.panel_box(DesignTokens.COL_STROKE_STRONG, 14, 28))
	# Title in gold heading style
	var title := get_node_or_null("Panel/VBox/TitleLabel") as Label
	if title:
		DesignTokens.style_heading(title, DesignTokens.FONT_HEADING)
	# Row label colours
	for row_lbl_path: String in ["Panel/VBox/MusicRow/MusicLabel", "Panel/VBox/SfxRow/SfxLabel"]:
		var lbl := get_node_or_null(row_lbl_path) as Label
		if lbl:
			DesignTokens.style_label(lbl, DesignTokens.FONT_LABEL_LG)
	# Close button styled as a primary action
	if close_button:
		DesignTokens.style_button(close_button, true)


func _refresh_labels() -> void:
	master_pct_label.text = "%d%%" % int(master_slider.value * 100)
	music_pct_label.text = "%d%%" % int(music_slider.value * 100)
	sfx_pct_label.text = "%d%%" % int(sfx_slider.value * 100)


func _on_master_slider_value_changed(value: float) -> void:
	GameManager.set_master_volume(value)
	_refresh_labels()


func _on_music_slider_value_changed(value: float) -> void:
	GameManager.set_music_volume(value)
	if MusicManager and MusicManager.has_method("refresh_volume"):
		MusicManager.refresh_volume()
	_refresh_labels()


func _on_sfx_slider_value_changed(value: float) -> void:
	GameManager.set_sfx_volume(value)
	SfxManager.play_click()
	_refresh_labels()


func _on_close_button_pressed() -> void:
	SfxManager.play_click()
	closed.emit()
	queue_free()
