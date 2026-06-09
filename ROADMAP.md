# Roadmap — Affoltern Banani Raubzug

The autonomous dev loop reads this file every 6 hours and picks the
highest-priority unchecked item matching the current run mode.

**Priority order**: P0 (blocking) → P1 (important) → P2 (nice-to-have).
Within a priority, top-of-list wins. Aging items at the top take
absolute precedence.

**Live state docs** (read these before picking work):
- `docs/observability/asset_status.md` — what art is shipped vs missing
- `docs/observability/loop-status.md` — workflow health snapshot
- `docs/changelog/` — what shipped when (historical, dated)

Previous ROADMAP archive (1178 lines, 6 conflicting P0 sections —
collapsed into the section below):
`docs/changelog/2026-05-03-roadmap-archive.md`

---

## 🔥 P0 — Current Priority

The single source of truth for "what ships next". Picked from playtest
feedback, post-audit findings, and the highest-leverage user-visible
work. Cap: 15 items. When something ships, tick it AND remove it within
7 days; new P0 items get appended at the bottom.

### Game systems
- [x] **Wire 11 new enemy textures into .tres files** — `camo`, `lead`,
  `regrow`, `swarm`, `fondue_bomb`, `glace_golem`, `berserker`,
  `cumulus_blob`, `linsen_golem`, `smoothie_slime`, `tofu_ninja` all
  have base PNGs in main and their `.tres` files reference them via
  `custom_texture`. Verified 2026-05-05.

- [x] **Run enemy-damage-art for the 11 new enemies** — PR #387 merged
  2026-05-05 with 51 damage-state variants covering all 17 enemy types
  (basic, fast, tank, healer, flying, boss, camo, lead, regrow, swarm,
  fondue_bomb, glace_golem, berserker, cumulus_blob, linsen_golem,
  smoothie_slime, tofu_ninja).

- [x] **Drag-and-drop tower placement** — ghost appears on shop-tap and
  follows finger, green tint = valid, red tint + ✕ icon = invalid;
  tap map to place. Drag-from-shop tried (button_down) but was unreliable
  on HTML5/touch and reverted (user report). Current tap-then-tap flow is
  solid. Verified in code: TowerPlacement._unhandled_input with ScreenDrag.

- [x] **Scrollable side-widget tower shop (BTD-style)** — right-anchored
  SideShop PanelContainer with ShopScroll ScrollContainer + TowerShop
  VBoxContainer inside. Collapsible handle with 0.22s slide tween,
  per-friend row tint, affordability dim. Verified in hud.tscn + hud.gd.

### Performance (data-blocked until playtest #330 + #328 fix lands)
- [ ] **Real FPS pass** — once `playtest.yml` produces `fps.log` with
  honest 3-5 tower scenarios (commit `8e89310` ships this), audit any
  scenario reporting min FPS < 30 and address. Suspects from old data:
  L1+L3 hitches, 80-enemy stress.
  _Partial fix 2026-05-04: EffectPlayer concurrent caps (MAX_FLASH 8, MAX_DUST 6,
  MAX_MISC 10) + ~30% particle count reductions; glow ring 5×48→2×20 arcs;
  range_circle _process disabled when hidden. Next step: profile with Godot
  headless --rendering.profiler once the headless FPS number stabilises._

