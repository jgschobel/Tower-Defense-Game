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
	master_slider.value = GameManager.master_volume
	music_slider.value = GameManager.music_volume
	sfx_slider.value = GameManager.sfx_volume
	_refresh_labels()


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
