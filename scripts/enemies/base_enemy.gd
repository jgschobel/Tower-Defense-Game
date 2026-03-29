class_name BaseEnemy
extends PathFollow2D

## Base enemy that follows a Path2D. Attach to a Path2D node.
## Loses health from tower projectiles, awards gold on death.

signal enemy_died(enemy: Node)
signal enemy_reached_end(enemy: Node)

@export var data: EnemyData

var health: float = 100.0
var max_health: float = 100.0
var move_speed: float = 80.0
var armor: float = 0.0
var gold_reward: int = 10
var slow_factor: float = 1.0
var slow_timer: float = 0.0
var is_dead: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var health_bar: ProgressBar = $HealthBar

var heal_timer_node: Timer = null


func _ready() -> void:
	if has_node("HealTimer"):
		heal_timer_node = $HealTimer
	if data:
		_apply_data()
	_update_visual()


func _apply_data() -> void:
	max_health = data.max_health
	health = max_health
	move_speed = data.move_speed
	armor = data.armor
	gold_reward = data.gold_reward

	if data.heals_nearby and heal_timer_node:
		heal_timer_node.wait_time = 1.0
		heal_timer_node.start()


func _process(delta: float) -> void:
	if is_dead:
		return

	# Handle slow debuff
	if slow_timer > 0.0:
		slow_timer -= delta
		if slow_timer <= 0.0:
			slow_factor = 1.0
			# Reset tint when slow wears off
			modulate = Color.WHITE

	# Move along path
	var speed := move_speed * slow_factor
	progress += speed * delta

	# Check if reached end of path
	if progress_ratio >= 1.0:
		_reached_end()
		return


func take_damage(amount: float, _damage_type: String = "physical") -> void:
	if is_dead:
		return

	var actual_damage := maxf(1.0, amount - armor)
	health -= actual_damage
	_update_health_bar()

	# Show floating damage number
	_show_damage_number(actual_damage)

	# Flash white on hit, then restore
	modulate = Color(2.0, 2.0, 2.0)
	var tween := create_tween()
	var restore_color := Color(0.6, 0.7, 1.0) if slow_factor < 1.0 else Color.WHITE
	tween.tween_property(self, "modulate", restore_color, 0.15)

	if health <= 0.0:
		die()


func apply_slow(factor: float, duration: float) -> void:
	slow_factor = factor
	slow_timer = duration
	# Tint blue-ish when slowed (whole node including drawn shapes)
	modulate = Color(0.6, 0.7, 1.0, 1.0)


func show_hit_reaction() -> void:
	# Show a floating angry/sad label above the enemy
	var reaction := Label.new()
	var reactions := [">:(", "!!!", "grr", "ugh", "NO!", "why?!"]
	reaction.text = reactions[randi() % reactions.size()]
	reaction.add_theme_font_size_override("font_size", 18)
	reaction.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	reaction.position = Vector2(-15, -50)
	reaction.z_index = 10
	add_child(reaction)

	# Float up and fade out
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(reaction, "position:y", -80.0, 0.8)
	tween.tween_property(reaction, "modulate:a", 0.0, 0.8)
	tween.chain().tween_callback(reaction.queue_free)


func die() -> void:
	if is_dead:
		return
	is_dead = true
	CurrencyManager.add_gold(gold_reward)
	_show_gold_earned()
	SfxManager.play_death()

	# Spawn children on death if configured
	if data and data.spawns_on_death != "" and data.spawn_count > 0:
		_spawn_children()

	enemy_died.emit(self)

	# Death animation
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ZERO, 0.3)
	tween.tween_callback(queue_free)


func _reached_end() -> void:
	if is_dead:
		return
	is_dead = true
	GameManager.lose_life()
	enemy_reached_end.emit(self)
	queue_free()


func _update_visual() -> void:
	if not sprite:
		return

	# Try to load friend photo
	if data and data.friend_character_id != "":
		var photo := GameManager.get_friend_photo(data.friend_character_id)
		if photo:
			sprite.texture = photo
			sprite.scale = Vector2.ONE * data.scale_factor * 0.5
			return

	# Use custom texture if set
	if data and data.custom_texture:
		sprite.texture = data.custom_texture
		sprite.visible = true
		# Auto-scale based on enemy size
		var max_dim := maxf(data.custom_texture.get_width(), data.custom_texture.get_height())
		var target_size := 50.0 * data.scale_factor
		var s := target_size / max_dim
		sprite.scale = Vector2(s, s)
		# Add name label above sprite
		var label := Label.new()
		label.text = data.display_name
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 3)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2(-45, -target_size * 0.6 - 15)
		add_child(label)
		return

	# Hide the default icon sprite — we draw food shapes instead
	sprite.visible = false

	# Add a name label
	if data:
		var label := Label.new()
		label.text = data.display_name
		label.add_theme_font_size_override("font_size", 11)
		label.add_theme_color_override("font_color", Color.WHITE)
		label.add_theme_color_override("font_outline_color", Color.BLACK)
		label.add_theme_constant_override("outline_size", 3)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		label.position = Vector2(-45, -65)
		add_child(label)

	queue_redraw()


