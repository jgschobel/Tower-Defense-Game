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

- [x] **Fix kills=0 playtester regression (P0)** — GDScript recompilation
  race: loading any scene that transitively preloads base_projectile.gd
  detached scripts from all 40 pool nodes, so every attack aborted.
  Fix: ProjectilePool.acquire() reloads + re-attaches script on null
  instead of destroying. base_tower._attack() CACHE_MODE_IGNORE path
  also tries set_script() before aborting. PR #853 merged 2026-06-12.

### Performance (data-blocked until playtest #330 + #328 fix lands)
- [ ] **Real FPS pass** — once `playtest.yml` produces `fps.log` with
  honest 3-5 tower scenarios (commit `8e89310` ships this), audit any
  scenario reporting min FPS < 30 and address. Suspects from old data:
  L1+L3 hitches, 80-enemy stress.
  _Partial fix 2026-05-04: EffectPlayer concurrent caps (MAX_FLASH 8, MAX_DUST 6,
  MAX_MISC 10) + ~30% particle count reductions; glow ring 5×48→2×20 arcs;
  range_circle _process disabled when hidden._
  _Partial fix 2026-06-17: WaveManager enemy data cache (dict lookup instead of
  ResourceLoader.exists()+load() per spawn); preload now synchronous; spawn_payload
  children pre-cached. max_physics_steps_per_frame 48→12 prevents physics catch-up
  spiral at 12× time_scale. Wave receipt creation deferred one frame at wave boundary.
  Partial fix 2026-06-18: L1 min-FPS 2.0 spike was a CI measurement artifact —
  _capture_anim_clip (L1-only, 24 GPU readbacks) caused the following frame to report
  2.0 fps. Added _in_readback flag to auto_playtest.gd: _snapshot() and
  _capture_anim_clip() set it true before get_image(); _process() skips the FPS sample
  when set and clears it. Closes #975 #982 #989. The real-device FPS floor is still
  unknown — a true device profile pass remains the next step.
  Partial fix 2026-06-25: Replaced Engine.get_frames_per_second() (smoothed ~1s window)
  with 1.0/maxf(delta,0.001) (instantaneous) in auto_playtest.gd _process(). Root cause
  of L1 min-FPS 3.0 was that the engine's smoothed counter stays depressed for 15+
  frames after the 8 GPU readback stalls in _capture_anim_clip(); existing
  _readback_cooldown=3 was only sufficient to exclude 3 frames, not 15. With
  instantaneous measurement, only the actual stall frames show slow FPS and
  _readback_cooldown=3 is sufficient. Closes #1190._

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

