# Roadmap — Affoltern Banani Raubzug

The autonomous dev loop reads this file every 6 hours and picks the
highest-priority unchecked item matching the current run mode.

**Priority order**: P0 (blocking) → P1 (important) → P2 (nice-to-have).
Within a priority, top-of-list wins.

---

## 📋 Autonomous Loop — overnight work queue (user asleep 2026-04-18 22:00Z)

Priority for the 6-hour loop while user sleeps. Pick one, ship it, auto-merge:

1. **Level 4 content** — `resources/level_data/level_4.tres` + `scenes/game/level_4.tscn` (reuse level_3.tscn as base, new path, 10 waves escalating from tank+basic mix through flying+boss). Include new Lore entry in `scripts/systems/lore.gd`. Unlock via GameManager level progression.
2. **Strike animations** — particles/muzzle flash on tower attack + impact effects on projectile hit. `scenes/effects/muzzle_flash.tscn` + `scenes/effects/impact_spark.tscn`. Spawn via `base_tower._attack` and `base_projectile._hit`. Keeps the 4× time_scale playtest running smooth (CPU-cheap particle2D).
3. **Price-popup edge-fix** — the tower-info panel anchor math for towers placed far right/left of screen. Clamp `tower_info.offset_left/right` within viewport bounds.
4. **Design polish P1** — `docs/design_polish.md` spec: replace "teenager garage" look with pro art brief (color palette, shadow/highlight rules, typography tokens). No code, just spec so subsequent PRs follow consistent direction.
5. **PAT-based user-attachment fetch** — in `photo_to_character.py`, try `USER_ATTACHMENT_PAT` secret before `GITHUB_TOKEN`. If PAT set and valid, 404 would go away. Add docs on how to create the PAT. Optional — user needs to set the secret.
6. **More levels** — level_5 through level_10 stubbed out with progressively harder wave defs. Even stub resources make the level-select feel full.

**Circuit breaker**: 25 merges / 24h, 4 Opus 4.7 runs / 5h. Don't exceed. If rate-limited, stop and log to `docs/observability/ledger.md`.

**Do NOT do**: anything requiring user input. No new issue-template changes, no secrets, no PR reviews. Auto-merge everything validated by sim-gate + playtest.

---

## ✅ Shipped 2026-04-18 evening — wrap-up session

