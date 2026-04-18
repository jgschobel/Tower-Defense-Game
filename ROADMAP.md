# Roadmap — Affoltern Banani Raubzug

The autonomous dev loop reads this file every 6 hours and picks the
highest-priority unchecked item matching the current run mode.

**Priority order**: P0 (blocking) → P1 (important) → P2 (nice-to-have).
Within a priority, top-of-list wins.

---

## 🔥 P0 — Long-Term Retention System (NEWLY ADDED — BTD-grade)

User ask: "Spezial-Münzen, Forschig-Menü, Mission-Challenges per Level,
Difficulty-Modes, extra coole Levels — sodass man nach durchspielen
nicht aufhört". This is the **active, mission-driven** layer that sits
above the passive Cumulus tree below. Two currencies, two trees, two
loops — like BTD6's Cash + Monkey Money + Knowledge.

Ship in this order — each item is a self-contained PR:

### A) Spezial-Münzen Currency

A second currency separate from in-run gold and from passive Cumulus.
Earned only by completing **specific challenges**, not just playing.

- [ ] **`scripts/autoload/spezial_currency.gd`** new singleton, persists
  via `user://spezial.save` JSON (`{ "balance": int, "earned_total": int,
  "history": Array[{source, amount, timestamp}] }`)
- [ ] Display at top of HUD next to gold (small Migros-themed coin icon
  with star). Animated pulse on earn.
- [ ] Earning sources:
  - 5 per mission completed (see B below)
  - 10 per difficulty tier beaten (Hert) per level
  - 25 per difficulty tier beaten (Brutal) per level
  - 50 per first 3-star clear of any level
  - 100 per extra-bonus-level cleared

### B) Mission System per Level

Three missions per level, BTD-style: "Beat with X constraint or do Y
thing". Visible from level-select before starting. Progress tracked
per save. Each completion = 5 Spezial-Münzen + a checkmark icon next
to the level.

- [ ] **`resources/missions/level_N.tres`** per level, schema:
  ```
  missions: Array[{
    id: String,            # "no_amosius", "perfect_run"
    name_de: String,       # "Ohni Amösius gwinne"
    description_de: String,
    type: enum(NO_TOWER_USE, NO_LIFE_LOST, MAX_GOLD_LIMIT, KILL_COUNT,
               TIME_LIMIT, ONLY_TOWER_TYPE, NO_HERO),
    constraint_value: Variant,  # tower id, gold cap, time seconds, etc.
    reward_spezial: int = 5,
  }]
  ```
- [ ] **GameLevel tracks mission state** during run. On level complete,
  evaluates each mission and awards Spezial-Münzen for newly-completed
  ones. Save state.
- [ ] **Level-select UI** shows 3 small mission icons per level
  (locked / available / completed). Tap one before starting → loads
  that constraint into the level.
- [ ] **Initial missions to spec** (autonomous loop fills the rest):
  - Level 1: "Ohni Amösius", "Ohni Läbe verlüre", "Mit max 200 Gold start"
  - Level 2: "Nur Sniper-Türm", "Unter 5 Minute durche", "Ohni Hero"
  - Level 3: "Alli 3 Päd-Tier-3 Upgrades", "Boss überlebe ohni Schade",
    "Mit nur 1 Tower-Typ"

### C) Forschig (Research) Menu

The destination for Spezial-Münzen — a permanent unlock tree that
makes the game DEEPER, not just easier. Three branches:

**Branch 1 — Tower Forschig** (advanced tower modifications)
- [ ] Lemurius: "Doppel-Banane-Wurf" — 25% chance of 2nd banana per
  shot. (50 Münzen)
- [ ] Kühne: "Pollen-Wolke" — sniper hits leave 2s poison cloud at impact
  point. (75 Münzen)
- [ ] JoJo: "Säure-Splash" — splash damage now also slows by 30%.
  (75 Münzen)
- [ ] Cordula: "Volley-Feuerei" — first attack each wave is a triple-shot.
  (50 Münzen)
- [ ] Amösius: "Brennendi Zunge" — slow now also deals DoT 2/sec.
  (75 Münzen)
- [ ] Hero: "Doppel-Banani-Wurf-Cooldown" — ability cooldown -15s.
  (100 Münzen)

**Branch 2 — Krieger-Forschig** (combat advantages)
- [ ] "Schade-Stack +5%" against all enemies. (40 Münzen, repeatable 5×)
- [ ] "Boss-Tüüfel-Hass +15% damage" specifically on boss enemies.
  (60 Münzen)