### Tier-art completion
- [ ] **D1/D2 portraits for remaining 3 towers** — Cordula and Kühne
  done (#310, #311). Need `basic` (Lemurius), `splash` (JoJo), `slow`
  (Amösius). Output: `assets/textures/towers/{tower_id}_t{1,2}{a,b}.png`.

### Asset hygiene (from audit 2026-05-03)
- [x] **Delete superseded art** — 8 orphaned PNG+import pairs deleted
  (amosius_raw, cordula_final, cordula_upgrade, cordula_v2, jojo_final,
  jojo_v2, kuhne_final, kuhne_v2) — ~13.8 MB recovered. Verified no
  .tres/.gd/.tscn reference them (img2img and clean variants kept).
  Remaining `_img2img` files (cordula, jojo, kuhne) are active tower
  textures, not orphans.

### CI / observability
- [ ] **Smarter ci-monitor** — root cause identified: `autonomous-dev.yml`
  needs `continue-on-error: true` on the claude-code-action step so the
  tsconfig/fd-4 post-step cleanup noise doesn't mark every run as failed.
  Fix written but NOT applied — pushing workflow files requires `workflows`
  token scope; the GITHUB_TOKEN used by the loop doesn't have it. Needs
  user to either: (a) grant `workflows` write permission in the repo's
  Actions settings, OR (b) apply manually. Fix: add `id: claude_run` +
  `continue-on-error: true` to "Run Claude Code" step in autonomous-dev.yml,
  then add a "Flag genuine Claude failure" step after validate that fails
  only when outcome=failure AND no claude/auto/ PR was produced.

- [x] **Fix workflow-lint** — actionlint + bash-syntax both pass
  locally against all 28 workflow files. The "never succeeded" status
  in the stale loop-status.md was a stale record (loop-health pushes
  blocked since 2026-05-03 by the branch-protection ruleset). The lint
  itself is green. Verified 2026-05-05.

- [x] **Fix drift-scan + weekly-digest** — drift-scan was replaced by
  `weekly-audit.yml` (scheduled Mondays 06:00 UTC) on 2026-05-03.
  weekly-digest disabled pending Resend email debugging. Both items
  are resolved/superseded. Verified 2026-05-05.

- [ ] **Restore observability push** — the branch-protection ruleset
  (added 2026-05-03) blocks direct `git push origin main` from
  github-actions[bot] because no bypass actor is set. loop-health,
  deploy-web, playtest, and ci-monitor observability commits all fail
  silently since ~2026-05-03T16:31Z. Fix: add `github-actions[bot]`
  as a bypass actor at github.com/jgschobel/Tower-Defense-Game/rules/15885847
  (requires repo admin — 2 min from phone). OR: grant the GITHUB_TOKEN
  in autonomous-dev.yml the `workflows` permission and migrate workflows
  to use the GitHub Contents API for observability writes.

---

## ⚡ P1 — Important Polish & Content

### Content
- [x] **Hero system foundation** — Lemurius "Banana-Storm" active ability at
  tier 3+: 3–5s triple-fire burst on 30s cooldown. Tap-button in upgrade
  panel (HUD _ensure_ability_button). Shipped via base_tower.gd
  (ability_cooldown_remaining, trigger_active_ability) + hud.gd. Verified 2026-05-08.

- [x] **Cumulus meta-progression** — 1 Cumulus point per wave cleared,
  100 Cumulus = 1 starter perk (+50 starting gold). Shipped 2026-05-08 via
  GameManager.earn_cumulus() + game_level._on_wave_completed() hook;
  balance shown on game_over screen (victory + defeat). PR #553.

- [x] **D7 Tier-3 unique death-cam effect** — 0.4s bullet-time (Engine.time_scale
  0.05) + 4-burst gold/white spark explosion + "✦ [Tower Name]" floating name bubble
  above the killing tower. Shipped 2026-05-05 via effect_player.tier3_boss_kill().

- [x] **Per-path projectile tier skins (D4)** — Lemurius normal banana
  → big banana → khaki missile. Pollen → icy flower → fire lily. Etc.
  Shipped 2026-05-06: all 5 projectile styles (banana, pollen, flask, volleyball, tongue)
  visually distinct at tiers 1–3 via `setup(…, p_tier)` + `_draw()` branching.

- [x] **L10 dedicated background** — `level_10_finale.png` generated via
  Stability AI SD3.5-large (dark hellfire Migros vault). Verified 2026-06-06.

### Workflow / discipline
- [x] **PR template with verify-checklist** — forces author to confirm
  "did you read asset_status.md? does this affect playtester signal?"
  before opening. Shipped 2026-05-06 via `.github/PULL_REQUEST_TEMPLATE.md`.

- [x] **`session-opener.yml`** — daily 03:00 UTC workflow that writes
  `docs/observability/session_brief.md`. Exists as
  `.github/workflows/session-opener.yml`. Verified 2026-05-08.

- [ ] **Branch protection on main** with required CI checks
  (`validate.sh`, `workflow-lint`, `playtest`). Makes
  `gh pr merge --auto` actually wait for green CI.

- [x] **Autonomous-loop killswitch** — `.github/workflows/loop-killswitch.yml`
  monitors merged PRs by claude[bot]; opens `loop-broken` issue + writes
  PAUSE file if no PR merged in 24h with >5 stuck open PRs. Verified 2026-05-08.

---

## 💡 P2 — Ideas To Explore

- [ ] **Forschig (Research) menu** — 9 permanent upgrades unlockable
  with Cumulus/Spezial currency. Spec in archived roadmap.
- [x] **Difficulty modes** — Eifach/Normal/Hard/Expert per level.
  _2026-06-06: difficulty_count_mult wired into wave_manager (PR #689);
  HP/speed/gold/aminos multipliers were already active. UI picker already
  present in level_select.gd._
- [ ] **Bonus levels** — "Self-Scan-Hölli", "Banani-Träume",
  "De Tüüfel kommt heim", "Cumulus-Bingo".
- [ ] **Daily challenge** — single-attempt daily mission with
  leaderboard.
- [x] **Active power abilities** — all 5 friend towers now have tier-3+
  active abilities (PR #690). Kühne: POLLEN-WOLKE (6s, 90s CD), JoJo:
  MEGA-SPRITZ (4s, 120s CD), Cordula: VOLLEY-TORNADO (5s, 90s CD),
  Amösius: ZUNGE-RUCK (4s, 60s CD). All use 3× fire-rate burst.
  _VFX done 2026-06-09: expanding ring + radial particle burst per tower in signature color (banana gold, pollen teal, hot orange, volleyball pink, ice cyan). Differentiated attack patterns still TODO._

### Added 2026-06-04 (ideate run)

- [ ] **MOAB-class boss: "Selbschtbedienigs-Wage"** — self-checkout
  shopping cart mega-boss that, when popped, splits into a payload of
  6 stacked enemies (3× fast `pasta_express`, 2× swarm `cherry_bomb`,
  1× camo `tofu_ninja`). HP 5,000, speed 40 px/s, 350 gold drop.
  Debuts L7 wave 8, reappears L9 wave 6. New tres
  `resources/enemy_data/selbschtbedienigs_wage.tres`; new
  `_split_into_payload(payload_ids: Array, fan_offset_px: float)`
  method on `BaseEnemy.die()` reusing EnemyPool.acquire so the spawn
  doesn't tank perf. BTD analogue: BFB-with-cerams; theme: the
  endless "Help required at self-checkout" gag every Swiss shopper
  knows. **Impl hint:** payload spawns with the parent's
  `path_progress`, fanned by `±h_offset` so they don't visually stack.

- [ ] **Migros-Bon active power (50% off next 3 actions)** — top-bar
  "🎫 Bon" button (only visible when ≥1 charge). Tap → next 3 tower
  placements OR upgrades cost 50% gold. Charge cost: 200 Cumulus to
  unlock first slot in Forschig menu; thereafter +1 charge per level
  cleared (cap 3). New autoload field `GameManager.bon_charges: int`;
  `CurrencyManager.try_spend()` consults `_pending_discount_uses`
  before deducting. UI: HUD adds `BonButton` next to PauseButton,
  60×60 px, animated 1.05× pulse when ≥1 charge. **Why it sticks:**
  gives meta-currency a *visible* effect mid-run, not just a passive
  +50 gold buff.

- [ ] **"Geischter-Lauf" (ghost replay) — laziest-player fantasy** —
  after each win, GameManager persists a JSON `replay_<lvl>.json`
  with `{tick, action, params}` per significant event (tower place,
  upgrade, wave_start, ability_trigger). MainMenu adds "▶ Geischter
  schaue" entry on cleared levels: replays the run as a faint
  translucent overlay (towers ghost-tinted to 60% alpha, enemies
  follow the same RNG seed). Doubles as: (a) watch-mode for new
  players to learn strategies, (b) ghost-line vs. current attempt
  on re-play to push optimization. **Why it's a TikTok moment:**
  side-by-side "first attempt vs. mastered" replays. Small first
  cut: record only tower placements + wave timestamps, render the
  ghost as static `Sprite2D` placements.

- [ ] **"Hei-Karte" — share-card on tier-3 finisher or 50× combo** —
  hooks `effect_player.tier3_boss_kill()` and
  `combo_tracker._on_combo_changed` (when count crosses 50). On
  fire: pause render, composite a 1080×1080 PNG via `Viewport.get_texture()`
  with: kill frame, friend portrait (32×32 corner), combo count in
  giant Züri-Bahnhof font, "Bi de Bani z'Affoltere" tagline, and a
  QR (procedurally generated, no lib) pointing to the deployed Pages
  URL. HTML5 → copy to clipboard via `JavaScriptBridge`. Native →
  save to `user://share/`. **Why it's worth it:** the share card IS
  the marketing — the user has named "screenshot worth sharing" as
  the bar. New script `scripts/systems/share_card.gd`, dependency-free.

- [ ] **"DDT-Verwüschelig" Tüüfel sabotage event (L8+)** — between
  waves on L8/L9/L10, 25% chance the De Vegan-Tüüfel drops 3
  Servelat-smoke bombs at random map positions (avoiding path tiles).
  Towers within 80 px of any bomb get -50% range AND a purple
  modulate tint for 12s. Player gets two counters: (a) sell any
  affected tower for FULL refund during smoke window (sympathy
  refund), or (b) place a one-shot "🧄 Knoblauch-Tube" (40 gold,
  HUD inventory slot) on the bomb to cleanse it in 0.5s. **Mechanic:**
  new `GameLevel._schedule_sabotage_event()` between waves;
  `BaseTower._process()` reads `has_meta("ddt_smoked")` to apply
  the range/tint mod. **Why:** adds rhythmic between-wave decisions
  to the late game where current downtime is dead air.

### Added 2026-06-05 (ideate run)

- [x] **"Synergie-Combo" — adjacent-friend passive bonuses** — when
  two specific friend towers are placed within ~150 px of each other,
  both get a small passive bonus AND a tiny `✦ Synergie` badge above
  their hats. Predefined pairs (Swiss-cast specific, not generic):
  - **Lemurius + Cordula** = +20 % range each (childhood-friends
    "mir gsehnd alles" combo)
  - **Kühne + JoJo** = +15 % damage each (precision + chaos)
  - **Amösius + Cordula** = +0.5 s slow duration (icy support stack)
  - **JoJo + Lemurius** = +1 projectile pierce (banana-volleyball)
  - **Joe + Justus** = +25 % attack speed (Vater/Sohn rapid fire)

  **Impl spec:** new `scripts/systems/synergy_table.gd` (data-driven
  array of `{a_id, b_id, range_mul, dmg_mul, slow_dur_add, pierce_add,
  atk_speed_mul}` entries). `BaseTower._refresh_synergies()` runs on
  placement, sell, and via a `GameLevel.tower_topology_changed` signal
  (not per-frame). Uses squared-distance check vs. 150² = 22 500 to
  avoid `sqrt`. HUD badge: 12×12 `Polygon2D` star, gold (`#FFD27A`),
  positioned above the tier-hat slot. Tower-info panel adds a
  "🤝 Synergie:" row when active, listing the partner name in Swiss
  German.

  **Why it sticks:** BTD has no friend-pair-specific bonuses — this
  rewards placement intelligence in a way that's unique to *this*
  game's cast. Composes naturally with [[migros-bon-active-power]]
  discount placements. ~250 LoC, no new art needed.
  Shipped PR #758 (2026-06-07): `scripts/systems/synergy_table.gd` + `BaseTower._refresh_synergies()` + ✦ badge.

- [ ] **"Migros-App" diegetic phone overlay (level-select skin)** —
  optional cosmetic skin that reframes `level_select.tscn` as a fake
  Migros mobile app. Static carousel of push-notification toasts
  drops in every 8–12 s with Swiss German one-liners:
  - "Mami: Bring no Brot mit! 🥖"
  - "Cumulus-Aktion: Gratis Banani bi 5 Stern"
  - "De Tüüfel hät dir gleicht. Hilfe gsuecht."
  - "JoJo: Wo bisch? Voll spannend hie."

  Gold balance shown as `Cumulus-Punkte 2,345 ★`; the "Spiele" button
  styled as an in-app feature button with rounded `StyleBoxFlat` + a
  subtle 1 px white border (mimics iOS list-cell). **Impl:** new
  `scripts/ui/migros_app_skin.gd` that hooks into `level_select.gd`
  via signal `_ready()`; toggle in `OptionsMenu` (`migros_app_skin: bool`
  in `user://settings.cfg`, default `false` so existing players opt-in).
  Hard-coded notification queue of ~15 strings in
  `scripts/data/app_notifications.gd` (data, not logic).

  **Why it sticks:** turns dead-air menu time into joke-delivery time.
  ~150 LoC, no art (uses existing icons + emoji). Pairs perfectly with
  [[hei-karte-share-card]] for cohesive "diegetic phone" feel.

- [x] **"Hoi-Schatz" tower love-tap easter egg** — tap any placed
  friend tower 7 times in 3 s (without selecting it for upgrades) and
  it plays a Swiss-German voice-line bubble above its head: Lemurius
  → "Hoi Schatz!", Cordula → "Mir gönds guet, gell?", Kühne → "Ruig,
  ruig, alles unter Kontrolle.", JoJo → "Was machsch du dänn?",
  Amösius → "Brrr, kalt isch's!". 30 s per-tower cooldown so spam
  doesn't ruin it.
  _Shipped 2026-06-07: `scripts/data/easter_egg_lines.gd` + `on_tapped()`
  in `base_tower.gd` + wired in `game_level._check_tower_tap`._

- [ ] **"Wagli-Schub" — drag-to-push shopping cart active power** —
  active player power: tap a top-bar `🛒 Wagli` button, then drag a
  finger across the map. Enemies the drag-line crosses get pushed
  backward along the path by 30–50 px (`path_follow.progress -=
  push_amount`). Costs **30 gold** per use (immediate, no cooldown
  but gold-gated so spam = bankruptcy). Unlocks at **150 Cumulus** in
  the Forschig menu.

  **Impl:** new `scripts/ui/wagli_cursor.gd` overlay listens to
  `InputEventScreenDrag` during active mode. Each drag step queries
  enemies via `EnemyPool.get_active()` and tests
  `global_position.distance_squared_to(drag_pos) < 60²`; affected
  enemies have their `PathFollow2D.progress` decreased by 35 (clamped
  to >= 0). Visual feedback: cursor sprite swapped to a 32 px
  shopping-cart icon (already exists at `assets/icons/wagli.svg`);
  dust-puff `EffectPlayer.dust(...)` at each enemy hit; gold deducted
  per *unique enemy* pushed (not per frame). Hard cap: max 4 enemies
  pushed per drag-stroke (`_pushed_this_stroke: Set`) to prevent
  trivializing dense waves.

  **Why it sticks:** the user has named "active powers" as a P2
  cluster but they've all been *passive triggers* or *taps*. This is
  the first one requiring physical gesture — the BTD-vet surprise is
  "you actually move them with your finger". Stacks with
  [[migros-bon-active-power]] (Bon = strategic, Wagli = tactical).

- [ ] **"Tag der Affoltern" — concrete daily-mission spec (closes the
  abstract P2 placeholder)** — supersedes the "Daily challenge" P2
  bullet with shippable details:
  - **Seed:** `floor(unix_time / 86400)` → deterministic level
    selection + tower-restriction + modifier per UTC day.
  - **Restriction examples:** "L3, only Kühne + Amösius allowed",
    "L5, no upgrades past tier 1", "L7, -30 % gold income",
    "L1 with double-speed enemies start wave 1".
  - **Reward:** 50 Cumulus on completion (~half a wave's worth),
    +100 if completed without losing a life.
  - **Persistence:** `user://daily/2026-06-05.json` records
    `{seed, attempts, best_lives, best_wave_reached, won_bool}`. Hard
    one-attempt-per-day; if user closes mid-run it auto-fails.
  - **UI:** new MainMenu button "🌅 Tag der Affoltern" — golden
    border, pulses when today's mission unplayed. Tap shows preview
    panel (level thumbnail, restrictions, reward) before "Spiele!"
    confirms the attempt-lock.

  **Impl:** new `scripts/systems/daily_mission.gd` autoload (~200 LoC)
  + `scenes/ui/daily_preview.tscn`. Hooks `GameLevel._on_level_won/lost`
  to write the JSON. Mission generator is a pure function — no RNG
  state, fully reproducible per seed.

  **Why it sticks:** gives a reason to open the game on a day you
  weren't planning to play. Composes with [[hei-karte-share-card]]
  ("Tag-Karte" variant brags about today's seed). The local-only
  leaderboard sidesteps the BFF complexity of online scores.

---

## 🔎 Architecture Notes

Long-form observations from periodic code reads. Each entry dated.
Use as input for refactor sprints when the loop runs `self-improve`.

- **2026-06-04 — `scripts/towers/base_tower.gd` is a 1188-line
  god-object with TWO embedded mini-scripts.** Lines 827–828 and
  911–912 define `_hat_script()` and `_glow_script()` getters that
  return `GDScript` objects whose `.source_code` is a multi-line
  string literal containing actual GDScript (`extends Node2D` +
  `func _draw()` + helpers). Effects:
  1. `validate.sh` and `godot --check-only` cannot parse these inner
     scripts as files — syntax errors hide until runtime.
  2. Editor "go to definition" doesn't work on `_draw_crown` /
     `_draw_band` inside the embedded source.
  3. The file mixes 6 responsibilities (targeting, upgrades, draw,
     animation, abilities, tier visuals) and is the #1 merge-conflict
     hotspot — 4 separate audit-polish branches modified it in May.

  **Refactor proposal (1–2 audit-polish runs):**
  - Extract `_hat_script()` → `scripts/towers/visuals/tier_hat.gd`
    (true Script file, instantiated via `preload(...)`).
  - Extract `_glow_script()` → `scripts/towers/visuals/tier_glow.gd`.
  - Move `_apply_path_tint`, `_apply_tier_scale`, `_update_tier_hat`,
    `_update_tier_glow`, `_rebuild_pip_cache` to a sibling
    `TowerVisuals` node attached as a child in `base_tower.tscn`.
  - Goal: drop `base_tower.gd` below 700 lines, all visual logic
    parseable by validate.sh, fewer merge-conflict surfaces.

- **2026-06-05 — `scripts/ui/hud.gd` is 2201 lines with 75 functions
  — even bigger than [[base-tower-god-object]].** A rapid `grep`
  shows at least seven separate responsibilities crammed in:
  1. Tower shop population, styling, and collapse animation
     (`_populate_tower_shop` L494, `_style_shop_button` L694,
     `_refresh_side_shop_layout`, `_build_shop_collapse_handle`,
     `_toggle_shop_collapse`).
  2. Threat / boss-HP UI (`_start_threat_watcher`,
     `_refresh_threat_badges`, `_refresh_boss_hpbar_live`,
     `_build_boss_hpbar`).
  3. Combo badge + screen-tint flash (`_ensure_combo_badge`,
     `_on_combo_changed`, `_apply_combo_screen_tint`).
  4. Enemy intro card + MOAB-tier telegraph
     (`show_enemy_intro` L730, `_build_enemy_preview` L865,
     `_flash_boss_telegraph`, `_flash_moab_telegraph`).
  5. Wave progress bar (`_ensure_wave_progress_bar`).
  6. Wave-clear celebration (`show_wave_clear_celebration`).
  7. Safe-area handling for notched phones (`_apply_safe_area`).

  **Symptoms already showing:** the 2201-line wall is the #2
  merge-conflict surface after `base_tower.gd` (every shop tweak,
  every combo tweak, every threat-badge tweak touches the same
  file). Search-by-feature requires a `grep` because the file
  outgrew "scroll-and-find". `_ready()` runs all subsystem setup
  inline — adding one new HUD widget means editing 4+ places
  (var declaration, `_ready` wiring, signal connection, layout
  refresh).

  **Refactor proposal (2–3 audit-polish runs, low risk because each
  HUD subsystem is signal-driven and stateless across each other):**
  - Extract subsystems to sibling scenes/scripts:
    `scripts/ui/hud/tower_shop_panel.gd` (responsibilities 1),
    `scripts/ui/hud/threat_indicator.gd` (2),
    `scripts/ui/hud/combo_overlay.gd` (3),
    `scripts/ui/hud/enemy_intro_card.gd` (4),
    `scripts/ui/hud/wave_progress.gd` (5),
    `scripts/ui/hud/wave_clear_burst.gd` (6).
  - Keep `hud.gd` as a thin orchestrator (~400 lines) that owns
    layout, safe-area, and forwards signals between subsystems.
  - Composition over class explosion: each subsystem is a `Control`
    sibling node added in `hud.tscn`, not a class hierarchy.
  - **Bonus:** every extraction is a unit-testable surface — drop a
    subsystem into a barebones scene in `tests/` to verify behaviour
    in isolation, which currently requires running the full game.

  Pair this refactor sequencing with the [[base-tower-god-object]]
  one — both files are the structural debt blocking faster
  feature work.

---

## Loop directives

- Pick the **top-of-list unchecked P0** unless the run mode says
  otherwise.
- If a P0 item is older than 7 days, it MUST be the next pick (rule
  overrides any mode).
- Tick the box `- [x]` AND add a one-line note when shipping. Append
  to `CHANGELOG.md` separately.
- If a task is multi-PR, split it into sub-bullets with their own
  boxes.
- Don't add new ideas while old P0s rot. Use P2 for ideation.
