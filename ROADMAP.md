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

- [ ] **L10 dedicated background** — currently reuses L1. Generate
  `level_10_finale.png` via art-request workflow.

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
- [ ] **Difficulty modes** — Eifach/Normal/Hard/Expert per level.
- [ ] **Bonus levels** — "Self-Scan-Hölli", "Banani-Träume",
  "De Tüüfel kommt heim", "Cumulus-Bingo".
- [ ] **Daily challenge** — single-attempt daily mission with
  leaderboard.
- [ ] **Active power abilities** — Wagli-Räge, Rausch-Modus combo
  frenzy.

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
