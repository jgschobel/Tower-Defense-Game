# Affoltern Banani Raubzug

## Project Overview
A mobile tower defense game built in **Godot 4.6** using GDScript. Set in Migros Affoltern (Zürich), players control Lemurius (banana-throwing lemur) and Amösius (tongue-stunning gecko) to fight cursed supermarket products controlled by Der M-Teufel. Features bananas as currency, friend photos as characters, procedural chiptune music, AI image generation integration, and a lore system with story cutscenes.

## Tech Stack
- **Engine**: Godot 4.6 (GL Compatibility renderer for mobile)
- **Language**: GDScript
- **Target**: Mobile (portrait 720x1280), touch controls
- **Renderer**: GL Compatibility (not Vulkan) for max device support

## Project Structure
```
scripts/
  autoload/         → Singletons: GameManager, CurrencyManager
  enemies/          → BaseEnemy, EnemyData (Resource class)
  towers/           → BaseTower, TowerData (Resource class)
  projectiles/      → BaseProjectile
  systems/          → WaveManager, TowerPlacement, GameLevel, LevelData
  ui/               → MainMenu, LevelSelect, HUD, GameOver, PauseMenu, TowerInfoPanel, FriendPhotoManager
scenes/
  enemies/          → base_enemy.tscn
  towers/           → base_tower.tscn
  projectiles/      → base_projectile.tscn
  game/             → game.tscn (main gameplay), level_N.tscn (per-level)
  ui/               → main_menu.tscn, level_select.tscn, hud.tscn, etc.
resources/
  enemy_data/       → .tres files per enemy type (basic, fast, tank, healer, flying, boss)
  tower_data/       → .tres files per tower type (basic, sniper, splash, slow, support)
  level_data/       → .tres files per level (level_1, level_2, level_3)
assets/
  textures/         → towers/, enemies/, ui/, maps/, projectiles/
  audio/            → sfx/, music/
```

## Architecture
- **Autoloads**: `GameManager` (game state, save/load, lives, levels) and `CurrencyManager` (gold economy) are global singletons
- **Data-driven design**: Tower types, enemy types, and levels are defined as Godot `Resource` (.tres) files — add new content by creating new .tres files, no code changes needed
- **Scene composition**: Base scenes (base_tower.tscn, base_enemy.tscn) are reused with different data resources attached
- **Signal-based communication**: Systems communicate via signals, not direct references

## Coding Conventions
- **GDScript style**: Follow Godot's official GDScript style guide
- **Naming**: snake_case for variables/functions, PascalCase for classes, UPPER_SNAKE for constants/enums
- **Type annotations**: Use explicit types for function parameters and return values
- **Signals**: Use simple types (int, String, Node2D, Resource) in signal parameter types — avoid custom class_name types in signal declarations as they can cause parse-order issues
- **Typed arrays**: Use `Array` (untyped) instead of `Array[CustomClass]` when the custom class is defined via class_name, to avoid parse-order dependencies
- **No trailing commas** in function call arguments
- **Enum values**: Avoid using names that could conflict with GDScript keywords (e.g., use `PURE` instead of `TRUE`)

## Important Patterns
- **Adding a new tower**: Create a new .tres file in `resources/tower_data/` using the TowerData resource type, add its ID to `_shop_tower_ids` in hud.gd
- **Adding a new enemy**: Create a new .tres file in `resources/enemy_data/`, then reference its ID in level wave definitions
- **Adding a new level**: Create `resources/level_data/level_N.tres`, optionally create `scenes/game/level_N.tscn`
- **Friend photos**: Assigned via FriendPhotoManager UI, stored in `user://photos/`, mapped by character_id in GameManager

## Common Pitfalls
- Enemies are `PathFollow2D` nodes — they must be children of a `Path2D` to work
- The `DetectionArea` on towers uses `body_entered`/`body_exited` — enemies need a physics body to be detected
- Autoloads reference each other (GameManager ↔ CurrencyManager) — ensure both are registered in project.godot
- When using `.bind()` on signal connections, bound args come AFTER the signal's own args in the callback

## Build & Run
- Open in Godot 4.6+
- Main scene: `res://scenes/ui/main_menu.tscn`
- Mobile export: use the Android or iOS export templates with GL Compatibility
