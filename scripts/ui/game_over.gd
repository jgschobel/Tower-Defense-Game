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
	# Confetti burst that runs through the fade-in pause so the screen
	# isn't a dead 2-second blank wait. CPUParticles2D layered behind
	# the panel — colors picked from the gold/red/green/blue
	# competition palette. Stars > 0 only (defeat path skips this).
	if stars > 0:
		_spawn_victory_confetti(stars)
	if title_label:
		title_label.text = "SIEG!"
		_animate_title_pop()
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


func _spawn_victory_confetti(stars: int) -> void:
	# Layered CPUParticles2D bursts — three colors of confetti rain from
	# the top of the screen, scaled by star count. Stars=1 gets a modest
	# 30, stars=2 gets 60, stars=3 gets 100. Cleanup after 3.5s.
	var burst_count: int = 30 if stars == 1 else (60 if stars == 2 else 100)
	var colors: Array = [
		Color(1.0, 0.85, 0.20, 0.92),  # gold
		Color(0.95, 0.30, 0.25, 0.90), # red
		Color(0.45, 0.85, 0.40, 0.90), # green
		Color(0.45, 0.65, 1.0, 0.90),  # blue
	]
	for i in colors.size():
		var p := CPUParticles2D.new()
		p.name = "ConfettiLayer%d" % i
		p.position = Vector2(640 + (i - 1.5) * 50.0, -30)
		p.one_shot = true
		p.explosiveness = 0.85
		p.amount = burst_count
		p.lifetime = 2.2
		p.direction = Vector2(0, 1)
		p.spread = 30.0
		p.initial_velocity_min = 220.0
		p.initial_velocity_max = 380.0
		p.scale_amount_min = 2.5
		p.scale_amount_max = 5.5
		p.gravity = Vector2(0, 380)
		p.angular_velocity_min = -250.0
		p.angular_velocity_max = 250.0
		p.color = colors[i]
		add_child(p)
		p.emitting = true
		get_tree().create_timer(3.5).timeout.connect(p.queue_free)


func _animate_title_pop() -> void:
	# Scale-bounce on the title when victory shows. SIEG! lands with
	# weight instead of just fading in like the rest of the panel.
	if title_label == null:
		return
	title_label.scale = Vector2(0.35, 0.35)
	title_label.pivot_offset = title_label.size * 0.5
	var tw := create_tween()
	tw.tween_interval(2.15)  # after the panel finishes fading in
	tw.tween_property(title_label, "scale", Vector2(1.15, 1.15), 0.22) \
		.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(title_label, "scale", Vector2.ONE, 0.16) \
		.set_trans(Tween.TRANS_SINE)


func show_defeat() -> void:
	visible = true
	modulate = Color(1, 1, 1, 0)
	_spawn_defeat_vignette()
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 1.0, 0.4)
	if title_label:
		title_label.text = "VERLORE!"
		_animate_title_defeat()
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


func _animate_title_defeat() -> void:
	if title_label == null:
		return
	title_label.pivot_offset = title_label.size * 0.5
	title_label.scale = Vector2(2.0, 2.0)
	title_label.rotation = 0.0
	var tw := create_tween()
	tw.tween_property(title_label, "scale", Vector2.ONE, 0.30) \
		.set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.06)
	tw.tween_property(title_label, "rotation",  0.08, 0.05)
	tw.tween_property(title_label, "rotation", -0.08, 0.05)
	tw.tween_property(title_label, "rotation",  0.05, 0.04)
	tw.tween_property(title_label, "rotation", -0.04, 0.04)
	tw.tween_property(title_label, "rotation",  0.0,  0.07).set_trans(Tween.TRANS_SINE)


func _spawn_defeat_vignette() -> void:
	var wrap := Panel.new()
	wrap.name = "DefeatVignette"
	wrap.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	wrap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ring := StyleBoxFlat.new()
	ring.bg_color = Color(0, 0, 0, 0)
	ring.border_color = Color(0.85, 0.05, 0.05, 0.0)
	ring.border_width_left = 46
	ring.border_width_right = 46
	ring.border_width_top = 46
	ring.border_width_bottom = 46
	wrap.add_theme_stylebox_override("panel", ring)
	add_child(wrap)
	move_child(wrap, 1)  # behind Panel (Dimmer→Vignette→Panel)
	var tw := wrap.create_tween()
	tw.tween_method(func(a: float): ring.border_color = Color(0.85, 0.05, 0.05, a),
		0.0, 0.70, 0.40).set_trans(Tween.TRANS_SINE)
	tw.tween_interval(0.20)
	tw.tween_method(func(a: float): ring.border_color = Color(0.85, 0.05, 0.05, a),
		0.70, 0.38, 0.45).set_trans(Tween.TRANS_SINE)
	tw.tween_method(func(a: float): ring.border_color = Color(0.85, 0.05, 0.05, a),
		0.38, 0.55, 0.90).set_trans(Tween.TRANS_SINE)


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
