# Affoltern Banani Raubzug — Development Plan

## Workflow
Tasks are executed using the agent architecture defined in `AGENTS.md`:
- **Conductor (Opus)** handles bug fixes, game logic, creative decisions
- **Art Factory (Sonnet)** runs image generation in background while Conductor codes
- **Code Scout (Sonnet)** explores codebase when Conductor needs info
- **Build Tester (Sonnet)** validates everything before git push

## Critical Bugs (Must Fix First)

- [ ] **All levels play as Level 1** — `game.tscn` hardcodes `level_id = 1`. Need to read from `GameManager.current_level` in `_ready()`
- [ ] **Boss spawn_children() is empty** — Der M-Teufel should spawn 4 Brötli on death, currently does nothing
- [ ] **Starting gold/lives ignored from LevelData** — CurrencyManager uses hardcoded dict instead of .tres values
- [ ] **Splash projectile vanishes if target dies mid-flight** — should continue to position and explode
- [ ] **DJ Booth buff is stale** — buff only calculated on placement, not when nearby towers change
- [ ] **Game speed not reset on menu return** — add `Engine.time_scale = 1.0` safety net in MainMenu._ready()
- [ ] **Level star JSON key mismatch** — int vs string keys after save/load round-trip

## Gameplay Balance

- [ ] **Nerf Amösius** — reduce from 25 dmg/2.0 atk/75% slow 4s to 15 dmg/1.0 atk (keep slow, reduce DPS)
- [ ] **Buff Bomber** — increase splash radius 60→80 or reduce cost 175→150
- [ ] **DJ Booth recalculation** — trigger `_recalculate_stats()` on all towers when any tower placed/sold
- [ ] **Economy review** — fix starting gold from LevelData (250/300/350 instead of 200/250/300)

## Visual & Art Tasks

### Tower Art (need images for each)
- [x] Lemurius — has custom art (lemur character)
- [x] Amösius — has custom art (gecko character)
- [ ] **Sniper tower** — needs character art (currently colored square)
- [ ] **Bomber tower** — needs character art
- [ ] **DJ Booth tower** — needs character art

### Enemy Art (currently drawn as shapes, need proper sprites)
- [ ] **Angry Brötli** — bread roll with angry face
- [ ] **Turbo Toblerone** — triangular chocolate bar running
- [ ] **Beefy Cervelat** — giant Swiss sausage with armor
- [ ] **Dr. Rivella** — healing bottle with a stethoscope
- [ ] **Fliegende Fondue** — flying cheese pot
- [ ] **Der M-Teufel** — the Migros devil boss (big, scary, orange M logo)

### UI Art
- [ ] **App icon** — Lemurius & Amösius with bananas
- [ ] **Banana currency icon** — replace money.png with banana
- [ ] **Star icons** — proper stars for victory screen
- [ ] **Level thumbnails** — small preview images for level select

### Map Backgrounds
- [ ] **Level 1: Migros Affoltern** — supermarket floor tiles, shelves
- [ ] **Level 2: Frozen Section** — ice blue floor, freezer cabinets
- [ ] **Level 3: Bakery of Horrors** — warm wood floor, oven glow

### Effects & Particles
- [ ] Banana splat on projectile hit
- [ ] Cheese drip from Fondue enemies
- [ ] Sparkle on tower placement
- [ ] Explosion for Bomber splash
- [ ] Death poof when enemies die

## UI Improvements

- [ ] **Floating gold text** — "+10" on enemy kill
- [ ] **Enemy count display** — "12 enemies remaining" on HUD
- [ ] **Tower DPS in info panel** — show calculated DPS alongside raw stats
- [ ] **Wave preview** — show what enemies are coming next
- [ ] **Banana currency label** — use banana icon instead of money icon
- [ ] **Lore-flavored victory** — "Your banana discount is SAFE!" etc.
- [ ] **Tower shop scrollable** — wrap in ScrollContainer for more towers
- [ ] **Bigger tap zones on mobile** — 50px → 70-80px for tower selection

## Content Expansion

### Levels 4-10
| Level | Name | Theme | New Mechanic |
|-------|------|-------|-------------|
| 4 | The Cheese Counter | Raclette zone | Shield enemies |
| 5 | The Drink Aisle | Bottles everywhere | Split path |
| 6 | The Self-Checkout | Beeping machines | Fast lane (second shorter path) |
| 7 | The Warehouse | Behind-the-scenes | Boss: Mega Cervelat |
| 8 | The Parking Garage | Underground | Dark map, limited visibility |
| 9 | Cumulus Points Vault | M-Teufel's lair | All enemy types, heavy waves |
| 10 | Der M-Teufel's Throne | Final battle | Multi-phase boss |

### New Tower Ideas
- [ ] **Cumulus Cannon** — fires expired Cumulus cards, bonus damage to bosses
- [ ] **Migros Bag Launcher** — AoE pushback, swings reusable bags
- [ ] **Käserei (Cheese Station)** — creates slow zone puddle instead of targeting

### New Enemy Ideas
- [ ] **Frozen Pizza Frisbee** — fast, deflects some projectiles
- [ ] **Kamikaze Gipfeli** — flies to nearest tower and explodes (tower HP mechanic)
- [ ] **Shopping Cart** — slow, armored, carries 3 smaller enemies inside

## Per-Level Scenes
- [ ] Create `level_2.tscn` — unique ice-blue path, frozen section background
- [ ] Create `level_3.tscn` — unique bakery path, warm brown background
- [ ] Each level needs unique Curve2D, Line2D, and background

## Mobile Readiness

- [ ] Improve placement UX: place on finger-release, not finger-down
- [ ] Increase tower tap zones to 70-80px
- [ ] Add safe area margins for notches/status bars
- [ ] Test procedural music performance on low-end devices
- [ ] Replace FileDialog with native gallery picker for friend photos
- [ ] Create proper app icon
- [ ] Configure Android export template
- [ ] Build and test APK on Samsung Galaxy

## Testing Checklist

### Core Loop
- [ ] Menu → Level Select → Story → Game (full flow)
- [ ] Level 2 loads correct waves (not level 1's)
- [ ] Place tower, gold decreases
- [ ] Towers shoot, enemies lose HP
- [ ] Amösius stun: blue tint, slow, reaction text
- [ ] Enemy reaches end → lose life
- [ ] 0 lives → defeat screen
- [ ] All waves cleared → victory with stars
- [ ] Retry/Next level buttons work

### Towers
- [ ] Can't place on path
- [ ] Can't overlap towers
- [ ] Cancel placement
- [ ] Upgrade increases stats
- [ ] Sell returns 60% gold
- [ ] Sniper targets strongest
- [ ] Bomber splash hits group
- [ ] Bomber ignores flying
- [ ] DJ Booth buffs neighbors
- [ ] Tower info on tap
- [ ] Deselect on empty tap

### Enemies
- [ ] Boss spawns 4 Brötli on death
- [ ] Healer heals nearby
- [ ] Flying ignored by Bomber
- [ ] Boss bigger than normals
- [ ] Hit reaction text on stun
- [ ] Health bar on damage

### Save/Load
- [ ] Stars persist across sessions
- [ ] Level unlock persists
- [ ] Stars only improve, never decrease