func _draw() -> void:
	if not data:
		# Fallback circle
		draw_circle(Vector2.ZERO, 15.0, Color.RED)
		return

	if sprite and sprite.visible:
		return  # Using a real texture, don't draw

	var s := data.scale_factor
	var c := data.base_color

	match data.id:
		"basic":
			# Brötli (bread roll) - round golden bun
			draw_circle(Vector2.ZERO, 16.0 * s, c)
			draw_circle(Vector2.ZERO, 12.0 * s, Color(0.9, 0.78, 0.55))
			# Cross on top
			draw_line(Vector2(-6, -6) * s, Vector2(6, 6) * s, Color(0.7, 0.55, 0.3), 2.0)
			draw_line(Vector2(6, -6) * s, Vector2(-6, 6) * s, Color(0.7, 0.55, 0.3), 2.0)
			# Angry eyes
			draw_circle(Vector2(-5, -3) * s, 2.5, Color.WHITE)
			draw_circle(Vector2(5, -3) * s, 2.5, Color.WHITE)
			draw_circle(Vector2(-5, -3) * s, 1.2, Color.BLACK)
			draw_circle(Vector2(5, -3) * s, 1.2, Color.BLACK)
		"fast":
			# Toblerone - triangular chocolate bar
			var tri := PackedVector2Array([
				Vector2(0, -18) * s,
				Vector2(-12, 12) * s,
				Vector2(12, 12) * s,
			])
			draw_colored_polygon(tri, c)
			draw_colored_polygon(tri, Color(0.65, 0.4, 0.2), PackedVector2Array(), null)
			# Eyes
			draw_circle(Vector2(-4, 0) * s, 2.0, Color.WHITE)
			draw_circle(Vector2(4, 0) * s, 2.0, Color.WHITE)
			draw_circle(Vector2(-4, 0) * s, 1.0, Color.BLACK)
			draw_circle(Vector2(4, 0) * s, 1.0, Color.BLACK)
		"tank":
			# Cervelat (sausage) - thick oval
			var rect := Rect2(Vector2(-22, -10) * s, Vector2(44, 20) * s)
			draw_rect(rect, c, true)
			# Rounded ends
			draw_circle(Vector2(-22, 0) * s, 10.0 * s, c)
			draw_circle(Vector2(22, 0) * s, 10.0 * s, c)
			# Skin lines
			draw_line(Vector2(-10, -8) * s, Vector2(-10, 8) * s, Color(0.6, 0.35, 0.25), 1.5)
			draw_line(Vector2(10, -8) * s, Vector2(10, 8) * s, Color(0.6, 0.35, 0.25), 1.5)
			# Angry face
			draw_circle(Vector2(-5, -2) * s, 2.5, Color.WHITE)
			draw_circle(Vector2(5, -2) * s, 2.5, Color.WHITE)
			draw_circle(Vector2(-5, -2) * s, 1.2, Color.BLACK)
			draw_circle(Vector2(5, -2) * s, 1.2, Color.BLACK)
		"healer":
			# Rivella bottle - red bottle shape
			draw_rect(Rect2(Vector2(-8, -15) * s, Vector2(16, 30) * s), c, true)
			draw_rect(Rect2(Vector2(-5, -22) * s, Vector2(10, 8) * s), Color(0.8, 0.15, 0.15), true)
			# Label
			draw_rect(Rect2(Vector2(-6, -5) * s, Vector2(12, 10) * s), Color.WHITE, true)
			# Plus sign (healing)
			draw_line(Vector2(0, -3) * s, Vector2(0, 3) * s, Color.RED, 2.0)
			draw_line(Vector2(-3, 0) * s, Vector2(3, 0) * s, Color.RED, 2.0)
		"flying":
			# Fondue pot - round pot with cheese dripping
			draw_circle(Vector2.ZERO, 14.0 * s, c)
			draw_rect(Rect2(Vector2(-16, -4) * s, Vector2(32, 12) * s), Color(0.4, 0.35, 0.3), true)
			# Cheese drips
			draw_circle(Vector2(-8, 10) * s, 4.0 * s, Color(1, 0.9, 0.4))
			draw_circle(Vector2(6, 12) * s, 3.0 * s, Color(1, 0.9, 0.4))
			# Steam
			draw_line(Vector2(-5, -14) * s, Vector2(-7, -22) * s, Color(1, 1, 1, 0.4), 1.5)
			draw_line(Vector2(5, -14) * s, Vector2(7, -22) * s, Color(1, 1, 1, 0.4), 1.5)
		"boss":
			# M-Teufel - big orange M with horns
			draw_circle(Vector2.ZERO, 25.0 * s, c)
			# Horns
			draw_line(Vector2(-12, -20) * s, Vector2(-18, -35) * s, Color(0.8, 0.2, 0), 4.0)
			draw_line(Vector2(12, -20) * s, Vector2(18, -35) * s, Color(0.8, 0.2, 0), 4.0)
			# M letter
			draw_line(Vector2(-10, 8) * s, Vector2(-10, -5) * s, Color.WHITE, 3.0)
			draw_line(Vector2(-10, -5) * s, Vector2(0, 3) * s, Color.WHITE, 3.0)
			draw_line(Vector2(0, 3) * s, Vector2(10, -5) * s, Color.WHITE, 3.0)
			draw_line(Vector2(10, -5) * s, Vector2(10, 8) * s, Color.WHITE, 3.0)
			# Evil eyes
			draw_circle(Vector2(-8, -8) * s, 4.0, Color(1, 1, 0))
			draw_circle(Vector2(8, -8) * s, 4.0, Color(1, 1, 0))
			draw_circle(Vector2(-8, -8) * s, 2.0, Color.RED)
			draw_circle(Vector2(8, -8) * s, 2.0, Color.RED)
		_:
			# Unknown enemy - generic colored circle
			draw_circle(Vector2.ZERO, 15.0 * s, c)
			draw_circle(Vector2(-4, -3), 2.0, Color.WHITE)
			draw_circle(Vector2(4, -3), 2.0, Color.WHITE)
			draw_circle(Vector2(-4, -3), 1.0, Color.BLACK)
			draw_circle(Vector2(4, -3), 1.0, Color.BLACK)


