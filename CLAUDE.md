# Affoltern Banani Raubzug

## User Directives (Durable)

These are the user's standing preferences — persist across all sessions,
autonomous or manual. Update only when the user explicitly changes them.

- **Scope target**: Bloons TD-style depth, in a small Swiss-German
  package. No scope is "too big" if justified — ship it in slices.
- **Subscription**: Claude Max — quota is finite, spend it on value.
  Model discipline (non-negotiable):
  - **Haiku 4.5** for all file-exploration / search subagents (Explore agent,
    Code Scout, grep/find tasks). 5× cheaper than Sonnet, fully capable.
  - **Sonnet 4.6** for code writing, bug fixing, content creation, git ops.
    This is the default for almost everything.
  - **Opus 4.7** ONLY for genuinely novel architecture decisions affecting
    5+ files or introducing a new system. At most once per week.
  - Never spawn Opus for a task Sonnet can handle. Never spawn Sonnet for
    a task Haiku can handle.
  Read discipline (non-negotiable):
  - Always `grep` before `Read`. Never read a file speculatively.
  - When reading, target the exact line range needed (±10 lines). Never
    read a 700-line file when you need 20 lines.
  - Max 3-4 file reads per fix before writing code and committing.
  Agent discipline:
  - Max 2-3 parallel subagents per turn. Never spawn 6 in parallel.
  - Give subagents tight, specific prompts — not "explore the codebase".
  Commit rhythm:
  - One logical fix = one commit. Do not accumulate 10 fixes then commit.
  - Commit and push after each standalone change. This also keeps context
    lean as the conversation compresses around commit boundaries.
  Autonomous run scope:
  - Each autonomous loop run should complete ~5-10 meaningful tasks then
    stop. Do not chain indefinitely — quota is shared with manual sessions.
- **Review appetite**: none. Do not ask the user to review PRs. The
  autonomous loop auto-merges validated changes. User manages from
  phone via GitHub mobile.
- **Do NOT ask the user to trigger workflow runs manually.** They
  hate that. Make workflows trigger themselves on push, or daisy-chain
  via `workflow_run` events, or use `repository_dispatch`. If something
  needs a one-shot execution, do it yourself (push a dummy commit,
  open a PR, etc). Never say "please click Run workflow on your phone".
- **Be maximally productive and proactive every session.** Ship as
  much as fits. Generate new ideas, don't wait for the user to ask.
  When you finish one fix, immediately pick up the next meaningful
  thing from ROADMAP or CI-failure issues and keep going. Write code,
  don't ask permission. The user prefers too much progress over too
  little ceremony.
- **Read your own CI failures.** The `ci-monitor.yml` workflow files
  a GitHub Issue with log tails whenever any workflow fails. Before
  starting new work, check `mcp__github__list_issues` with label
  `ci-failure` and fix those first. Close the issue when fixed.
- **Regular codebase audit to prevent chaos.** Every ~3rd self-improve
  run should pick Option 6 in `mode-self-improve.md` — scan for
  unused code, orphaned files, divergent duplicates, drift between
  ROADMAP ticks and actual implementation, and leave a dated audit
  note under `docs/audits/`. If chaos accumulates the game becomes
  unmaintainable — this is non-negotiable hygiene.