- **Crash/freeze on first attack** (PR #68) — pool stale-ref elimination in both ProjectilePool and EnemyPool; `acquire()` skips invalid slots; projectile invalid-target now routes through `release()` instead of `queue_free`
- **Blurry-empty-text-box fix** (PR #68) — `reset_for_pool` cleans orphaned Label children (damage numbers / hit reactions that outlived their tweens); persistent enemy name labels removed entirely since intro overlay covers naming
- **Photo pipeline root-cause documented** (PR #68) — `github.com/user-attachments/assets/*` URLs return 404 to workflow clients; inbox is now the canonical path; README rewritten with mobile walkthrough; failure comment on issue links to inbox
- **Per-tower projectiles** (PR #66) — Lemurius bananas, Cordula volleyball, JoJo flask, Kühne pollen, Amösius tongue-from-mouth; per-style `_draw()` + style refresh on pool reuse
- **JoJo acid pool** (PR #66) — flask impact spawns lingering `AcidPool` that DoT ticks on any enemy that walks through
- **Music uplift** (PR #66) — triangle wave instead of square; menu vs game track bank; drums on game track (kick/snare/hat)
- **Monster intro animation** (PR #67) — `enemy_introduced` signal + 1.2s zoom-fade overlay on first spawn of each type
- **Enemy bobbing walk** (PR #67) — sine-wave `v_offset` driven by `_walk_phase` so enemies visibly step instead of slide

## ✅ Shipped 2026-04-18 afternoon (big day — 14 PRs)

Infrastructure:
- Photo pipeline robust + Gemini fallback + diagnostic (PR #42/#59)
- Auto-merge with `--auto` flag (PR #55)
- Workflow observability — runs commit results to `docs/observability/` (PR #62)
- Playtester v3.1: 60s window, 4× time_scale, proper stress spawn, 3 scenarios × all 3 levels (PR #55)
- L1 preload — texture warmup on menu (PR #55)
- Pool race + double-release guards (PR #60)

Game correctness:
- DamageType enum actually applied (PHYSICAL / MAGIC / PURE armor rules) (PR #43)
- Spawn-stacking fix — MIN_DELAY floor + per-enemy v_offset (PR #43/#54)
- Healer signal leak on pool reuse (PR #60)
- Healer heal-radius uses progress-distance not global (PR #60)
- Spawn-children bounds check + EnemyPool usage (PR #60)
- Safe-area idempotency guard (PR #60)
- Tower-info panel auto-hide on tap-outside (PR #60)

Perf:
- Projectile object pool (PR #56)
- Enemy object pool (PR #57)

Game feel (1% Juice Pass):
- Pop SFX pitch by enemy size (PR #43)
- Starting gold +50% all levels (PR #43)
- Tower sprite rotates toward target ±35° (PR #43)
- Victory screen 2s hold (PR #43)
- ✦ mini-floater on every non-killing hit (PR #43)
- Mobile touch targets ≥52px + safe-area (PR #44, from loop)

---

## 🔥 P0 — Placement + Shop UX Overhaul (live feedback)

User playtests have identified the current tap-to-place + bottom-bar shop
as the biggest UX friction. BTD6-style drag-and-drop from a side shop is
the target. These are large but self-contained features — each one
worth a dedicated PR.

- [ ] **Drag-and-drop tower placement**: replace tap-button → tap-map
  flow with press-and-drag from the shop button directly onto the map.
  Implementation: tower shop button gets `_gui_input` handler that
  captures press, then `_unhandled_input` tracks drag position and
  shows the ghost tower following the touch. Drop on valid map position
  instantiates; drop on invalid (path, off-screen, too close to tower)
  plays the placement-invalid toast and refunds. Must still support
  tap-to-preview in options menu (accessibility).
- [ ] **Scrollable side-widget tower shop (BTD-style)**: replace the
  full-width `HBoxContainer` at bottom with a vertical `ScrollContainer`
  anchored to the right edge, ~140px wide. Five tower icons stacked
  with cost + name. Tap opens detail tooltip, drag initiates placement.
  Collapses to thin handle when not in use. hud.tscn restructure needed:
  - Remove `$BottomPanel/BottomBar/TowerShop` HBox
  - Add `$SideShop` PanelContainer (anchor right, top 20%, height 60%)
  - Containing a VBox ScrollContainer with tower buttons
  - `_populate_tower_shop()` populates the VBox instead
- [ ] **Monster first-appearance intro animation**: when a new enemy
  type spawns for the first time in a session (track via GameManager.
  seen_enemy_ids Set[String]), freeze the wave for 1.2s and play a
  big reveal animation: enemy zooms in from offscreen to 2× scale at
  center, portrait slides in with name label + Swiss-German taunt
  speech bubble, music ducks 50% briefly, screen flashes. After first
  reveal, enemies never show name labels again (removes the constant
  floating text over every enemy). Spec:
  - `GameManager.seen_enemy_ids: Array[String] = []`
  - On wave_manager.\_spawn_enemy, check if enemy_id NOT in seen_enemy_ids
  - If new: emit enemy_introduced(id, data) signal, add to seen
  - HUD listens, builds an EnemyIntroOverlay, animates 1.2s, frees
  - base_enemy removes its persistent name label; only the intro shows it
- [ ] **Enemy movement polish**: add bobbing walk cycle to
  base_enemy.\_physics_process — sine-wave y-offset ±3px at speed-
  proportional frequency. Plus dust-puff particles on each "step"
  (every 0.4s at normal speed). Makes enemies feel alive, not static
  sprites sliding on a track.

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

- [x] **Pop SFX pitch by enemy size**: in `sfx_manager.play_death(enemy_data)`
  modulate base sweep frequency by `enemy_data.health` (small enemies =
  higher pitch, big enemies = deep thump). Single line change.
- [x] **Generous starting cash +50%**: bump `level_data.starting_gold` by
  ~50% across all 3 level data files. Testing playtests already show
  early game is gold-starved.
- [x] **Tower sprite rotates toward target**: in `base_tower._process` set
  `sprite.rotation = (current_target.global_position - global_position).angle()`
  when targeting, with `lerp` smoothing for snappy feel. Skip if no
  target.
- [x] **Victory screen 2s hold**: in `game_over.gd` defer score reveal
  by 2s after `level_completed` signal — gives the final pop air time.
- [x] **+gold floater on EVERY enemy hit (not just kill)**: tiny "+1"
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
- [x] DamageType enum actually applied in base_enemy.gd (magic ignores armor, physical reduced by armor) — PLAN #16
- [x] Show feedback text on invalid tower placement ("Z'nöch am Wäg!" / "Z'nöch am Turm!") — PLAN #24
- [x] Tower cost affordability color (yellow/gold affordable, red unaffordable) — PLAN #28
- [x] Floating `+gold` labels don't disappear when monster dies (tween was self-bound to freed enemy)
- [x] Death SFX was grating noise burst — replaced with soft 180→70Hz sweep at 0.15 volume
- [ ] Story screen rework — multi-page dialogue boxes instead of one cramped panel. User reports text is too small to read and skips show immediately. Bloons/Monaco-style typewriter across 3-5 pages with big tap-to-advance buttons. Swiss German content unchanged, presentation rebuilt.
- [ ] **Options menu** (music volume, SFX volume, master volume) accessible from main menu AND pause menu. Use AudioServer buses: add "Music" and "SFX" buses, route MusicManager/SfxManager players through them, expose sliders that call `AudioServer.set_bus_volume_db`.
- [x] Enemy pathing bug: at level 2+, enemies stack up at spawn — fixed in #43 with MIN_DELAY=0.35s floor in wave_manager spawn queue builder.

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

- [x] Enemy count on HUD ("12 übrig" next to wave counter) — PLAN #26
- [ ] Tower range preview stat in shop buttons — PLAN #29
- [x] Reposition tower info panel so it doesn't overlap map — PLAN #30 (auto-hide on tap-outside, PR #60)
- [x] HUD buttons ≥ 50px for mobile touch — PLAN #34
- [x] Pause button 60px minimum — PLAN #35
- [x] Safe area margins for notches/status bars — PLAN #36
- [x] Health bar smooth tween over 0.2s — PLAN #41
- [ ] Screen shake on boss spawn (level 3 wave 10) — PLAN #42
- [x] Wave start announcement flies across screen — PLAN #43
- [ ] UI click SFX wired to every button press — PLAN #52
- [ ] Boss entrance SFX (low rumble) — PLAN #54
- [ ] Tutorial overlay for first-time play — PLAN #27
- [ ] Level select background uses levelselect_bg.png — PLAN #31
- [ ] Story screen: small centered portraits, dark overlay — PLAN #32
- [ ] Main menu buttons: panel behind buttons over artwork — PLAN #33
- [ ] Proper star icons instead of `*`/`-` characters — PLAN #70

## 🎮 P1 — New Content

- [x] Level 4 data + scene + story intro — D'Chäsi-Keller (PR #84 ships chäs theme; cash register kept for L5)
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

- [x] Object pooling for projectiles — PLAN #63 (PR #56, 2026-04-18)
- [x] Object pooling for enemies — PLAN #64 (PR #57, 2026-04-18)
- [x] Viewport scaling across phone sizes — PLAN #66 (stretch=expand + safe-area insets, PRs #44/#60)
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

- [x] **Empty space left/right in landscape**: fixed via
  `window/stretch/aspect=expand` + DisplayServer safe-area insets
  in hud.gd. Layout flexes on 20:9 phones. Shipped PR #44/#60.
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

## 💡 Ideate 2026-04-19 — Direct Democracy, Coupons & Boss Personality

Five fresh specs from the 2026-04-19 ideate run. Each fills a gap none of
the existing roadmap items cover: **between-wave engagement**, **mistake
recovery**, **antagonist personality**, **idle-tap dopamine**, and a true
**post-Level-10 endless loop with weekly community variance**. Specs not
vibes — concrete numbers, file paths, signal contracts.

- [ ] **Abstimmig-Modus (Direct-democracy wave modifiers)** — every 3rd
  wave (waves 3, 6, 9 of each level), pause briefly and pop a Swiss-style
  voting card top-center: two modifier choices, each with a JA-grün /
  NEI-rot button styled like a real Swiss ballot. Player picks one; the
  modifier applies for the next 3 waves then expires. Twelve seed
  modifiers, two random ones surfaced each vote:
  - "+50% Gold-Bonus" (each kill +50% gold)
  - "Schnälleri Wäue" (waves spawn 25% faster, more pressure)
  - "+1 Läbe-Regäneration" (regain 1 life every wave clear)
  - "Türm schiessed 25% schnäller"
  - "Gegner händ -15% HP"
  - "Zwöi-Ziel-Türm" (every tower targets 2 enemies)
  - "Kein Sell-Refund" (sell button disabled — the trade-off)
  - "Türm-Kosten -20%"
  - "Boss spawnt 2 Wäue früener" (risk-reward)
  - "Klini Banane-Räge alli 30s" (free auto-cast)
  - "Spezial-Münze x2" (when shipped after Spezial currency lands)
  - "Cumulus x1.5" (when shipped after Cumulus lands)

  Implementation: `scripts/systems/wave_manager.gd` emits
  `vote_required(modifier_options: Array[Dictionary])` between waves
  3/6/9. New `scripts/systems/modifier_manager.gd` autoload tracks
  active modifiers as `{id, expires_in_waves, payload}`, exposes
  `apply_to(target_data, kind)` so towers/enemies/currency query it
  on stat reads. New `scenes/ui/vote_panel.tscn` — two-column
  PanelContainer with JA/NEI buttons, fades in via Tween, closes on
  pick or 6s timeout (random pick if no input). Mobile-friendly: each
  card ≥ 200px wide, ≥ 120px tall, single-tap.

  Why ship: zero current systems give the player a between-wave
  decision. This adds replayability (12C2 = 66 vote permutations per
  run) and Swiss-cultural specificity (Abstimmig is the Swiss national
  pastime). Not in BTD — direct-democracy modifiers are uniquely ours.

- [ ] **Reklamatzioe-Karte (Migros complaint card — 100% undo)** — Swiss
  humor mechanic: 3 "Reklamatzioe" cards per level let the player undo
  a tower placement within 10 seconds for **100% refund** (vs. normal
  sell's 60%). Models the real Migros customer-service desk where you
  return a wrong purchase. After 10s the card greys out for that
  tower; the count appears top-right next to gold (`📋 3/3`).

  Implementation: `scripts/systems/reklamatzioe.gd` autoload tracks
  `cards_remaining: int = 3` per level (reset on `start_level`). On
  tower placed, `tower_placement.gd` records `placed_at_msec` on the
  tower instance. Tower info panel shows a red "📋 Reklamatzioe (10s)"
  button when `Time.get_ticks_msec() - placed_at_msec < 10000` AND
  `Reklamatzioe.cards_remaining > 0`. Click → tower freed, full cost
  refunded, ka-ching SFX, brief "Reklamatzioe agnomme!" toast.

  Why ship: encourages experimentation (place-and-evaluate without
  punishment), reduces rage-quit on misclicks (huge on touch), and
  the Migros customer-service framing is character-rich. Not in BTD.

- [ ] **De Vegan-Tüüfel Taunt System (boss personality between waves)** —
  between every wave, a small De-Vegan-Tüüfel portrait pops in the
  bottom-right corner with a Swiss-German taunt in a speech bubble for
  3 seconds, then slides off. Taunts pull from a tagged pool keyed by
  player state — never repeats verbatim within a level.

  Taunt pool spec (≥ 30 lines, tagged by trigger condition):
  - LOW_GOLD (< 50g): "Bisch pleite, ja? Häsch z'viel im Migros gebe!"
  - LOW_LIVES (≤ 5): "No 5 Läbe... ich rieche dini Angst!"
  - HIGH_TOWER_COUNT (≥ 8): "Vill Türm, vill Ärger — kömmer doch!"
  - PERFECT_WAVE (no life lost in last wave): "Gschick, abr s'isch nur d'Vorspiis!"
  - BOSS_INCOMING (next wave has boss): "Jetzt chunt MIR — pass uf!"
  - MID_RUN (default fallback ~12 lines): generic mockery
  - WIN: "Nein! Zürichberg sött MEIN si!" (final-wave taunt before
    game-over screen, doubles as victory flavor)

  Implementation: `scripts/systems/taunt_system.gd` autoload with
  `Array[Dict]` of `{tag: String, text_de: String}`, function
  `pick_taunt(state: Dictionary) -> String`. WaveManager emits
  `wave_completed(stats: Dictionary)`; HUD listens, calls TauntSystem,
  shows new `scenes/ui/taunt_bubble.tscn` (PanelContainer + Label +
  small Vegan-Tüüfel sprite) with slide-in/out Tween. Stops appearing
  if user taps a "Mute Tüüfel" toggle in options.

  Why ship: cheap personality. Currently the antagonist is invisible
  outside of cutscenes — between-wave taunts make him a constant
  presence. 30 lines is one ideate-mode session's writing work.

- [ ] **Migros-Coupon drop (tappable gold reward)** — every 7th enemy
  killed (counter resets on level start) drops a Migros-orange coupon
  Sprite2D ("Aktion! +25g") that floats slowly on a sine path across
  the playable area for 4 seconds. Tap to claim +25g + ka-ching SFX +
  small confetti puff. If untouched, it fades and is lost. Encourages
  active touchscreen engagement during slow waves — perfect for the
  fidgety mobile-train-ride play context.

  Implementation: extend `base_enemy._on_died` with a global counter
  in CurrencyManager (`enemies_killed_total`); when `% 7 == 0`, spawn
  new `scenes/effects/migros_coupon.tscn` at enemy position. Coupon
  is Area2D + Sprite2D with `_on_input_event(... InputEventMouseButton
  or ScreenTouch)` → claim. CPUParticles2D for confetti on claim.
  Auto-frees after 4s if untouched. Coupon texture: small 64×96 PNG
  with Migros-orange "AKTION!" stamp — generate via Imagen 4.

  Why ship: cheapest possible "do something between tower placements"
  loop, and the Migros-coupon framing is on-theme to a degree no
  generic +gold pickup would be. Designs around the "phone game played
  one-handed on tram" use case.

- [ ] **Sechstigi Wuchä (Endless mode with weekly modifier seeds)** —
  builds on the already-planned Endless mode. After Level 10 win,
  endless mode is unlocked. Each in-game "Wuchä" (= 5 waves) advances
  a counter; **the modifier active each Wuchä is deterministic by
  real-world week number** (`floor(Time.get_unix_time_from_system() /
  604800) % MODIFIER_POOL_SIZE`), so every player worldwide gets the
  same modifier sequence for that week. Foundation for community /
  leaderboard play without a backend.

  Modifier reveal UX: at the start of each Wuchä, an SBB-style
  departure-board panel scrolls in from top-left with the modifier
  text in yellow-on-black ("WUCHÄ 7 — Alli Gegner +20% Speed"),
  ding-dong arrival SFX, holds 2.5s, scrolls out. Twelve seed
  modifiers (separate pool from Abstimmig — these are forced, harsh,
  shared globally):
  - "Iis-Wuchä": all enemies +30% speed
  - "Tüüfel-Wuchä": +1 boss spawns at end of each wave
  - "Sparig-Wuchä": -50% gold income
  - "Gross-Wuchä": all enemies +50% HP
  - "Schwarm-Wuchä": +100% spawn count
  - "Stiläzitig-Wuchä": between-wave time -50%
  - "Räge-Wuchä": +25% gold but towers fire 25% slower (humid)
  - "Föhn-Wuchä": projectiles drift (random ±15°)
  - "Streik-Wuchä": one random tower disabled per wave
  - "Marschpaus-Wuchä": +1 free Banana-Räge per wave (gift week)
  - "Sale-Wuchä": -25% all tower costs
  - "Härter-als-Härt-Wuchä": all multipliers x1.25 stacking

  Implementation: `scenes/game/endless.tscn` reusing level_3 path/bg
  initially. New `scripts/systems/endless_mode.gd` calculates current
  Wuchä = 1 + (waves_cleared / 5). New
  `scripts/systems/weekly_seed.gd` autoload exposes
  `current_week_modifier_chain() -> Array[String]` returning the
  next ~50 Wuchä modifiers from the deterministic seed. ModifierManager
  (built for Abstimmig) reused to apply effects. Departure-board UI:
  small `scenes/ui/sbb_board.tscn` with a horizontally-scrolling
  Label using existing Tween infrastructure.

  Why ship: makes endless interesting beyond "harder waves forever"
  by forcing a different play-style every Wuchä. The deterministic
  weekly seed means user can compare runs with friends without any
  backend infra. Specifically Swiss (SBB-board UX is iconic) — BTD
  endless has nothing like it.

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
- **2026-04-19 — GameManager save format will collapse under planned
  expansions.** `scripts/autoload/game_manager.gd` `save_game()` writes
  one monolithic `user://save_data.json` with a flat dict
  (`levels_unlocked`, `level_stars`, `friend_photos`, audio volumes).
  The current P0 expansion roadmap will add: Cumulus balance + node
  unlocks, Spezial-Münzen balance + history, mission completion state
  per level, level_clears keyed by difficulty (eifach/normal/hert/
  brutal), Forschig unlocks across 3 branches, hero XP per friend,
  endless-mode best-Wuchä per level. Without a schema strategy this
  becomes ~12 sibling keys with implicit version coupling — any
  breaking change wipes saves silently.

  Recommended pre-expansion refactor (1 small PR, before shipping the
  Spezial currency): introduce `save_version: int` field, namespaced
  sub-dicts (`{ "core": {...}, "cumulus": {...}, "spezial": {...},
  "missions": {...} }`), and a migration switch in `load_game()` that
  applies version-to-version transformers. Each new currency/system
  loads its own slice from its own autoload's `_ready`, never touches
  others. Costs ~50 LoC; saves us from a "save file got corrupted"
  bug-storm 4 PRs from now. Also: `MAX_LEVELS := 4` is hardcoded —
  derive from `DirAccess.get_files_at("res://resources/level_data/")`
  so the constant doesn't drift each time a level ships.

## 🎯 P2 — Polish & Extras

- [x] Upgrade visual path (tint/glow per upgrade level) — PLAN #22 (PR #54/#60, 2026-04-18)
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
