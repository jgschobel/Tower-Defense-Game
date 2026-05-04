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
  have base PNGs in main but their `.tres` files don't reference them
  via `custom_texture`. Add `[ext_resource type="Texture2D" path="..."]`
  + `custom_texture = ExtResource("N")` to each. They render as flat
  base_color circles otherwise.

- [ ] **Run enemy-damage-art for the 11 new enemies** — the
  `generate_enemy_damage_variants.py` script knows about them; just
  needs the workflow to fire (open issue with label `enemy-damage-art`
  and "all" as the title's first word). Will produce 33 damage-state
  variants (11 × 3 states).

- [ ] **Drag-and-drop tower placement** — biggest mobile UX win. Replace
  the current tap-button → tap-map flow with a held-drag that shows the
  range circle live and snaps on release. Existing
  `TowerPlacement.start_placement()` is the entry point.

- [ ] **Scrollable side-widget tower shop (BTD-style)** — replace the
  current static shop column with a right-anchored vertical strip that
  scrolls. Already partially scaffolded in `hud.gd` `_populate_tower_shop`.

### Performance (data-blocked until playtest #330 + #328 fix lands)
- [ ] **Real FPS pass** — once `playtest.yml` produces `fps.log` with
  honest 3-5 tower scenarios (commit `8e89310` ships this), audit any
  scenario reporting min FPS < 30 and address. Suspects from old data:
  L1+L3 hitches, 80-enemy stress.

### Tier-art completion
- [ ] **D1/D2 portraits for remaining 3 towers** — Cordula and Kühne
  done (#310, #311). Need `basic` (Lemurius), `splash` (JoJo), `slow`
  (Amösius). Output: `assets/textures/towers/{tower_id}_t{1,2}{a,b}.png`.

### Asset hygiene (from audit 2026-05-03)
- [x] **Delete superseded art** — 11 files with version suffixes
  (`_raw`, `_final`, `_upgrade`, `_gen`) deleted from `assets/textures/towers/`
  and `assets/textures/enemies/`. Saved ~16MB; towers/ now 30MB (was 46MB).
  Remaining `_v2.png` files kept — they ARE the active textures (priority 2
  in base_tower.gd fallback chain). `_img2img.png` files kept — active
  default in .tres files. Further cleanup needs asset_manifest audit first.

### CI / observability
- [ ] **Smarter ci-monitor** — suppress the `tsconfig.json directory
  mismatch / fd 4` post-step false-positive from
  `claude-code-action@v1`. Currently files a `ci-failure` issue every
  autonomous-dev run, draining loop quota.

- [ ] **Fix workflow-lint** — never succeeded. Either the `actionlint`
  download or the `bash -n per run-block` step has a real bug.
  Re-trigger by editing a workflow file, then check the failure log.

- [ ] **Fix drift-scan + weekly-digest** — both broken since
  2026-04-20. drift-scan would prevent ROADMAP/code drift; weekly-digest
  would email a build summary.

---

## ⚡ P1 — Important Polish & Content

### Content
- [ ] **Hero system foundation** — one Friend, one game-changer ability.
  Spec in archived roadmap, section "Game-Identity Levers". Pick
  Lemurius as the first hero with a "Doppel-Banani-Wurf" cooldown.

- [ ] **Cumulus meta-progression** — 1 Cumulus point per wave cleared,
  100 Cumulus = 1 starter perk. Spec in archived roadmap.

- [ ] **D7 Tier-3 unique death-cam effect** — 0.4s freeze + zoom +
  tower name bubble when a tier-3 tower kills the boss.

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