- [ ] "Krit-Chance 5%" — 5% of all hits do 2× damage. (80 Münzen)
- [ ] "Last-Stand" — at 1 life, all towers fire 30% faster. (100 Münzen)
- [ ] "Pop-Echo" — 10% chance pop spawns a small banana that does 5
  damage to next enemy. (90 Münzen)

**Branch 3 — Wirtschafts-Forschig** (economy)
- [ ] "Cumulus-Vermehrer" — 1.5× Cumulus earn rate. (80 Münzen)
- [ ] "Spezial-Boost" — 1.25× Spezial-Münzen earn rate. (120 Münzen,
  end-game node)
- [ ] "Wave-Rabatt" — between waves, 1 random tower gets -50% upgrade
  cost. (60 Münzen)
- [ ] "Sell-Bonus" — selling refunds 80% instead of 60%. (50 Münzen)
- [ ] "Wave-Skip-Token" — earn 1 token per 5 waves cleared, spend for
  +200g instant. (100 Münzen)

- [ ] **`scenes/ui/forschig_menu.tscn`** — 3-tab menu (Tower/Krieger/
  Wirtschaft), each tab has a node graph with cost/locked-by/owned
  state. Navigated from main menu and pause menu.
- [ ] **`GameManager.apply_forschig_modifiers()`** called on level start —
  reads unlocked nodes and modifies tower data, hero data, currency
  earn rates accordingly.

### D) Difficulty Modes per Level

Each level beatable in 3 modes: **Eifach / Normal / Hert / Brutal**.
Higher difficulties = more enemies, faster speed, fewer starting lives,
but more Spezial-Münzen on clear. Lock progression: must beat Normal
to unlock Hert, etc.

- [ ] Extend `level_data.tres` with arrays:
  ```
  enemy_count_multiplier: Array[float] = [0.7, 1.0, 1.3, 1.7]
  enemy_speed_multiplier: Array[float] = [0.85, 1.0, 1.15, 1.35]
  starting_lives_per_diff: Array[int] = [25, 20, 15, 10]
  spezial_reward_per_diff: Array[int] = [0, 5, 15, 30]
  ```
- [ ] WaveManager + BaseEnemy multiply count/speed by difficulty
  multiplier on spawn.
- [ ] Level-select UI shows 4 difficulty buttons per level, locked icon
  on locked tiers, gold star icon on cleared.
- [ ] Save format extended: `level_clears: { N: { eifach: bool, normal:
  bool, hert: bool, brutal: bool } }`

### E) Extra Bonus Levels (cool maps + special rules)

Unlocked by hitting Spezial-Münzen milestones. These are NOT in the
main story progression — they exist as standalone challenges with
unique mechanics that don't appear in main levels.

- [ ] **"Self-Scan-Hölli"** (unlock at 100 Spezial): 1 wave only, but
  500 enemies all at once. Stress test. Reward: 30 Spezial.
- [ ] **"Banani-Träume"** (200 Spezial): all enemies are Tofu-
  Würschtli, but they're 3× faster. Speedrun map. Reward: 40 Spezial.
- [ ] **"De Tüüfel kommt heim"** (400 Spezial): only the boss, but it
  spawns every 30s for 10 minutes. Tank/sustain test. Reward: 100 Spezial.
- [ ] **"Cumulus-Bingo"** (300 Spezial): random map each play, random
  tower restrictions, random enemy comp. Pure variety mode. Reward:
  20-80 Spezial depending on roll.
- [ ] **"Affoltern bei Nacht"** (500 Spezial): all maps in dark mode
  with limited tower visibility (60% range). Cool aesthetic + skill
  challenge. Reward: 50 Spezial.

Each bonus level has its own .tres + .tscn + entry on a separate
"Bonus" tab in level-select.

### Dependencies + Order Hint

The autonomous loop should ship A and D first (foundation), then B
(uses A), then C (uses A), then E (uses all). Approximate sequence
(7-10 cron build-content runs):

1. Spezial-Münzen currency + display
2. Difficulty modes data + UI
3. Mission system data + per-level evaluation
4. Forschig menu UI shell + Tower-Forschig branch
5. Krieger-Forschig + Wirtschafts-Forschig branches
6-10. Bonus levels one at a time

Sim-gate must run on each — bonus levels especially need balance check.

---

## 🔥 P0 — Game-Identity Levers (NEWLY ADDED — pick these next)

These three are the highest-ROI gameplay additions per BTD design
research. None require new infrastructure. Order them by spec
clarity, not by size.

