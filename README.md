# Affoltern Banani Raubzug

A mobile tower defense game built in Godot 4.6 set in Migros Affoltern, Zürich. Lemurius, Amösius, Kühne, JoJo, and Cordula fight cursed vegan supermarket products controlled by Der M-Tüüfel. All text in Swiss German (Züridütsch).

## Development
- Built with AI-assisted workflow: Opus (architecture/code) + Sonnet sub-agents (art generation, validation)
- Art generated via Stability AI API, backgrounds removed with rembg
- See `AGENTS.md` for the multi-agent architecture
- See `PLAN.md` for the full development roadmap
- See `CLAUDE.md` for coding conventions and project structure

## What's Done

### Core Systems
- **GameManager** (autoload) — game state machine, level progression (10 levels), 1-3 star ratings, save/load to JSON
- **CurrencyManager** (autoload) — gold economy with per-level starting gold, earn from kills, spend on towers

### 5 Tower Types
| ID | Name | Cost | Role |
|----|------|------|------|
| basic | Shooter | 100 | All-rounder, balanced stats |
| sniper | Sniper | 200 | High damage, long range, slow fire |
| splash | Bomber | 175 | AoE damage, good vs groups |
| slow | Freezer | 120 | Slows enemies by 40% |
| support | DJ Booth | 250 | Buffs nearby towers (+20% dmg, +15% speed) |

Each tower has 3 upgrade tiers with increasing damage, range, and speed.

### 6 Enemy Types
| ID | Name | HP | Speed | Special |
|----|------|----|-------|---------|
| basic | Grunt | 100 | 80 | — |
| fast | Sprinter | 60 | 160 | Fast, low HP |
| tank | Beefy Boy | 400 | 45 | Armored |
| healer | Medic | 120 | 70 | Heals nearby enemies |
| flying | Drone | 80 | 110 | Some towers can't target |
| boss | The Big One | 2000 | 35 | Armored, spawns 4 grunts on death |

### 3 Levels Defined
1. **The Meadow** — 5 waves, beginner
2. **Sandy Crossing** — 6 waves, introduces healers
3. **Dark Forest** — 7 waves, flying enemies + boss fight

### UI Screens
- Main menu → Level select (with star ratings + lock icons) → Gameplay HUD → Victory/Defeat popup
- Pause menu with resume/restart/quit
- Game speed toggle (1x/2x/3x)
- Tower shop bar at bottom of screen

### Friend Photo System
- Assign any photo from your device to any tower or enemy character
- Photos auto-resize to 256x256 and persist across sessions

## What Needs to Be Done Next

### High Priority
- [ ] **Draw enemy paths** — open each level scene in Godot, select `EnemyPath`, draw a Curve2D across the map
- [ ] **Add physics bodies to enemies** — enemies need `CharacterBody2D` or `StaticBody2D` to trigger tower detection areas (currently `PathFollow2D` only)
- [ ] **Add sprite textures** — currently using Godot's default icon; create or import proper tower/enemy sprites
- [ ] **Test and balance** — play through all 3 levels, tune HP/damage/gold values

### Medium Priority
- [ ] **Build level maps** — add TileMapLayer backgrounds for each level (grass, desert, forest themes)
- [ ] **Add levels 4-10** — create .tres files in `resources/level_data/` with wave definitions
- [ ] **Tower selection UI** — tap a placed tower to see stats, upgrade, or sell (TowerInfoPanel script exists but needs wiring)
- [ ] **Settings screen** — sound/music volume, friend photo manager access from main menu
- [ ] **Sound effects** — place audio files in `assets/audio/sfx/` (shoot, hit, die, place tower, wave start)
- [ ] **Music** — background tracks in `assets/audio/music/`

### Low Priority
- [ ] **Animations** — tower attack animations, enemy walk cycles
- [ ] **Particle effects** — explosions for splash tower, frost for freezer, death poof
- [ ] **Tutorial level** — guided first-time experience
- [ ] **Mobile export** — configure Android/iOS export templates
- [ ] **Leaderboards / achievements** — optional stretch goal
