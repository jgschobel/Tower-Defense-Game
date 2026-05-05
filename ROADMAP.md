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
- [ ] **Hero system foundation** — one Friend, one game-changer ability.
  Spec in archived roadmap, section "Game-Identity Levers". Pick
  Lemurius as the first hero with a "Doppel-Banani-Wurf" cooldown.

- [ ] **Cumulus meta-progression** — 1 Cumulus point per wave cleared,
  100 Cumulus = 1 starter perk. Spec in archived roadmap.

- [x] **D7 Tier-3 unique death-cam effect** — 0.4s bullet-time (Engine.time_scale
  0.05) + 4-burst gold/white spark explosion + "✦ [Tower Name]" floating name bubble
  above the killing tower. Shipped 2026-05-05 via effect_player.tier3_boss_kill().

- [ ] **Per-path projectile tier skins (D4)** — Lemurius normal banana
  → big banana → khaki missile. Pollen → icy flower → fire lily. Etc.

- [ ] **L10 dedicated background** — currently reuses L1. Generate
  `level_10_finale.png` via art-request workflow.

### Workflow / discipline
- [ ] **PR template with verify-checklist** — forces author to confirm
  "did you read asset_status.md? does this affect playtester signal?"
  before opening.

- [ ] **`session-opener.yml`** — daily 03:00 UTC workflow that writes
  `docs/observability/session_brief.md` (open PR count, P0 head item,
  ci-failures, last deploy). Chat-session reads this BEFORE doing
  anything.

- [ ] **Branch protection on main** with required CI checks
  (`validate.sh`, `workflow-lint`, `playtest`). Makes
  `gh pr merge --auto` actually wait for green CI.

- [ ] **Autonomous-loop killswitch** — if 3 consecutive autonomous-dev
  runs fail, the next run pauses and instead opens a `loop-broken`
  issue. Prevents runaway broken loops.

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
