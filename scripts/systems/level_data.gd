class_name LevelData
extends Resource

## Data resource for a single level. Create .tres files in resources/level_data/.

@export var level_id: int = 1
@export var level_name: String = "Level 1"
@export var description: String = ""
@export var starting_gold: int = 200
@export var starting_lives: int = 20

# Array of wave dictionaries:
# { "groups": [{ "enemy_id": "basic", "count": 5, "spawn_delay": 0.8 }] }
@export var waves: Array = []

# Map theme
@export var background_color: Color = Color(0.2, 0.5, 0.2) # grassy green
@export var path_color: Color = Color(0.6, 0.5, 0.3) # dirt brown