### A) Hero System (one Friend, one game-changer)

The single biggest design lever. Heroes auto-level mid-round and have
abilities. Pick **Lemurius** as the inaugural hero (matches lore as the
banana-throwing protagonist).

- [ ] **Hero data model**: extend `tower_data.gd` with `is_hero: bool`,
  `hero_max_level: int = 10`, `hero_xp_per_pop: float = 1.0`,
  `hero_ability_cooldown: float = 60.0`, `hero_ability_id: String`.
  Add to a new `resources/tower_data/lemurius_hero.tres` (different from
  `basic.tres` — heroes are their own slot).
- [ ] **One-instance-per-game rule**: `tower_placement.gd` rejects placement
  if any tower with `data.is_hero == true` already exists in the scene.
- [ ] **Mid-round leveling**: `base_tower._on_enemy_killed` adds
  `data.hero_xp_per_pop` to a runtime `hero_xp` field. Crossing thresholds
  `[10, 25, 50, 100, 200, 350, 550, 800, 1100, 1500]` increments
  `hero_level` from 1 to 10. Each level gives +5% damage, +3% range.
  At levels 3, 6, 9 the active ability cooldown reduces by 33%.
- [ ] **Active ability "Banani-Wurf"**: 60s cooldown, single-tap a button
  in HUD, instant 80-damage AoE across entire screen. Visual: rain of
  bananas SVG drops from top, screen-shake 0.3s, gold +50 per pop.
- [ ] **HUD hero panel**: bottom-left widget showing Lemurius portrait, XP
  bar, current level, ability cooldown timer, big tap-to-fire button.
- [ ] **Free purchase first level**: hero costs 0 gold on level 1,
  scaling: 50g L2, 150g L3+. So players see the hero immediately.

Effort: M (single tower mostly, but new UI + new mechanic).
Why: BTD6's biggest retention lever per research; matches Friend-as-Tower
identity perfectly.

### B) The 1% Juice Pass (5 micro-polishes, ship in one PR)

Tiny individually, transformative together. Per Bloons-veteran research:
the difference between "prototype" and "real game" lives here.

- [ ] **Pop SFX pitch by enemy size**: in `sfx_manager.play_death(enemy_data)`
  modulate base sweep frequency by `enemy_data.health` (small enemies =
  higher pitch, big enemies = deep thump). Single line change.
- [ ] **Generous starting cash +50%**: bump `level_data.starting_gold` by
  ~50% across all 3 level data files. Testing playtests already show
  early game is gold-starved.
- [ ] **Tower sprite rotates toward target**: in `base_tower._process` set
  `sprite.rotation = (current_target.global_position - global_position).angle()`
  when targeting, with `lerp` smoothing for snappy feel. Skip if no
  target.
- [ ] **Victory screen 2s hold**: in `game_over.gd` defer score reveal
  by 2s after `level_completed` signal — gives the final pop air time.
- [ ] **+gold floater on EVERY enemy hit (not just kill)**: tiny "+1"
  floater on damage, "+%d" big floater on kill. Existing label
  infrastructure works; just add a smaller variant on damage events
  in `base_enemy.take_damage`.

Effort: S (5 tiny edits, all in known files).
Why: Cheapest dopamine hits in the game. Compounds.

### C) Cumulus Meta-Progression (retention hook)

Loyalty-points-style permanent tree. Every failed run earns Cumulus,
spend on permanent buffs that stack across all future runs.

- [ ] **Save format**: `user://cumulus.save` JSON with
  `{ "balance": int, "unlocked_nodes": Array[String] }`.
  GameManager loads on `_ready`, saves on `complete_level` and
  `lose_life` (when run ends).
- [ ] **Earning rule**: 1 Cumulus per enemy killed, 50 bonus per level
  WON, 10 per level LOST. Show running total on game-over screen.
