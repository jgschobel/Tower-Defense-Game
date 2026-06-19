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
@export var heals_nearby: bool = false
@export var heal_amount: float = 5.0
@export var heal_radius: float = 60.0
@export var spawns_on_death: String = "" # enemy id to spawn when this dies
@export var spawn_count: int = 0
# Multi-type payload (MOAB-style). When non-empty, each entry is an
# enemy ID to spawn on death — overrides spawns_on_death+spawn_count.
# Entries are repeated per desired count: ["fast","fast","fast","tank"].
@export var spawn_payload: Array = []

# Camo (ROADMAP #50). Invisible to towers unless at least one placed
# tower has `can_detect_camo` true. Visual: semi-transparent + dashed
# outline so players can see it too. Kühne is the intended detector.
@export var is_camo: bool = false

# Regrow (ROADMAP #50). If healing, enemy resurrects once at
# `regrow_hp_pct` of max_health if killed by non-PURE damage. Set by
# killing damage_type in base_enemy.die().
@export var can_regrow: bool = false
@export var regrow_hp_pct: float = 0.4

# Lead (ROADMAP #50). If true, only MAGIC or PURE damage deals full
# damage. PHYSICAL damage is reduced to 15% before armor.
@export var is_lead: bool = false

# Fondue-Bomb (ROADMAP #31). On death, heal all enemies within
# splash_on_death_radius by splash_on_death_heal_pct of THEIR max
# health. Feels like the ceramic-bloon annoyance of BTD.
@export var splash_on_death_radius: float = 0.0
@export var splash_on_death_heal_pct: float = 0.0

# Selbschtskan-Schiff (ROADMAP P1). When true, the enemy copies the
# silhouette of the most-recently-placed friend tower and is immune
# to damage from that tower_id. Forces multi-tower compositions —
# spam a single friend and you can't kill it. The actual immune
# tower_id is set per-spawn via meta("immune_to") by WaveManager.
@export var is_copycat: bool = false

# Röschti-Bombe (build-content 2026-06-19). On death, spawn a "Russ"
# (soot) cloud at the corpse position that lingers for explosion_duration
# seconds. Any BaseTower whose global_position falls inside
# explosion_radius gets its attack_speed multiplied by
# tower_attack_debuff_mult (range 0.0–1.0; smaller = harsher slow)
# while inside. Forces the player to place towers further from the path
# in late-game L6–L9 waves, or risk attack-rate collapse during clutch
# windows. The cloud is a sibling node (NOT a child of the enemy) so it
# survives die() returning the enemy to the pool.
@export var explodes_on_death: bool = false
@export var explosion_radius: float = 100.0
@export var explosion_duration: float = 3.0
@export var tower_attack_debuff_mult: float = 0.55
