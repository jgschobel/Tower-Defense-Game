class_name TowerData
extends Resource

## Defines a tower type. Create .tres files in resources/tower_data/.

enum TargetMode { FIRST, LAST, CLOSEST, STRONGEST }
enum DamageType { PHYSICAL, MAGIC, PURE }

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var friend_character_id: String = ""

# Cost
@export var buy_cost: int = 100
@export var sell_return_pct: float = 0.6

# Combat stats
@export var damage: float = 20.0
@export var attack_speed: float = 1.0
@export var attack_range: float = 150.0
@export var damage_type: DamageType = DamageType.PHYSICAL
@export var target_mode: TargetMode = TargetMode.FIRST

# Special properties
@export var is_splash: bool = false
@export var splash_radius: float = 50.0
@export var splash_damage_pct: float = 0.5
@export var slow_amount: float = 0.0
@export var slow_duration: float = 0.0
@export var can_target_flying: bool = true
@export var buff_range: float = 0.0
@export var buff_damage_pct: float = 0.0
@export var buff_speed_pct: float = 0.0

# Visual
@export var base_color: Color = Color.BLUE
@export var projectile_color: Color = Color.YELLOW
@export var custom_texture: Texture2D = null

# Upgrades (up to 3 levels)
@export var upgrade_costs: Array[int] = [150, 300, 600]
@export var upgrade_damage_bonus: Array[float] = [10.0, 20.0, 40.0]
@export var upgrade_range_bonus: Array[float] = [15.0, 30.0, 50.0]
@export var upgrade_speed_bonus: Array[float] = [0.1, 0.2, 0.4]
@export var upgrade_names: Array[String] = ["Level 2", "Level 3", "Level 4"]


func get_sell_value(upgrade_level: int) -> int:
	var total_invested := buy_cost
	for i in upgrade_level:
		total_invested += upgrade_costs[i]
	return int(total_invested * sell_return_pct)
