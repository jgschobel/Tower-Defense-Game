extends Control

## Game over / Victory popup shown when a level ends.

@onready var title_label: Label = $Panel/VBoxContainer/TitleLabel
@onready var stars_label: Label = $Panel/VBoxContainer/StarsLabel
@onready var message_label: Label = $Panel/VBoxContainer/MessageLabel
@onready var retry_button: Button = $Panel/VBoxContainer/HBoxContainer/RetryButton
@onready var next_button: Button = $Panel/VBoxContainer/HBoxContainer/NextButton
@onready var menu_button: Button = $Panel/VBoxContainer/HBoxContainer/MenuButton

var _victory_messages_3 := [
	"Perfekt! Kei einzigi Banane verlore!",
	"De M-Tüüfel isch am hüle! Din Banane-Rabatt isch SICHER!",
	"Lemurius und Amösius sind unstoppbar!",
]
var _victory_messages_2 := [
	"Guet gmacht! D'Migros isch grettet!",
	"Chli Schäde, aber mir händ's packt!",
]
var _victory_messages_1 := [
	"Knapp... aber mir händ überläbt!",
	"Das isch eng gsi. Meh Banane nächscht Mal!",
]
var _defeat_messages := [
	"Sie sind duregbroche! D'Banane sind verlore!",
	"De M-Tüüfel lachet! Versuch's nomal!",
	"D'Migros isch gfalle... aber mir gäbed nöd uf!",
]


func show_victory(stars: int) -> void:
	visible = true
	# Juice: 2s hold before the panel fades in — lets the final pop
	# breathe and the player's win land emotionally (per BTD pacing).
	modulate = Color(1, 1, 1, 0)
	var fade := create_tween()
	fade.tween_interval(2.0)
	fade.tween_property(self, "modulate:a", 1.0, 0.5)
	if title_label:
		title_label.text = "SIEG!"
	if stars_label:
		# Start with empty outlines — each earned star pops in sequentially
		stars_label.text = "☆☆☆"
	if message_label:
		var flavor: String
		if stars == 3:
			flavor = _victory_messages_3[randi() % _victory_messages_3.size()]
		elif stars == 2:
			flavor = _victory_messages_2[randi() % _victory_messages_2.size()]
		else:
			flavor = _victory_messages_1[randi() % _victory_messages_1.size()]
		message_label.text = "%s\n\nK.O.s dä Rundi: %d  •  Total: %d\nCumulus-Punkte: %d%s" % [
				flavor, GameManager.level_kills, GameManager.total_kills,
				GameManager.cumulus_balance,
				"  (✓ +50 Gold nächschti Runde!)" if GameManager.cumulus_balance >= 100 else ""]
	if next_button:
		next_button.visible = GameManager.current_level < GameManager.MAX_LEVELS
	if retry_button:
		retry_button.text = "Nomal"
	if next_button:
		next_button.text = "Wiiter"
	if menu_button:
		menu_button.text = "Menü"
	_animate_star_reveal(stars)


func _animate_star_reveal(stars: int) -> void:
	if not stars_label or stars <= 0:
		return
	var tw := create_tween()
	tw.tween_interval(2.65)  # panel finishes fading in at ~2.5s; small extra beat
	for i in stars:
		var step: int = i + 1
		tw.tween_callback(func():
			stars_label.text = "★".repeat(step) + "☆".repeat(3 - step)
			stars_label.scale = Vector2(1.45, 1.45)
			SfxManager.play_upgrade()
		)
		tw.tween_property(stars_label, "scale", Vector2.ONE, 0.28).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		if i < stars - 1:
			tw.tween_interval(0.20)


func show_defeat() -> void:
	visible = true
	modulate = Color(1, 1, 1, 0)
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 1.0, 0.4)
	if title_label:
		title_label.text = "VERLORE!"
	if stars_label:
		stars_label.text = ""
	if message_label:
		var flavor: String = _defeat_messages[randi() % _defeat_messages.size()]
		message_label.text = "%s\n\nK.O.s dä Rundi: %d  •  Total: %d\nCumulus-Punkte: %d%s" % [
				flavor, GameManager.level_kills, GameManager.total_kills,
				GameManager.cumulus_balance,
				"  (✓ +50 Gold nächschti Runde!)" if GameManager.cumulus_balance >= 100 else ""]
	if next_button:
		next_button.visible = false
	if retry_button:
		retry_button.text = "Nomal"
	if menu_button:
		menu_button.text = "Menü"


func _on_retry_button_pressed() -> void:
	SfxManager.play_click()
	Engine.time_scale = 1.0
	GameManager.start_level(GameManager.current_level)
	get_tree().reload_current_scene()


func _on_next_button_pressed() -> void:
	SfxManager.play_click()
	Engine.time_scale = 1.0
	var next_level := GameManager.current_level + 1
	GameManager.start_level(next_level)
	get_tree().change_scene_to_file("res://scenes/ui/story_screen.tscn")


func _on_menu_button_pressed() -> void:
	SfxManager.play_click()
	Engine.time_scale = 1.0
	# Don't stop music — MusicManager auto-switches to menu track on
	# state change via GameManager.game_state_changed.
	get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn")
