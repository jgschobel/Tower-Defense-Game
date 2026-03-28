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
			if sprite:
				sprite.modulate = _get_base_color()

	# Move along path
	var speed := move_speed * slow_factor
	progress += speed * delta

	# Check if reached end of path
	if progress_ratio >= 1.0:
		_reached_end()
		return

	_update_health_bar()


func take_damage(amount: float, _damage_type: String = "physical") -> void:
	if is_dead:
		return

	var actual_damage := maxf(1.0, amount - armor)
	health -= actual_damage

	# Flash white on hit, then restore to slow tint or base color
	if sprite:
		sprite.modulate = Color.WHITE
		var tween := create_tween()
		var restore_color := Color(0.6, 0.7, 1.0) if slow_factor < 1.0 else _get_base_color()
		tween.tween_property(sprite, "modulate", restore_color, 0.15)

	if health <= 0.0:
		die()


func apply_slow(factor: float, duration: float) -> void:
	slow_factor = factor
	slow_timer = duration
	# Tint blue-ish when slowed
	if sprite:
		sprite.modulate = Color(0.6, 0.7, 1.0, 1.0)


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
		return

	# Fallback: tint the default sprite
	sprite.modulate = _get_base_color()
	if data:
		sprite.scale = Vector2.ONE * data.scale_factor


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
	pass


func _on_heal_timer_timeout() -> void:
	_heal_nearby()