- **Friend character icons: image-to-image ONLY. HARD RULE.** Never use
  text-to-image for friend icons — likeness matters. If the user drops
  a photo in chat and you cannot save its bytes to disk (common: chat
  attachments aren't accessible as files in this environment), DO NOT
  fall back to text-to-image. Instead, guide the user to upload the
  photo themselves — either via the `friend-photo` issue template or
  directly into `.github/friend_photos_inbox/<slug>.jpg` using GitHub
  mobile's file upload. Only if you actually have image bytes on disk
  do you commit them to the inbox and let the workflow run img2img.
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
- **Use Claude-native design wherever possible (don't always wait for
  Gemini).** Default to SVG icons, procedural Godot drawing
  (`_draw()`, `CanvasItem.draw_*`), `StyleBoxFlat` chrome, custom
  shaders, and tween/particle choreography written in code. ONLY
  escalate to Gemini/Imagen art-requests for things that genuinely
  need raster painting: character portraits, level backgrounds,
  detailed environmental art. Everything else (UI icons, badges,
  pedestals, frames, dividers, glyph replacements, animation feel,
  palette decisions) — Claude ships directly. No "I'll write a prompt
  and wait for hours" when SVG + GDScript can do it in one commit.
  See `assets/icons/` for the SVG icon library and
  `scripts/systems/design_tokens.gd` for the palette source-of-truth.

## Project Overview
A **landscape** (1280x720) tower defense game built in **Godot 4.6** using GDScript. Set in Migros Affoltern, Zürich. 5 tower characters (Lemurius, Kühne, JoJo, Cordula, Amösius) fight cursed vegan products controlled by De Vegan-Tüüfel. All text in Swiss German. Procedural chiptune music + SFX, AI-generated art, story cutscenes with multi-character paginated dialogue, **10 levels** with 10 waves each (L1 Migros-Eingang → L5 Kasse 3-boss finale → L6 Parkhuus bonus → L7 Dach → L8 Coop-Einbruch → L9 Cumulus-Punkte-Kern → L10 Finale 5-boss gauntlet). `MAX_LEVELS = 10` in `game_manager.gd`. BTD-style branching upgrades (paths A+B, 3 tiers each) with visible tier pips + drag-and-drop placement from a right-anchored collapsible side-shop. Per-level atmospheric particles + CanvasModulate tints + dust-puff steps + animated dashed range circles.

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
  ui/               → MainMenu, LevelSelect, HUD, GameOver, PauseMenu, StoryScreen, OptionsMenu
scenes/
  enemies/          → base_enemy.tscn
  towers/           → base_tower.tscn
  projectiles/      → base_projectile.tscn
  game/             → game.tscn (main gameplay), level_N.tscn (per-level)
  ui/               → main_menu.tscn, level_select.tscn, hud.tscn, etc.
resources/
  enemy_data/       → .tres files per enemy type (basic, fast, tank, healer, flying, swarm, camo, lead, regrow, boss + variants)
  tower_data/       → .tres files per tower (basic=Lemurius, sniper=Kühne, splash=JoJo, cordula, slow=Amösius, farm, support, joe, justus, seve)
  level_data/       → .tres files per level (level_1 .. level_10)
assets/
  textures/         → towers/, enemies/, ui/, maps/, projectiles/
  audio/            → sfx/, music/
```

## Architecture
- **Autoloads** (9, see `project.godot`): `GameManager` (state/save), `CurrencyManager` (gold), `MusicManager`, `SfxManager`, `AutoPlaytest`, `WaveSimulator`, `ProjectilePool`, `EnemyPool`, `EffectPlayer` (combat vfx)
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
- **Friend photos**: Uploaded to `.github/friend_photos_inbox/` (see that README); processed into `assets/textures/towers/`. `GameManager.assign_friend_photo` / `get_friend_photo` map `character_id → texture path`.

## AI Agent Architecture
This project uses a multi-agent workflow. See `AGENTS.md` for full details.

- **Conductor (Sonnet 4.6 default; Opus 4.7 only for novel architecture)** — code, creative, git, user communication. Per the model discipline directive above.
- **Code Scout (Haiku 4.5, on-demand)** — file searches, grep, path validation. Use Haiku — sufficient and 5× cheaper.
- **Build Tester** — `validate.sh` pre-push validation: ext_resource paths, preload paths, autoload existence, signal heuristic, per-script `godot --check-only`, scene-load smoke test.
- **Art Factory (background)** — Stability AI / Imagen 4 image generation, background removal, batch processing.

API keys stored as GitHub repository secrets: `STABILITY_API_KEY`, `GEMINI_API_KEY`, `HUGGINGFACE_API_KEY`, `RESEND_API_KEY`, `BUTLER_API_KEY` (all optional except `CLAUDE_CODE_OAUTH_TOKEN` which the autonomous loop hard-requires).

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
