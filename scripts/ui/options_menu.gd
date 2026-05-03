extends Control

## Options menu — music + SFX volume sliders. Values saved via GameManager.
## Accessible from main menu and pause menu.

signal closed

@onready var music_slider: HSlider = $Panel/VBox/MusicRow/MusicSlider
@onready var music_pct_label: Label = $Panel/VBox/MusicRow/MusicPct
@onready var sfx_slider: HSlider = $Panel/VBox/SfxRow/SfxSlider
@onready var sfx_pct_label: Label = $Panel/VBox/SfxRow/SfxPct
@onready var close_button: Button = $Panel/VBox/CloseButton


func _ready() -> void:
	_apply_theme()
	music_slider.value = GameManager.music_volume
	sfx_slider.value = GameManager.sfx_volume
	_refresh_labels()


func _apply_theme() -> void:
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
	music_pct_label.text = "%d%%" % int(music_slider.value * 100)
	sfx_pct_label.text = "%d%%" % int(sfx_slider.value * 100)


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
