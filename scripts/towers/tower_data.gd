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

# Farm tower (ROADMAP #38). If > 0, the tower generates `gold_per_round`
# at the start of each wave instead of shooting. `damage` and
# `attack_speed` are ignored. Upgrades increase the yield via
# `upgrade_damage_bonus` (repurposed as "gold bonus per tier").
@export var gold_per_round: int = 0

# Support tower (ROADMAP #38). If true, the tower has no offensive
# attack but emits a visible buff aura of radius `buff_range` that
# boosts nearby towers' damage/speed (via `buff_damage_pct` /
# `buff_speed_pct`). Effect applied by adjacency_manager.
@export var is_support: bool = false

# Projectile pierce count (ROADMAP #38, Lemurius). 1 = hit one enemy
# then despawn (default). 2+ = pass through that many targets before
# expiring, ignoring already-hit enemies.
@export var pierce_count: int = 1

# Crit chance (ROADMAP #38, Kühne). 0.0 = no crit, 0.25 = 25% chance
# of 2x damage, etc. Tiers can bump via `path_b_crit_bonus`.
@export var crit_chance: float = 0.0
@export var crit_multiplier: float = 2.0

# Pull mechanic (ROADMAP #38, Amösius). If > 0, the tower drags its
# target backwards along the path by this fraction of total path on
# every hit. 0.05 = reel back 5% per tick.
@export var pull_path_fraction: float = 0.0

# Cone burst (ROADMAP #38, Cordula). If > 0, projectile hits all
# enemies within this cone half-angle (radians) from aim direction.
@export var cone_half_angle: float = 0.0

# Visual projectile style — how the base_projectile draws itself.
# Each tower is thematically distinct: only Lemurius throws actual bananas.
# Options: "banana" (default), "volleyball", "flask", "pollen", "tongue"
@export var projectile_style: String = "banana"

# Per-tower offset from tower center where projectiles spawn. Lets
# Amösius's tongue emanate from his mouth instead of center, etc.
@export var projectile_origin_offset: Vector2 = Vector2.ZERO

# If true (JoJo-style chem splash), projectile leaves a lingering
# acid/ground pool on impact that ticks DoT for `ground_pool_duration`
# seconds at `ground_pool_damage_per_tick` damage per 0.5s.
@export var leaves_ground_pool: bool = false
@export var ground_pool_duration: float = 3.0
@export var ground_pool_damage_per_tick: float = 4.0
@export var ground_pool_radius: float = 70.0

# Visual
@export var base_color: Color = Color.BLUE
@export var projectile_color: Color = Color.YELLOW
@export var custom_texture: Texture2D = null

# Linear upgrades (legacy — used if no path_*_tier_names defined)
@export var upgrade_costs: Array[int] = [150, 300, 600]
@export var upgrade_damage_bonus: Array[float] = [10.0, 20.0, 40.0]
@export var upgrade_range_bonus: Array[float] = [15.0, 30.0, 50.0]
@export var upgrade_speed_bonus: Array[float] = [0.1, 0.2, 0.4]
@export var upgrade_names: Array[String] = ["Level 2", "Level 3", "Level 4"]

# Branching upgrade paths (BTD5-style). When path_a_tier_names is non-empty
# this tower uses paths A and B instead of the linear upgrade arrays above.
# Both paths can independently reach tier 3. Tier 0 = not upgraded, 3 = max.
@export var path_a_display: String = ""  # e.g. "Schnelli Banane"
@export var path_a_tier_names: Array[String] = []  # 3 entries
@export var path_a_costs: Array[int] = []
@export var path_a_damage_bonus: Array[float] = []
@export var path_a_range_bonus: Array[float] = []
@export var path_a_speed_bonus: Array[float] = []
@export var path_a_tint: Color = Color(1, 1, 1, 1)

@export var path_b_display: String = ""  # e.g. "Scharfi Banane"
@export var path_b_tier_names: Array[String] = []
@export var path_b_costs: Array[int] = []
@export var path_b_damage_bonus: Array[float] = []
@export var path_b_range_bonus: Array[float] = []
@export var path_b_speed_bonus: Array[float] = []
@export var path_b_tint: Color = Color(1, 1, 1, 1)


func has_branching_upgrades() -> bool:
	return path_a_tier_names.size() > 0 and path_b_tier_names.size() > 0


func get_sell_value(upgrade_level: int) -> int:
	var total_invested := buy_cost
	for i in upgrade_level:
		if i < upgrade_costs.size():
			total_invested += upgrade_costs[i]
	return int(total_invested * sell_return_pct)


func get_sell_value_branched(path_a_tier: int, path_b_tier: int) -> int:
	var total_invested := buy_cost
	for i in path_a_tier:
		if i < path_a_costs.size():
			total_invested += path_a_costs[i]
	for i in path_b_tier:
		if i < path_b_costs.size():
			total_invested += path_b_costs[i]
	return int(total_invested * sell_return_pct)
