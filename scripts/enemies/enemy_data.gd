class_name EnemyData
extends Resource

## Defines a type of enemy. Create .tres files in resources/enemy_data/.

@export var id: String = ""
@export var display_name: String = ""
@export var friend_character_id: String = "" # maps to a friend's photo

# Stats
@export var max_health: float = 100.0
@export var move_speed: float = 100.0 # pixels per second
@export var armor: float = 0.0 # flat damage reduction
@export var gold_reward: int = 10

# Visual
@export var base_color: Color = Color.RED
@export var scale_factor: float = 1.0
@export var custom_texture: Texture2D = null

# Special abilities
@export var is_flying: bool = false
@export var is_boss: bool = false
@export var heals_nearby: bool = false
@export var heal_amount: float = 5.0
@export var heal_radius: float = 60.0
@export var spawns_on_death: String = "" # enemy id to spawn when this dies
@export var spawn_count: int = 0
