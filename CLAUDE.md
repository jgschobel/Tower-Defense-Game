# Affoltern Banani Raubzug

## User Directives (Durable)

These are the user's standing preferences — persist across all sessions,
autonomous or manual. Update only when the user explicitly changes them.

- **Scope target**: Bloons TD-style depth, in a small Swiss-German
  package. No scope is "too big" if justified — ship it in slices.
- **Subscription**: Claude Max → use parallel Sonnet subagents freely,
  use Opus 4.7 for planning and architecture, Sonnet 4.6 for execution.
- **Review appetite**: none. Do not ask the user to review PRs. The
  autonomous loop auto-merges validated changes. User manages from
  phone via GitHub mobile.
- **Feedback rhythm**: user plays the deployed HTML5 build
  (`jgschobel.github.io/Tower-Defense-Game/`) and edits `ROADMAP.md`
  when they want to redirect priorities. Otherwise: zero input required.
- **Language**: game content in Swiss German (Züridütsch), code and
  commit messages in English.
- **Platform**: mobile landscape 1280×720, touch-first, GL Compatibility
  renderer. Also deploys to web via GitHub Pages for on-phone testing.
- **Aesthetic**: friends' faces as towers (Lemurius, Kühne, JoJo,
  Cordula, Amösius), vegan food enemies, De Vegan-Tüüfel as the
  antagonist. Migros Affoltern as world.

## Project Overview
A **landscape** (1280x720) tower defense game built in **Godot 4.6** using GDScript. Set in Migros Affoltern, Zürich. 5 tower characters (Lemurius, Kühne, JoJo, Cordula, Amösius) fight cursed vegan products controlled by De Vegan-Tüüfel. All text in Swiss German. Procedural chiptune music + SFX, AI-generated art, story cutscenes, 3 levels with 10 waves each.

## Tech Stack
- **Engine**: Godot 4.6 (GL Compatibility renderer for mobile)
- **Language**: GDScript
- **Target**: Mobile (landscape 1280x720), touch controls
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

## AI Agent Architecture
This project uses a multi-agent workflow. See `AGENTS.md` for full details.

- **Conductor (Opus)** — architecture, code, creative, git, user communication
- **Art Factory (Sonnet, background)** — image generation via Stability AI, background removal, batch processing
- **Code Scout (Sonnet, on-demand)** — codebase exploration, file searches, path validation
- **Build Tester (Sonnet, pre-push)** — validates signal connections, file paths, node references

API keys stored at `C:/Users/josef/.api_keys/keys.json` (outside repo).

## Common Pitfalls
- Enemies are `PathFollow2D` nodes — they must be children of a `Path2D` to work
- Tower `DetectionArea` uses `area_entered`/`area_exited` to detect enemy `HitBox` Area2D — NOT body_entered
- Autoloads reference each other (GameManager ↔ CurrencyManager) — ensure both are registered in project.godot
- When using `.bind()` on signal connections, bound args come AFTER the signal's own args in the callback
- Use simple types in signal declarations (Node2D, Resource, int) not custom class_name types

## Build & Run
- Open in Godot 4.6+
- Main scene: `res://scenes/ui/main_menu.tscn`
- Mobile export: use the Android or iOS export templates with GL Compatibility