func _get_base_color() -> Color:
	if data:
		return data.base_color
	return Color.RED


func _update_health_bar() -> void:
	if health_bar:
		health_bar.value = (health / max_health) * 100.0
		health_bar.visible = health < max_health


func _heal_nearby() -> void:
	if not data or not data.heals_nearby:
		return
	var enemies := get_tree().get_nodes_in_group("enemies")
	for enemy_node in enemies:
		if enemy_node == self:
			continue
		var enemy := enemy_node as BaseEnemy
		if enemy and not enemy.is_dead:
			if global_position.distance_to(enemy.global_position) <= data.heal_radius:
				enemy.health = minf(enemy.max_health, enemy.health + data.heal_amount)


func _spawn_children() -> void:
	if not data or data.spawns_on_death == "" or data.spawn_count <= 0:
		return
	var parent_path := get_parent() as Path2D
	if not parent_path:
		return
	var enemy_scene := preload("res://scenes/enemies/base_enemy.tscn")
	var data_path := "res://resources/enemy_data/%s.tres" % data.spawns_on_death
	if not ResourceLoader.exists(data_path):
		return
	var child_data = load(data_path)
	for i in data.spawn_count:
		var child = enemy_scene.instantiate()
		child.data = child_data
		child.add_to_group("enemies")
		parent_path.add_child(child)
		child.progress = progress + (i * 20.0)


func _show_damage_number(amount: float) -> void:
	var label := Label.new()
	label.text = "-%d" % int(amount)
	label.add_theme_font_size_override("font_size", 14)
	label.add_theme_color_override("font_color", Color(1, 0.3, 0.2))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 2)
	label.position = Vector2(randf_range(-15, 15), -40)
	label.z_index = 20
	add_child(label)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", -75.0, 0.6)
	tween.tween_property(label, "modulate:a", 0.0, 0.6)
	tween.chain().tween_callback(label.queue_free)


func _show_gold_earned() -> void:
	var label := Label.new()
	label.text = "+%d" % gold_reward
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color(1, 0.9, 0.2))
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 3)
	label.position = Vector2(0, -50)
	label.z_index = 20
	# Add to parent so it persists after enemy freed
	get_parent().add_child(label)
	label.global_position = global_position + Vector2(0, -30)
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(label, "position:y", label.position.y - 50.0, 0.8)
	tween.tween_property(label, "modulate:a", 0.0, 0.8)
	tween.chain().tween_callback(label.queue_free)


func _on_heal_timer_timeout() -> void:
	_heal_nearby()