### Visual Polish
- [x] **A-path upgrade tint: A1→A2 step unambiguously distinct (#1107)** —
  blend gap widened (A1=0.55, A2=0.82 vs previous 0.66/0.76); hue rotation
  increased 20°→28°/tier so each tier lands in a clearly different colour
  region; TierGlow ring at T2 jumps to radius=65/alpha=0.90 (was 58/0.55)
  with ring colour now tracking the tier-shifted hue. Verified 2026-06-21.

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
  Amösius: ZUNGE-RUCK (4s, 60s CD).
  _VFX done 2026-06-09. Differentiated 2026-06-09: Lemurius +2 pierce, Kühne AoE slow field (no rapid-fire), JoJo 2.5× splash radius + 3× fire, Cordula 360° cone + 3× fire, Amösius mass-freeze. All 5 are mechanically distinct._

### Added 2026-06-04 (ideate run)

- [x] **MOAB-class boss: "Selbschtbedienigs-Wage"** — self-checkout
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
  _Shipped 2026-06-12 via PR #855._

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

- [x] **"Migros-App" diegetic phone overlay (level-select skin)** —
  15 Swiss German push-notification toasts drop in every 8–12 s while
  browsing levels (Migros red panel, emoji prefix, slide-down tween).
  Cumulus balance shown in brand-red "🛒 Cumulus N ★" badge top-right.
  Always-on (no toggle needed — subtle, delightful, non-intrusive).
  _Shipped 2026-06-14: 15-entry notification carousel + Cumulus badge
  in `level_select.gd`. Swiss German "Stärn:" fix in totals badge._

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

### Added 2026-06-12 (ideate run)

- [ ] **"Brot-Stab" — petrify-line active power** — top-bar 🥖 button.
  Tap it, then drag a single stroke across the map. Every enemy whose
  position crosses the stroke within the next 3 s becomes
  "stein-Brot" (stone-bread) for 4 s: PathFollow2D `progress` frozen,
  `take_damage(...)` receives a ×2 multiplier, sprite gets a crusty
  ochre overlay + tiny wheat-ear particle. Cost **80 gold per cast**;
  unlocks at **250 Cumulus** in the Forschig menu. Hard cap: 6 enemies
  per stroke (`_petrified_this_stroke: Dictionary`) so it can't
  trivialise dense waves.

  **Impl:** new `scripts/ui/brot_stab_cursor.gd` overlay listening to
  `InputEventScreenDrag`; samples segments, calls
  `EnemyPool.get_active()`, tests
  `global_position.distance_squared_to(stroke_point) < 50²` per
  segment. Affected enemy: `set_meta("petrified_until", now + 4.0)` +
  pause `PathFollow2D` movement. `BaseEnemy._physics_process` early-
  returns when meta present; `BaseEnemy.take_damage()` reads meta and
  multiplies. Visual: `_draw()` adds a tan crust polygon overlay when
  meta is set. Cursor sprite swapped to existing `assets/icons/brot.svg`
  if present; otherwise a procedural rounded brown polygon.

  **Why it sticks:** BTD veterans expect freezes (Ice Monkey) but NOT
  player-drawn petrify lines. Pairs with [[wagli-schub]] — Wagli
  pushes, Brot-Stab freezes; together they're a tactile "two-finger
  combo" the user already has in muscle memory. Theme-perfect: the
  Migros bakery aisle as a tactical asset. Estimated ~280 LoC, no new
  art needed (use existing brot icon or draw procedurally).

- [ ] **"De Hauswart" — first dedicated support tower (Migros
  janitor)** — new tower character cost **250 gold**, T0 deals
  **zero damage on its own**. Passive AoE 200 px radius: every friend
  tower inside that radius gets `attack_speed *= 1.10` (stackable up
  to 3 Hauswarts → max ×1.30) AND every projectile fired by adjacent
  towers has a 5 % chance to spawn a tiny "Bäse" (broom) AoE on hit
  (radius 40 px, 8 damage). T1-A: bigger radius (250 px) + +15 %
  speed. T1-B: broom-proc chance 5 % → 12 %. T3 unique: every 25 s
  performs a "Bode-Wüsch" — sweeps the closest 60 px of path,
  pushing enemies back 40 px and dropping a slow-tile (-20 % speed
  for 2 s).

  **Impl:** new `resources/tower_data/hauswart.tres` with
  `damage = 0`, `range = 0` (no targeting), `attack_speed = 0`. New
  `tower_id = "hauswart"`. `BaseTower._refresh_synergies()` extended:
  Hauswarts register themselves in
  `GameLevel.hauswart_emitters` (Array[Vector2 + multiplier]); every
  other tower polls this list on placement / topology change. Sprite:
  needs one stylised side-profile portrait of a short man with a
  push-broom in green Migros apron — **escalate to image-to-image if
  the user provides a friend photo, otherwise text-to-image
  Stability** (acceptable here because Hauswart is generic, not a
  named friend). Add to `_shop_tower_ids` in `hud.gd`. Synergy with
  [[synergie-combo]]: explicit pair Hauswart + Lemurius = +1
  projectile per shot.

  **Why it sticks:** every Migros has a Hauswart; nobody notices
  them but they make everything work. Mechanical novelty: first tower
  that buffs *other* towers instead of attacking — closes the
  "support" gap in the cast roster. Composes with every existing
  tower; rewards tight clusters.

- [x] **"Selbschtskan-Schiff" — copycat punishment enemy (L8–L10)** —
  mid-level enemy that visually copies the silhouette of the **last
  friend tower placed in this run** (dark inverted sprite, magenta
  outline). HP 1,400, speed 95 px/s, 50 gold drop. **Mechanic:**
  immune to damage from that exact `tower_id` (the friend whose
  shape it copies). Forces multi-tower compositions — a player who
  only-Lemurius-spammed loses their L8 run unless they place a
  second friend.

  **Impl:** new `resources/enemy_data/selbschtskan_schiff.tres` with
  `custom_damage_immune_to_tower_id: String` field. `GameLevel`
  tracks `most_recent_tower_id`. On spawn, `WaveManager` reads it
  and assigns to the enemy via `set_meta("immune_to", tower_id)`.
  `BaseEnemy.take_damage(amount, type, attacker_id)` checks meta and
  no-ops when attacker_id matches. Sprite: silhouette pulled from
  `assets/textures/towers/<tower_id>.png` rendered black with a
  modulate `Color(0.1, 0.0, 0.1, 0.9)` + magenta outline shader.
  Debut: L8 wave 4 (intro: solo), L9 wave 7 (×3), L10 wave 6 (×5
  mixed with normal waves). Falls back to a generic camo silhouette
  if `most_recent_tower_id == ""`.

  **Why it sticks:** every BTD player has a "spam Super Monkey" muscle
  memory; this directly punishes that without being unfair. Players
  who already build mixed comps don't notice. Theme: the self-scan
  ghost-of-yourself, the shame of every Migros shopper who botched
  a barcode scan. Names: "**De Selbschtskan-Schiff hät dich kopiert.**"
  intro card via `hud.show_enemy_intro()`.

- [x] **"Coupon-Kombo" — spend-streak gold multiplier** — when the
  player spends >1000 gold within any rolling 3 s window
  (tower placements + upgrades pooled), fire a Migros-styled
  "🎫 KOMBO!" toast and set `bonus_kill_gold_mul = 1.15` for the
  next 10 s. Stacks multiplicatively with
  [[migros-bon-active-power]] — a Bon-discounted spend still counts
  toward the 1000-gold threshold AND the kombo bonus applies on top
  of normal kill gold.
  _Shipped 2026-06-21: `CurrencyManager._track_spend()` + `kombo_triggered` signal +
  `kill_gold_multiplier()` method; HUD `KomboBadge` pill with real-time countdown;
  `base_enemy` kill gold × `CurrencyManager.kill_gold_multiplier()`. ~120 LoC, no new art._

  **Why it sticks:** turns the "I just got paid → I spend it all"
  rhythm into a visible feedback loop. Currently gold accumulation is
  silent — every 100 gold disappears into a tower with no
  flourish. Kombo gives the spend itself a reward, the way Bloons TD
  gives the *kill* a reward. ~120 LoC, zero new art.

- [x] **"Pausbeleg" — diegetic between-wave receipt overlay** — during
  the 4 s breather between waves, slide up a Migros-style receipt
  paper from the bottom-right corner (250×320 px). Contents in
  monospace + dashed dividers:
  ```
  --- MIGROS AFFOLTERN ---
  Wälle 4 abgschlosse
  ------------------------
  Tower-MVP:
   1. JoJo        842 dmg
   2. Lemurius    611 dmg
   3. Kühne       402 dmg
  Find ert:        18 Feind
  Gwünne:         215 Gold
  Cumulus:          1 ★
  ------------------------
  Läbe übrig:       18 ♥
  Danke vil mal! 🇨🇭
       ✂  ✂  ✂
  ```
  Auto-dismisses on `wave_started` signal; tap to dismiss early.

  **Impl:** new `scripts/ui/hud/wave_receipt.gd` (~180 LoC) +
  `scenes/ui/wave_receipt.tscn`. Wired into `WaveManager.wave_completed`
  via signal. Needs per-tower kill+damage counters — extend
  `BaseTower` with `lifetime_damage_dealt: float` and
  `lifetime_kills: int`, reset between runs. `EnemyPool` already
  tracks per-wave kills; expose `get_wave_kill_count()`. Font: use
  existing Düridütsch monospace or `Theme.font_mono`.

  **Why it sticks:** the user has flagged "dead air between waves"
  as a P2 fix opportunity (DDT-Verwüschelig idea). Pausbeleg fills
  that dead air with a non-blocking visual joke that also delivers
  *useful* stats (which tower is carrying?). BTD has no diegetic
  stat screen — uniquely Swiss. Composes with [[hei-karte-share-card]]:
  the receipt can BE the share image if the user taps it. Estimated
  ~200 LoC + 1 scene, no new art (uses procedural styled panel +
  emoji).
  _Shipped 2026-06-15: `scripts/ui/wave_receipt.gd` — WaveReceipt Control
  slides up from bottom-right after each non-final wave. BaseTower gains
  `wave_kill_count` + `wave_damage_dealt` (reset on wave_started).
  CurrencyManager gains `wave_gold_earned` + `reset_wave_gold()`.
  Shows MVP towers (top 3 by dmg), kills, gold, cumulus, lives. Tap to dismiss._

### Added 2026-06-19 (build-content run)

- [x] **"Röschti-Bombe" — debuff-cloud enemy (L6–L10)** — golden-brown
  rösti hash with a smoking fuse. On death, drops a 110 px-radius Russ
  (soot) cloud that lingers 3.2 s and multiplies any tower-in-radius
  attack speed by 0.55 (≈45 % slower fire rate). HP 1200, speed 80 px/s,
  60 gold drop, armor 6. Forces players to consider tower placement
  *clearance from the path* in late-game waves — clustering all 5
  towers on one elbow becomes a trap. Wired into L6 wave 6+7
  (1+2 spawn), L7 wave 6 (×2), L8 wave 6 (×2), L9 wave 7 (×3),
  L10 wave 8 (×3). Multiple overlapping clouds compose
  multiplicatively (two Röschti-Bombe popping at the same chokepoint
  = ~0.30 mult ≈ one-third fire rate). Sprite is procedural (no new
  raster art per Claude-native directive). Wave-preview HUD shows
  "RÖSCHTI-ALARM!" red pulse and intro card taunt "Heiss, heisser,
  KABUMM — eui Türm chöched ab!" on first appearance. _Shipped 2026-06-19._

### Added 2026-06-18 (ideate run)

- [x] **"Banani-Lawine" — named-combo milestone bubbles** — when
  `ComboTracker.combo_count` crosses certain thresholds (10, 25, 50,
  75, 100, 150), spawn a giant Swiss-German named-combo bubble in the
  center of the play field for ~1.4 s, then fade. Tier-locked so it
  fires once per threshold per run (no spam, no overlap with
  Pausbeleg). Names are chunked into a `Dictionary` const so they're
  stealable for future modes:
  ```
  10  → "Banani-Schwarm!"
  25  → "Migros-Massaker!"
  50  → "Cumulus-Combo!"
  75  → "Aff-oltere-Apoteke!"
  100 → "Bani-Apokalypse!"
  150 → "DE TÜÜFEL CHUNT!"
  ```

  **Impl:** new `scripts/ui/combo_milestone_bubble.gd` (~120 LoC) +
  `scenes/ui/combo_milestone_bubble.tscn`. Hooks
  `ComboTracker.combo_changed`; reads
  `_fired_thresholds: Dictionary` and skips already-spawned tiers
  (cleared on `level_started`). Bubble is a `Label` centered at
  Viewport center with a `StyleBoxFlat` rounded-pill bg
  (`design_tokens.gold` for ≤50, `design_tokens.red` for >50),
  scale-pop tween 1.0 → 1.18 → 1.0 in 0.18 s, then 0.6 s hold, then
  fade-modulate 1.0 → 0.0 over 0.6 s. Sound: reuse existing
  `SfxManager.play_combo_milestone()` (pitch-ramped by tier).

  **Why it sticks:** the current combo badge is a tiny corner number —
  the spectacle the 5-year-old wants is *the moment the screen says
  AFF-OLTERE-APOTEKE*. Composes with [[hei-karte-share-card]]: the
  milestone bubble is a perfect snapshot trigger ("share when the
  bubble fires"). Zero new art; uses existing design-tokens palette.
  Pairs naturally with [[coupon-kombo]] (kombo gives gold, milestone
  gives glory).
  _Shipped 2026-06-19: `scripts/ui/combo_milestone_bubble.gd` — ComboMilestoneBubble
  Control added to HUD CanvasLayer by game_level._ready(). Hooks ComboTracker.combo_changed;
  tracks fired thresholds per-run; 0.18s scale-pop (TRANS_BACK) + 0.6s hold + 0.6s fade.
  Gold border ≤50, red border >50. `SfxManager.play_combo_milestone(tier)` — pitch-ramped
  rising sweep (330→630 Hz), overtone chord for tier ≥3._

- [ ] **"Hut-Lade" — tier-3 hat customization unlocks** — after a
  friend is tier-3'd at least once across runs, that friend unlocks
  a hat slot persisted to `user://hut_lade.json`. Long-press a placed
  tier-3 tower (~600 ms) to open a 6-hat picker overlay; tap a hat to
  swap. Initial hat roster (procedural, drawn in
  `scripts/towers/visuals/tier_hat.gd` — no new art assets):
  ```
  schwingerhut    — straw cone, Swiss wrestling
  sbb-mütze       — blue cap, white SBB logo
  alpenhorn-bow   — tiny alphorn arc bowed on head
  yodel-spike     — mountain-peak triangle
  cumulus-stern   — red Migros star, 5-pointed
  ein-kreuz       — Swiss flag white cross on red disc
  ```

  **Impl:** extend `TierHat` (already extracted to
  `scripts/towers/visuals/tier_hat.gd`) with a
  `style_id: StringName` exported var that switches `_draw()` between
  6 procedural variants. `GameManager.unlock_hat(tower_id, hat_id)`
  marks the unlock; `assign_hat(tower_id, hat_id)` writes the active
  choice; both persist via existing `save_game()` plumbing. UI: new
  `scripts/ui/hat_lade_overlay.gd` (~180 LoC) + scene; modal Control
  with 6 thumbnail buttons (drawn the same procedural way as the
  hats, at 64×64). Tap-outside or back-button dismisses.

  **Why it sticks:** flex. Pure cosmetic, but every Swiss-themed hat
  is a tiny in-joke and a screenshot vector. Closes the gap between
  "I love these characters" and "I want to dress them up". Pairs
  with [[hei-karte-share-card]] — hats appear on the share card.
  Crucially: the rendering is *procedural*, so no Stability/Gemini
  art request needed — Claude ships it directly per the
  "Claude-native design" user directive.

- [ ] **"Kassiererin Rosa" — diegetic level-select narrator NPC** —
  bottom-left corner of the level-select screen, a small (96×128 px)
  Migros cashier character idle-animates and pops contextual
  comic-book speech bubbles at quiet moments. Reactions are pulled
  from a small state machine on `GameManager` flags:
  ```
  first_level_won           → "Aaaah, du bisch eis vo de gueti Kunde!"
  5_in_a_row_lost           → "Wottsch e Schoggi näh? Gratis, gäll."
  1000_cumulus_crossed      → "Cumulus-Stamm-Kund — bravo!"
  daily_mission_done        → "Hesch das gnueg im Bonus-Päckli."
  returns_after_>3_days     → "Bisch lang nümme cho! Was nei?"
  hat_unlocked              → "De Huet stoht dir guet."
  L10_won_first_time        → "De Tüüfel hät verlore. Mier au, gell?"
  level_select_idle_45s     → "Wottsch öppis zum bschtellen? :-)"
  ```

  **Impl:** new autoload-adjacent `scripts/systems/rosa_narrator.gd`
  (~150 LoC, not a true autoload — lives on level_select.tscn only).
  Speech bubble = `RichTextLabel` with a `StyleBoxFlat` rounded-corner
  bg, 9-slice tail polygon pointing at Rosa's face. Auto-dismisses
  after 4.5 s OR on player tap. Cooldown per-line so the same line
  doesn't repeat within a session. Sprite: ONE
  text-to-image Stability call (Rosa is a generic NPC, NOT a friend
  character — friend rule doesn't apply); fallback to a procedural
  silhouette + apron if generation hasn't run yet. Output:
  `assets/textures/ui/kassiererin_rosa.png` (96×128).

  **Why it sticks:** the level-select is currently a dead grid of
  buttons. Rosa makes it a *place*. She's the persistent diegetic
  voice the game lacks — every Migros has a Rosa. Composes with
  [[tag-der-affoltern]] (she announces the daily mission with a
  golden bubble). Lazy-player engagement: even with no input, Rosa
  reacts to your run history.

- [ ] **"De Chef-Modus" — wave editor + 5-letter share codes** — a
  sandbox-adjacent mode unlocked at L5 cleared. Player composes a
  custom 8-wave run by dragging enemies from a side-shop into a
  per-wave grid (e.g. wave 3: 8 banani, 2 tofu_ninja, 1 boss). A
  one-line "Spiele!" button runs the custom wave-set on the L5 map.
  Each composition gets a deterministic 5-letter
  base32-from-hash code (e.g. `JHWBP`) shown at the top; player
  shares the code with friends, friends type it into "Code igäh"
  field to play the same gauntlet.

  **Impl:** new `scripts/systems/chef_mode.gd` autoload (~250 LoC) +
  `scenes/ui/chef_editor.tscn`. Wave-set serialized as
  `{seed_letters: "JHWBP", waves: [[{id, count}, ...], ...]}` JSON.
  Code = first 5 letters of `base32(sha1(json_str))` so dups collide
  to same code; collision-safe enough for friend-share scale. Game
  runs reusing existing `WaveManager.start_waves(custom_definitions)`
  path; no new gameplay code. UI: small grid (8 columns × variable
  rows) with drag-from-shop tap-to-add. Hard cap: 50 enemies per
  wave to keep things sane.

  **Why it sticks:** [BTD has sandbox; doesn't have shareable].
  Player creativity → shared content → replay value. Pairs with
  [[hei-karte-share-card]] (the code IS a tiny share card). Also
  closes a gap with [[daily-mission-tag-der-affoltern]]: Chef-Modus
  codes can BE the daily seed source — every day a procedurally
  picked community-shared code is "today's mission". Estimated 2–3
  audit-polish runs; ship the editor first, share-codes second.

- [ ] **"Räge & Sunne" — between-wave weather flavor layer** —
  subtle but persistent atmospheric mood: every level has a hidden
  `weather_pool: Array[StringName]` (rain, sun, fog, abendrot, snow)
  that ticks between waves. A new `WeatherOverlay` Control sits
  above the play field with very low alpha (0.18 max) particles +
  CanvasModulate shift. During the 4 s between-wave breather, a tiny
  Swiss weather forecast card slides in from top-left:
  ```
  ▒ Räge-Räge — Wälle 5 chunt mit Wasser    ☂
  ☀ Sunne — Wälle 6 chunt heiss             🥵
  ❄ Schnee — Cumulus z'verdoppelt           ★
  ```

  **Mechanical hook (optional but easy):** weather has a tiny
  multiplier baked in (rain → enemies +2 % slow on path tiles; sun
  → tower attack-speed +3 %; fog → +50 % camo enemy chance; snow →
  Cumulus drop doubled). Single-tap dismiss. Hidden until L4 (first
  4 levels stay weather-clear so the player learns base mechanics).

  **Impl:** new `scripts/ui/weather_overlay.gd` (~200 LoC) +
  `scenes/ui/weather_overlay.tscn`. Procedural particles drawn via
  `CPUParticles2D` (already in the project); CanvasModulate via
  existing `LevelData.canvas_modulate` field with a per-weather
  delta. Weather rolls once per level on first wave via
  `RandomNumberGenerator.randi_range(0, weather_pool.size() - 1)`
  using the level seed (deterministic per run). The forecast card
  reuses the Pausbeleg styling for diegetic consistency.

  **Why it sticks:** dead air between waves keeps creeping back as
  user-perceived "nothing's happening" (cf. Pausbeleg + DDT-
  Verwüschelig). Weather is the cheapest possible mood layer that
  also has tactical depth (fog → bring camo detection). Composes
  with every existing system; orthogonal to the tower/enemy roster.
  Zero new raster art (procedural particles + CanvasModulate +
  forecast emoji); minimal LoC. Theme-perfect: Switzerland literally
  has six weather types per afternoon. Pairs with
  [[ddt-verwüschelig]] (smoke bombs land harder during fog) and
  [[migros-bon-active-power]] (Bon discount could be "wether-
  themed": "Räge-Bon" = 50 % off slow towers).

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

  **Step 1 done 2026-06-12:** `_hat_script()` and `_glow_script()`
  extracted to `scripts/towers/visuals/tier_hat.gd` and
  `scripts/towers/visuals/tier_glow.gd` — both now preload()'d,
  visible to validate.sh, and parseable by godot --check-only.
  base_tower.gd: ~58 lines shorter.

  **Remaining refactor proposal (next audit-polish run):**
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

  **2026-06-12 follow-up (drift confirmed):** `hud.gd` is now **2321
  lines / 80 functions** — net **+120 lines and +5 functions in 7
  days** since the 2026-06-05 note. The refactor proposal has sat
  unstarted while the file keeps absorbing new HUD widgets (ability
  button, kombo badge plumbing, etc.). Every audit-polish run that
  touches the HUD adds another ~20 lines without extraction. **This
  is the highest-leverage refactor in the project right now** —
  next audit-polish run should pick item 1 of the extraction list
  (tower-shop-panel) as a load-bearing first cut. Estimated 2 h
  work, removes the largest merge-conflict surface in the repo.

- ~~**2026-06-12 — Autoload directory drift: 8 of 11 autoloads live
  under `scripts/systems/`, not `scripts/autoload/`.**~~ **Fixed 2026-06-13:**
  all 11 singletons now live in `scripts/autoload/`; `project.godot` updated;
  `CLAUDE.md` project-structure section corrected. No preload() references
  existed outside `project.godot` so the move was trivially clean.

- **2026-06-18 — God-object drift is accelerating, not slowing.**
  Re-measured both flagged hotspots vs. their prior notes:
  - `scripts/towers/base_tower.gd`: **1487 lines / 53 functions** —
    vs. 2026-06-04 baseline of **1188 / 39**. Net **+299 lines and
    +14 functions in 14 days**, despite the 2026-06-12 visuals
    extraction (TierHat/TierGlow) that cut ~58 lines. The file is
    absorbing new code faster than it sheds it.
  - `scripts/ui/hud.gd`: **2398 lines / 80 functions** — vs.
    2026-06-12 follow-up of **2321 / 80**. Net **+77 lines in 6
    days, same function count** — meaning existing functions are
    growing in place (longer methods, fewer extracted helpers). This
    is the worst drift signature: monotonic growth without
    decomposition.

  `scripts/ui/hud/` subdir still doesn't exist; the
  tower_shop_panel / threat_indicator / combo_overlay extraction
  list from 2026-06-05 is **0/6 done**. The total god-object
  surface in the repo now stands at **3885 lines across 2 files**,
  driving ~80 % of merge conflicts on audit-polish branches.

  **Concrete forcing-function proposal (don't read another note,
  pick this):** the next audit-polish run that touches HUD MUST
  extract `_populate_tower_shop` + `_style_shop_button` +
  `_refresh_side_shop_layout` + `_build_shop_collapse_handle` +
  `_toggle_shop_collapse` to `scripts/ui/hud/tower_shop_panel.gd`
  as a `PanelContainer` subclass. Wire it into `hud.tscn` as a
  sibling, signal-bridged to the existing hud.gd. Estimated removal:
  **~400 lines from hud.gd** in a single PR. Validate.sh runs the
  extraction headless; risk is low because shop logic is signal-
  driven (CurrencyManager + GameManager.tower_selected) with zero
  cross-coupling to threat / combo / boss-hpbar code. **If this
  refactor doesn't ship in the next 7 days, the loop should
  auto-force it on the following ideate or audit-polish run.**

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
