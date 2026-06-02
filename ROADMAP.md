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

### Ideated 2026-06-02 — Master architect batch

- [ ] **Kassa-Punkte mid-run combo shop** (BTD-inspired remix). Once
  the existing ComboTracker hits ×50, "Kassa-Punkte" begin to drip in
  (1 KP per kill while combo holds). A small fold-out panel above the
  combo badge offers three timed buys:
  - **Donnschtig-Aktion** (100 KP) — +40 % damage for 10 s on all
    towers.
  - **Gold-Sturm** (200 KP) — every enemy popped in the next 12 s drops
    2× gold.
  - **Iisrad-Wirbel** (150 KP) — freeze the nearest 5 enemies for 4 s.
  Why: turns the (currently passive) combo system into a per-wave
  decision, gives JoJo/Cordula players a panic button without adding
  a tower. Impl hint: extend `ComboTracker` autoload with KP counter +
  signal; HUD reuses TowerInfo panel chrome for the popover. Resets
  to 0 KP on game over. **Single-PR scoped.**

- [ ] **Migros-Mitarbeiter support tower** (the missing Village). New
  tower id `mitarbeiter`, cost 350 gold, no damage of its own.
  Passive aura (radius 180 px) buffs every tower in range:
  - Path A — "Lehrlig" → "Filialleiter" → "De Chef vo Affoltern":
    +10 / +20 / +35 % range to adjacent towers.
  - Path B — "Service-Cracher" → "Logistig-Profi" → "Cumulus-Gott":
    +10 / +25 / +50 % damage; T3 also converts adjacent PHYSICAL hits
    to MAGIC (cuts armor 70 %).
  Why: BTD without Village support is half the game; we already have
  unused tower slots (`farm`, `support`, `seve`) the HUD doesn't show.
  Reuse the support slot — `resources/tower_data/support.tres` becomes
  Migros-Mitarbeiter, add `_shop_tower_ids` entry in `hud.gd`. Sprite
  reuses the placeholder portrait until art-request can paint a proper
  Migros uniform.

- [ ] **Camo-Bananen + detection mechanic** (BTD camo, Migros-flavored).
  New enemy variant: plastic-wrapped banana that most towers cannot
  target. Only **Kühne** (sniper, has scope) and **Cordula** (microscope)
  see it natively. Other towers gain camo-vision when adjacent to a
  Mitarbeiter T2+ (see above) — creates a real placement puzzle.
  Spec: `resources/enemy_data/camo_banani.tres` (camo flag, 60 HP, 90 px/s),
  appears in L4 wave 6, L7 wave 4, L9 waves 3+8, L10 wave 7. Add
  `targets_camo: bool` to `TowerData`; default false; Kühne + Cordula
  set it. Tower `_find_target()` filters camo enemies unless the tower
  has detection. Visual: dim yellow tint + subtle "?" floater.
  Why: forces the player to actually use Kühne/Cordula instead of
  spamming JoJo, and gives the Mitarbeiter tower a strategic reason
  to exist beyond pure buff stacking.

- [ ] **Sandchaste-Modus** (sandbox / lazy-fantasy mode). Unlock after
  L5: a single map (re-uses L1 path) where gold starts at 99 999, no
  lives are lost, every tower deals 10× damage, all upgrades are free.
  Pure "what if I built a 5-Cordula wall" experimentation. Toggle
  "🏖️ Sandchaste" button on main menu, hidden until L5 cleared.
  Why: zero balance risk (segregated mode), maximum delight, and it's
  great content for screenshots / TikTok shares — the "screenshot-worthy"
  moment the ideate brief asked for. Impl hint: new
  `scenes/game/sandbox.tscn` extending game.tscn, sets `CurrencyManager.gold
  = 99_999`, `GameManager.lives = INF`, multiplies all tower base damage
  by 10 via a `sandbox_mode` flag on `BaseTower._fire()`. **1–2 runs.**

- [ ] **"De Chef!" MOAB-class boss** (the screenshot moment). New
  walking boss enemy: **Riccardo, de Filialleiter**, appears as the
  finale of L7 wave 10 and at L10 wave 5 mid-act. 4 000 HP, 30 px/s,
  immune to slow + freeze, carries 8 `cumulus_blob` enemies that
  release on death (BTD MOAB-style). Quotes in Swiss German speech
  bubbles every 15 s — sample: "Es git kei Bananä mehr!",
  "Ihr händ kei Cumulus-Charte!", "Mir sind eu am vermisse, Banani-Diebe!"
  Drops 600 gold + 5 Cumulus on kill. Spec: reuse
  `resources/enemy_data/boss.tres` as base, new `riccardo.tres` with
  `on_death_spawn: ["cumulus_blob"] × 8`, `taunt_lines: [...]` array
  read by base_enemy. Why: every BTD veteran will instantly recognise
  the MOAB silhouette and laugh at the Migros-store-manager remix —
  exactly the "would surprise a BTD veteran" answer the brief asked
  for. Requires the carrier-spawn architecture (see Architecture
  Notes below) to land first or get hacked in.

---

## 🔎 Architecture Notes

Dated observations from random gameplay-file audits. Each note is one
specific friction the next builder will hit; not a P0, but worth
ticking off before the codebase becomes load-bearing in painful ways.

- **2026-06-02** — `scripts/towers/base_tower.gd` is **1 179 lines**
  and `scripts/enemies/base_enemy.gd` is **827 lines**. Both classes
  now juggle pool reuse, projectile spawning, active hero abilities,
  damage-type math, upgrade flow, range-circle drawing, and tier
  cosmetics in one file. **Concrete consequence**: the "De Chef!" boss
  idea above needs `on_death_spawn` carrier behaviour — currently
  that would mean adding a 7th concern to `base_enemy.die()` and
  reaching into `wave_manager` from inside an enemy. Suggest a
  pre-work refactor PR (audit-polish mode, single file at a time):
  extract `BaseTower._fire_projectile_*()` into a sibling
  `tower_combat.gd` helper, and pull `BaseEnemy.on_death_*` hooks into
  a small `enemy_death_effects.gd` resource so we can compose
  "spawns N children", "taunt line", "drops gold X" without touching
  the base class. Until that lands, every new enemy archetype will
  push `base_enemy.gd` past 1 000 lines.

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