- [ ] **15 nodes (Migros-themed)**:
  1. `start_gold_50`: +50g start (cost 100 Cumulus)
  2. `start_gold_100`: +100g start (200, requires #1)
  3. `extra_life`: +1 life per level (300)
  4. `extra_life_2`: +1 more life (500, requires #3)
  5. `tower_discount_5`: -5% all tower costs (200)
  6. `tower_discount_10`: -10% all tower costs (400, requires #5)
  7. `faster_waves`: -25% time between waves (300)
  8. `pop_bonus_gold`: +1 gold per pop (200)
  9. `lemurius_speed`: Lemurius +10% attack speed (250)
  10. `kuhne_range`: Kühne +15% range (250)
  11. `jojo_splash`: JoJo splash radius +20% (250)
  12. `cordula_dmg`: Cordula +10% damage (250)
  13. `amosius_slow`: Amösius slow +0.5s (250)
  14. `hero_start_lvl_2`: Hero starts at level 2 (500, requires hero shipped)
  15. `cumulus_double`: 2× Cumulus earn rate (1000, requires 5+ other nodes)
- [ ] **UI**: new `scenes/ui/cumulus_shop.tscn` accessible from main menu
  ("Cumulus-Punkt"), grid of 15 nodes with cost/locked indicator/buy
  button. Use existing PanelContainer style.
- [ ] **Apply at level start**: `GameManager.start_level()` reads unlocked
  nodes and modifies `max_lives`, `CurrencyManager.gold`, applies
  per-tower stat bonuses to that level's tower data via temp overrides.

Effort: M-L (new scene, save format, application logic).
Why: Per BTD6 research, meta-progression is the #1 long-term retention
driver. Every failed run becomes progress. Strategically more important
than 5 more levels because it fixes "why play again" not "what to play".

## 🔥 P0 — Blocking / Bugs

- [x] Fix JoJo splash tower `can_target_flying = true` (PLAN #12)
- [ ] DamageType enum actually applied in base_enemy.gd (magic ignores armor, physical reduced by armor) — PLAN #16
- [x] Show feedback text on invalid tower placement ("Z'nöch am Wäg!" / "Z'nöch am Turm!") — PLAN #24
- [x] Tower cost affordability color (yellow/gold affordable, red unaffordable) — PLAN #28
- [x] Floating `+gold` labels don't disappear when monster dies (tween was self-bound to freed enemy)
- [x] Death SFX was grating noise burst — replaced with soft 180→70Hz sweep at 0.15 volume
- [ ] Story screen rework — multi-page dialogue boxes instead of one cramped panel. User reports text is too small to read and skips show immediately. Bloons/Monaco-style typewriter across 3-5 pages with big tap-to-advance buttons. Swiss German content unchanged, presentation rebuilt.
- [ ] **Options menu** (music volume, SFX volume, master volume) accessible from main menu AND pause menu. Use AudioServer buses: add "Music" and "SFX" buses, route MusicManager/SfxManager players through them, expose sliders that call `AudioServer.set_bus_volume_db`.
- [ ] Enemy pathing bug: at level 2+, enemies stack up at spawn in a long vertical line before moving. Visible in screenshot — 10+ tofu-würschtli piled on top of each other at the top-left corner. Likely a spawn cadence/path-follow issue in `wave_manager.gd` or `base_enemy.gd`.

## 🎨 P0 — Map Backgrounds (each level needs real personality)

The current level backgrounds are a single static image that feels flat.
Each level should have: a bespoke parallax layer, thematic foreground
props, ambient particles, and time-of-day atmosphere. Use `generate-art`
mode to produce tier-2 quality assets; wire them in during `build-content`.

- [ ] **Level 1 — Migros Affoltern Eingang**: parallax sliding-doors,
  shopping carts in background, self-scan area props, midday bright
  neon-fluorescent lighting, Migros-orange color accents.
- [ ] **Level 2 — D'Tiefchüel-Abteilig (Freezer Aisle)**: dripping
  icicles (animated), frost-fog particle layer, vertical freezer doors
  as parallax columns, cold blue lighting, occasional breath-mist from
  towers.
- [ ] **Level 3 — D'Bäckerei vom Gruse**: warm oven glow, flour
  particle drift, baguette/gipfeli props, warm amber lighting, bread
  racks in background.
- [ ] Level 4+ pending — see Content section. Each needs the same
  bespoke treatment: props, parallax, particles, lighting.

## 🔥 P0 — The Big Feature: Bloons-TD-5-style branching upgrades

The single biggest gap to Bloons TD. Each tower should have **two upgrade
paths**, visually distinct at each tier, with meaningfully different
mechanics. This is the core progression loop of BTD. Attack as a multi-
run project:

- [ ] **Data model**: extend `tower_data.gd` with `upgrade_path_a` and
  `upgrade_path_b` arrays (each has 3 tiers), plus `current_path_a_tier`
  and `current_path_b_tier` runtime state per tower. Max 2/0 or 0/2 per
  tier rule (one path must stay at tier 2 before the other can reach 3).
- [ ] **UI**: tower info panel shows two upgrade columns instead of one
  linear button. Icons + cost + Swiss German name per tier.
- [ ] **Visual feedback**: tower texture swaps per tier (use
  `generate-art` mode to produce tier-2 and tier-3 variants for each
  character; while art is pending, tint/outline/particle effects
  indicate tier).
- [ ] **Lemurius paths**: Schnelli Banane (attack speed) vs. Scharfi Banane
  (damage) → tier-3 merger: Explosivi Khaki (AoE bomb)
- [ ] **Kühne paths**: Giftige Pollen (poison DoT) vs. Iis-Blüete (freeze)
  → Füür-Lilie (AoE fire over time)
- [ ] **JoJo paths**: Stärcheri Formel (damage) vs. Chaos-Chemie
  (random effects) → Lotter JoJo (random legendary)
- [ ] **Cordula paths**: Volleyball Hagel (multi-shot) vs. Ankerhake
  (stun) → Party Kanone (massive AoE)
- [ ] **Amösius paths**: Längeri Zunge (range) vs. Chläbrigeri Zunge
  (stronger slow) → Insta-Reel Attacke (pull-and-hold)

## ⚡ P1 — Important (Polish & UX)

- [ ] Enemy count on HUD ("12 übrig" next to wave counter) — PLAN #26
- [ ] Tower range preview stat in shop buttons — PLAN #29
- [ ] Reposition tower info panel so it doesn't overlap map — PLAN #30
- [ ] HUD buttons ≥ 50px for mobile touch — PLAN #34
- [ ] Pause button 60px minimum — PLAN #35
- [ ] Safe area margins for notches/status bars — PLAN #36
- [x] Health bar smooth tween over 0.2s — PLAN #41
- [ ] Screen shake on boss spawn (level 3 wave 10) — PLAN #42
- [ ] Wave start announcement flies across screen — PLAN #43
- [ ] UI click SFX wired to every button press — PLAN #52
- [ ] Boss entrance SFX (low rumble) — PLAN #54
- [ ] Tutorial overlay for first-time play — PLAN #27
- [ ] Level select background uses levelselect_bg.png — PLAN #31
- [ ] Story screen: small centered portraits, dark overlay — PLAN #32
- [ ] Main menu buttons: panel behind buttons over artwork — PLAN #33
- [ ] Proper star icons instead of `*`/`-` characters — PLAN #70

## 🎮 P1 — New Content

- [ ] Level 4 data + scene + story intro (D'Kasse — cash register chaos)
- [ ] Level 5 data + scene + story intro (D'Lager — warehouse descent)
- [ ] Level 6 data + scene + story intro (D'Parkhuus)
- [ ] Level 7 data + scene + story intro (D'Dach — rooftop showdown)
- [ ] Level 8 data + scene + story intro (D'Chüelraum — deep freeze)
- [ ] Level 9 data + scene + story intro (D'Zentrale — HQ infiltration)
- [ ] Level 10 data + scene + story intro (Final: De Vegan-Tüüfel's Throne)
- [ ] Endless mode after Level 10 — PLAN #76
- [ ] Katzensee level using saved photo reference — PLAN #61
- [ ] Migros entrance level using saved photo reference — PLAN #62

## 🚀 Master-Plan Phase 3 — Deferred (too invasive for blind ship)

- [ ] **3-tier → 5-tier upgrade system** (BTD-standard with crosspath
  exclusion at tier 3+5). Touches every tower, every UI button, save
  format. Recommended path: `ideate` cron drafts the migration plan
  one tower at a time, then `build-content` cron ships per-tower.
  Requires playtest verification at each step. The wave-balance
  simulator (`sim-gate.yml`) catches regressions automatically.

## 🧪 P2 — Branching Upgrades (PLAN #72) — SHIPPED in PRs #20, #31

- [x] Lemurius: Schnelli Banane vs Scharfi Banane → Explosivi Khaki
- [x] Amösius: Längeri Zunge vs Chläbrigeri Zunge → Insta-Reel Attacke
- [x] Kühne: Giftige Pollen vs Iis-Blüete → Füür-Lilie
- [x] JoJo: Stärcheri Formel vs Chaos-Chemie → Lotter JoJo
- [x] Cordula: Volleyball Hagel vs Ankerhake → Party Kanone
- [ ] Lotter JoJo random effects — PLAN #73

## 🏎 P2 — Performance

- [ ] Object pooling for projectiles — PLAN #63
- [ ] Object pooling for enemies — PLAN #64
- [ ] Viewport scaling across phone sizes — PLAN #66
- [ ] Battery optimization: stop music gen when backgrounded — PLAN #67

## 🔥 P0 — Creative Upgrade Pipeline (Live Feedback)

User: upgrades must be visually + mechanically creative, not just stat
bumps. Each tier must look different; projectiles must evolve.

- [ ] **Per-tier tower texture variants**: use Nano Banana img2img with
  existing tower PNG as source. Generate 2 extra variants per path per
  tower (tier 1, tier 2, plus tier 3 "ultimate" bigger change). Save as
  `assets/textures/towers/<id>_A1.png`, `_A2.png`, `_A3.png`,
  `_B1.png` etc. TowerData arrays: `path_a_textures`, `path_b_textures`.
  base_tower._update_visual() picks the highest-tier texture per path
  that matches current state (when A3 reached, use A3 over A2).
  Total assets: 5 towers × 6 tier variants = 30 new PNGs via the
  generate-art cron.
- [ ] **Per-tier projectile animations**: base_projectile.gd grows a
  `style: String` parameter (`banana`, `banana_sharp`, `banana_bomb`,
  `pollen_cloud`, `ice_shard`, `chaos_bubble`, etc). Each style has a
  dedicated Sprite2D or shader effect. Tower hands `data.path_a_tier`
  or `data.path_b_tier` to `launch_projectile()` so the visual matches.
- [ ] **Upgrade-button icons in tower info panel**: tiny PNG per tier
  name. Imagen 4 generate-background with 1:1 aspect, 64×64 output,
  matching tower tint. Wire into hud._style_path_button().
- [ ] **Side-widget tower selection**: replace the full-width bottom
  bar with a collapsible widget on the RIGHT edge of the screen. Five
  small circular avatar buttons, expand on tap to show cost + range,
  stays out of map center. hud.tscn rearrange: move TowerShop to an
  anchored right-side VBoxContainer, shrink per-button size, add
  "pull-tab" to collapse.
- [ ] **Maps still boring — second pass**: Imagen 4 generate richer
  Level 1/2/3 backgrounds with more detail (shelves, products, Swiss
  supermarket atmosphere). Plus animated overlays per level: ice
  particles for L2, flour drift for L3, fluorescent flicker for L1.
  Current backgrounds are "screenshot of supermarket", user wants
  "tower defense-ready stylized painting".

## 🔥 P0 — Just Added (Latest Live Feedback)

- [ ] **Empty space left/right in landscape**: partially fixed by setting
  `window/stretch/aspect=expand`. Follow-up: audit every scene to ensure
  root Controls use PRESET_FULL_RECT with anchors (not fixed positions)
  so layout flexes on 20:9 phones. Biggest offenders: game.tscn +
  level_N.tscn map nodes which may still assume 1280×720.
- [ ] **Compact tower shop**: current bottom bar takes too much vertical
  space and is always visible → distracting. Redesign: small circular
  "+" FAB in bottom-right opens a radial/popup picker with the 5 tower
  icons. Stays out of the way until player wants to place.
  Alternative: collapse bar to a thin handle when no tower selected,
  expands on tap.
- [ ] **Richer maps — each level gets bespoke visual identity**:
  - Level 1 Migros Eingang: animated auto-doors sliding, shopping-cart
    props, Migros-orange accent color, fluorescent neon flicker shader
    overlay
  - Level 2 Tiefchüel: dripping icicles (particle system), frost-mist
    layer with blue tint post-processing, breath-fog when towers fire
  - Level 3 Bäckerei: warm oven glow, drifting flour particles, amber
    light gradient, heat-haze shader on path
  Use Imagen 4 text-to-image (`generate_background` helper) for richer
  static backgrounds; use Godot CPUParticles2D + CanvasModulate for
  the animated layers.

## 🔥 P0 — Live Gameplay Feedback (earlier)

- [ ] **First-appearance monster intro animation** — when a new enemy type
  spawns for the first time in a level (not every wave), trigger a
  brief animated reveal: enemy zooms in at 2× scale from bottom
  center, portrait slides in with name label and short Swiss German
  taunt in speech bubble, music ducks briefly, then enemy flies to
  path start. 2s total. Track `seen_enemies: Array[String]` in
  `wave_manager.gd`; fire `enemy_introduced(enemy_id, data)` signal
  first time each id appears. HUD listens and plays animation.
- [ ] **Better music** — current procedural chiptune is "cheap".
  Upgrade `music_manager.gd`:
  - Add drum pattern (kick + snare + hi-hat procedural)
  - Vary melody + bass per level (Level 1 happy, Level 2 dark/cold,
    Level 3 fast/urgent, boss wave dramatic minor key)
  - Smooth between sections instead of hard loops
  - Lower master volume by default; users can bump via options

## 💡 Ideas To Explore (Proactively Generated)

- [ ] **Active Powers** (BTD5 "agents" / "abilities") — 3 single-use
  items purchased with gold, with per-game cooldowns:
  - **Banana-Räge**: drops +500 gold immediately (cost 300g, 120s cd)
  - **Gfrüüri-Puls**: freezes all enemies on screen for 3s (cost 200g, 90s cd)
  - **Gipfeli-Airstrike**: spawn a 150-damage AoE blast at tapped position (cost 250g, 60s cd)
  Icon row above the tower shop, tap to arm, tap target to fire.
- [ ] **Adjacency synergies** — towers placed within 100px of certain
  other towers get a visual glow + stat boost:
  - Lemurius + Kühne: Lemurius bananas deal +20% damage (nature theme)
  - Amösius + JoJo: Amösius slow applies an extra 1s (sticky acid)
  - Cordula + Kühne: Cordula attack speed +15% (pirate flower crew)
  Shown as a faint gold line between synergy pairs.
- [ ] **Combo multiplier** — rapid kills (within 2s of each other)
  build a combo counter. x1.5 gold at 5 combo, x2 at 10, x3 at 20.
  On-screen streak badge top-center, fades when broken.
- [ ] **Leaderboard/ghosts** — record player's best run per level (wave
  reached, time, gold earned). Compare to best ever. "Deini beschti
  Runde" panel on level select.
- [ ] **Daily challenge** — one seeded level per day with modifiers
  (no Kühne, double enemy speed, etc.). Shared seed so every player
  worldwide gets the same challenge — basis for future leaderboard.

## 💡 Ideate 2026-04-18 — Swiss-German Spectacle & Retention Hooks

Five concrete ideas from today's ideate run. Each has a spec, a Swiss
German name, and a rough implementation hint so the next `build-content`
or `feature` run can pick it up without re-designing.

- [ ] **Migros-Cumulus meta-progression** — persistent loyalty points
  earned across runs (1 Cumulus per 100 gold banked at level-end, +50
  for a perfect no-life-lost clear). Spend in a "Cumulus-Laade" shop on
  permanent account-wide boosts: *Start-Bonus* (+50g start, 200 Cml),
  *Extra Läbe* (+1 starting life, 400 Cml), *Rabatt-Charte* (-10% tower
  cost, 600 Cml, capped 3 stacks), *Express-Kasse* (waves start 20%
  faster, 500 Cml). Save to `user://cumulus.save` via GameManager.
  Shop button on main_menu + post-level summary shows Cml earned. This
  is the *hurts-to-remove* retention hook — ties Migros theme directly
  to progression, not in BTD.
- [ ] **"De Chef!" finisher (boss-only cameo slayer)** — when a boss's
  HP drops below 10%, a Migros-orange **"DE CHEF CHUNT!"** button
  flashes top-center for 4s. Tap to spawn a cameo slayer (Michi /
  optional user-photo) who arcs across screen with a Migros-Budget
  hammer, screen-shakes on impact, instant-kills the boss and awards
  +300g bonus. One use per boss fight. Implementation: new
  `systems/finisher.gd` autoload listens to enemy health; HUD shows
  button; on tap, play a 1.2s Tween on a Sprite2D across the viewport +
  screenshake + a sharp chiptune sting. Screenshot-worthy moment,
  fulfils "viral TikTok" brief.
- [ ] **Rausch-Modus (frenzy combo)** — kill streaks within 2.5s of each
  other build a combo counter. At 10 combo trigger **"RUUSCH!"**:
  0.25s slow-mo zoom (Engine.time_scale = 0.4 tweened back to 1.0),
  golden vignette overlay, +2× damage for 3s, +1.5× gold for the next
  5 kills. Badge top-center ("x12 Rausch · 3.1s"). Extends existing
  "combo multiplier" idea with concrete numbers + spectacle. Hook
  into `base_enemy.enemy_died` from a new `systems/combo_tracker.gd`
  autoload.
- [ ] **Züri-Tram MOAB-boss ("De 11er Tram vom Tüüfel")** — Line 11
  Zürich-tram-shaped mega-boss for Level 10 / endless, VBZ-blue long
  sprite (3× width of normal enemies), 12000 HP, move_speed 0.4×,
  immune to slow. On death splits into 3 individual tram-carriages
  (2000 HP each, normal speed) that keep advancing. 1500g total
  reward. New `enemy_data/tram_11.tres` + `enemy_data/tram_carriage.tres`
  + boolean `splits_on_death: Array[String]` (enemy ids) field on
  EnemyData. Thematic Swiss spectacle — BTD has MOABs, we have trams.
- [ ] **Wagli-Räge active power (Shopping-Cart Rain)** — slots into the
  P0 "Active Powers" row. Cost 250g, 75s cooldown, 1 charge per level.
  On fire: 5 runaway Migros shopping carts spawn off-screen-top and
  roll diagonally across the play area over 1.5s, each dealing 60
  physical damage to every enemy they touch (pierce). CPUParticles2D
  for debris + cart Sprite2Ds tweened on straight-line paths. Icon:
  small chrome-cart PNG via Imagen 4. Satisfies the "laziest player
  fantasy" of solving a wave with one tap and is specific to this
  setting in a way BTD's bomb-drop isn't.

## 💡 Legacy Ideas

*Added by the `ideate` mode runs. The loop mines this section for bigger
creative swings. Lift to P1 when ready to ship.*

- [ ] **Glace-Schlag tower** — Migros ice-cream themed, freezes all
  enemies in 200px radius for 3s, 15s cooldown, 400 gold.
- [ ] **MOAB-class boss: "De Grossi Coop-Güggel"** — rival supermarket
  mega-boss in Level 10 / endless, 8000 HP, spawns 4 soja_steak on death,
  gives 800 gold.
- [ ] **Camo enemies** (invisible unless a sniper tower is within range)
  — thematic fit: "Schatte-Tofu", sneaky ninja tofu.
- [ ] **Combo multiplier** — rapid kills within 2s build a combo that
  gives bonus gold and a tiny UI streak counter.
- [ ] **Sandbox mode** — unlimited gold, unlock all towers, any level,
  for experimenting. One extra button on level-select.

## 🔎 Architecture Notes

*Observations added during ideate runs, useful for future refactors.*

- **2026-04-18 — Spawn stacking root cause (ties to P0 "enemies stack up
  at spawn" bug).** `scripts/systems/wave_manager.gd` `_build_spawn_queue`
  flattens every `count` in a group into individual queue entries but
  reads `delay` from the *same* group dict — so if a wave defines
  `{enemy_id: "tofu_wuerschtli", count: 12, spawn_delay: 0.3}`, all 12
  spawn 0.3s apart and each enters `enemy_path` at `progress = 0`. With
  a tofu sprite ~64px tall, the first ~3s of spawning visually stacks
  10+ enemies at the start of the path. Fix direction: either (a) give
  each newly-spawned `PathFollow2D` a tiny negative `progress` offset
  based on its index (e.g. `-0.2 * i * move_speed`) so they start
  staggered behind the spawn point, or (b) raise the per-group minimum
  `spawn_delay` floor from 0.3s to ~0.6s for slower enemies. (a) is the
  cleaner fix; (b) is the one-line safety net. Do both — cap and
  stagger — and the visual stacking disappears without changing wave
  difficulty.
- **2026-04-18 — Reprioritization note.** Leaving P0 ordering as-is.
  The **spawn-stacking bug** and **story screen rework** are the two
  most visible issues in screenshots; next `fix` mode should take the
  spawn bug (now that the root cause is documented above) before
  anything else. Branching-upgrades work already has Lemurius shipped
  (PR #20) + 4 other towers in PR #31 — mark the P0 branching header
  as "in-progress, per-tower tickets still open" rather than bumping.

## 🎯 P2 — Polish & Extras

- [ ] Upgrade visual path (tint/glow per upgrade level) — PLAN #22
- [ ] Enemy preview icons in story (actual sprites) — PLAN #69
- [ ] Custom app icon featuring Lemurius & Amösius — PLAN #71
- [ ] Android export preset — PLAN #74
- [ ] HTML5 web export — PLAN #75
- [ ] Achievement system — PLAN #78
- [ ] Daily challenge — PLAN #79
- [ ] Leaderboard — PLAN #80
- [ ] Friend photo gallery view — PLAN #77

---

## For the Autonomous Loop

**When you complete an item**: tick the box `[x]`, add one line to
`CHANGELOG.md`, and commit both changes with your PR.

**When you add a new idea**: drop it under the right priority bucket with
a clear one-liner. Link to any related PLAN.md item number if relevant.

**When nothing fits today's mode**: do a tiny polish PR (a typo, a
constant rename for clarity, a missing type annotation). Never open an
empty PR.
