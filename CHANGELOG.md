# Changelog

Running log of changes made by the autonomous dev loop. Newest first.
Each run appends one line.

## 2026-05-04 (audit-polish — enemy Swiss German consistency + art hygiene)

- polish(hud): Swiss German short names for all 16 enemy types in wave-preview panel — new enemies no longer show raw English IDs like "Cumulus_blob"
- polish(hud): distinct preview dot colors for 7 new enemy types (fondue_bomb=gold, glace_golem=ice-blue, berserker=crimson, cumulus_blob=indigo, linsen_golem=olive, smoothie_slime=green, tofu_ninja=cream)
- polish(hud): Züridütsch taunt lines for 5 missing new enemies (berserker, cumulus_blob, linsen_golem, smoothie_slime, tofu_ninja)
- chore(assets): deleted 5 orphaned tower art files (amosius_raw, cordula_final, cordula_upgrade, jojo_final, kuhne_final) — ~10.5 MB recovered, none referenced in .tres or code
- chore(roadmap): ticked "Wire 11 new enemy textures" P0 item — textures already wired in .tres files, just needed verification

## 2026-05-03 (audit-polish — shop badge + options theme + L4 path + enemy intro taunts + wave toast + level select)

- polish(hud): shop tower cost display upgraded to a coin-icon badge (dark pill + SVG coin + 13px gold label) — fixes #319
- polish(ui): options menu (Iistellige) now has a proper DesignTokens panel background + golden border (fixes #153)
- fix(level): L4 Bäckerei PathBorder changed to near-white cream, PathDraw to medium tan (fixes #320)
- polish(hud): per-enemy Swiss German taunts in first-appearance intro banner — 12 enemy types show Züridütsch taunt
- polish(hud): wave announcement "WELLE X" moved to small top-edge toast (y=68, 26pt) — no longer occludes battlefield (fixes #289)
- polish(level-select): level nodes redesigned as BTD-style 90×90 circular buttons with per-level accent colours, 5-column grid (fixes #297)

## 2026-05-03 (audit-polish — tier hat overlay)

- polish(tower): procedural crown/hat overlay at tier ≥ 1 (ROADMAP D8) — path A gets a spiky crown (3/4/5 points per tier, red gem at tier≥2), path B gets a sash/badge with 1/2/3 gold stars; pop-in bounce animation on upgrade; hat_y tracks sprite top via tier scale factor; drawn via inline GDScript in _hat_script()

## 2026-05-02 (manual session — design polish batch + dev-menu rescue + repo audit)

- fix(dev-menu): root-cause grey-screen — `DesignTokens.get(name)` and `name in DesignTokens` are invalid on a class_name (Object.get is instance-only, `in` undefined). Replaced palette tab with explicit `_resolve_palette_color() → Color` match. Added print() bracket logs and yellow heartbeat label that proves _ready ran even if downstream UI fails.
- feat(art-pipeline): v2-art priority chain in `base_tower._update_visual()` — `cordula_v2.png` / `kuhne_v2.png` / `jojo_v2.png` from art-request workflow now apply automatically (between dev-picker variant and friend-photo).
- polish(ui): replaced font-emoji icons with the existing SVG IconLibrary across HUD sell button (coin/x), main menu run-stats badge (star/sword), Aminos-Lade title + 11 row icons + check/lock/sparkle state badges. No more tofu on phones with stripped Noto Emoji.
- polish(level-select): Easy / Normal / Hard difficulty picker buttons now show colored diamond shield SVG (E=blue, N=gold, H=red) on the left edge.
- polish(placement): tower placement ghost overlay uses SVG check + x (was unicode ✓ / ✕).
- fix(ci-monitor): /actions/runs/<id>/logs API is not always populated when workflow_run fires — added 3× retry with 15-35s backoff plus `gh run view --log` fallback. Captures real log tail instead of `(no logs available)` placeholder.
- chore(repo): closed 17 stale ci-failure issues (#220-#236, #292-#301) — art-request issues were resolved when the workflow finally fixed itself; recent autonomous-loop failures were on auto-merged branches with no actionable signal.
- chore(assets): deleted 12 unreferenced enemy textures (~13 MB) — non-clean originals + retired hafer/soja/tofu/vegan/avocado experiments. All live enemies now point at *_clean.png variants.

## 2026-05-02 (audit-polish — economy balance pass)

- balance(economy): tighten starting gold L1=120→L10=220 ramp (was up to 600g bloating early game); steepen Lemurius upgrade costs ~25% [210,455,1140]/[245,560,1260]; Amösius tier2+3 +15%; fix early-wave variety L1 wave2 + L2 wave2 (closes ROADMAP #21 #22 #36 #37)

## 2026-05-02 (manual session — autonomous infra rescue + observability tools)

- fix(ci): hash-prefix every prose comment inside `run: |` blocks across 8 workflow files. Root cause of the loop being silent for 9 days (2026-04-21 → 2026-05-02) — bash interpreted unmarked prose lines as commands, exit 127, every cron-triggered run died at preflight. 80/80 run blocks now pass `bash -n`.
- fix(ci): `ci-monitor.yml` was itself failing with `could not add label: 'ci-failure' not found` — added idempotent `gh label create --force` step plus a fallback that files the issue without labels. Same pattern in `loop-health.yml`.
- feat(observability): failure log mirror — every failed workflow run now writes `docs/observability/failures/<workflow>__<run_id>.log` + appends to `failures/INDEX.md`. Chat-session Claude can read these via `mcp__github__get_file_contents` directly (no Actions logs API access).
- feat(observability): live status dashboard — `loop-health.yml` writes `docs/observability/loop-status.md` every 6h with per-workflow last-run + conclusion + last-success, open issue counters, PAUSE state, recent failure index. One file = full health view.
- feat(ci): `workflow-lint.yml` (NEW) — `actionlint` v1.7.7 + `bash -n` per `run: |` block on every PR touching `.github/workflows/`. Will block the prose-comment bug class from ever recurring.
- feat(ci): `loop-health.yml` (NEW) — every 6h watchdog. Files `loop-broken` issue if autonomous-dev hasn't run in 8h or deploy-web has no success in 24h.
- feat(ci): `pause-watchdog.yml` (NEW) — fails CI on PRs that touch `.github/workflows/` if any workflow has been `# PAUSED` for >7 days. Caught the leftover sim-gate pause comment on first run.
- feat(deploy): `deploy-web.yml` emits `build-info.json` next to `index.html` with commit SHA + timestamp + content counts. Phone-checkable build-freshness URL.
- feat(validate): `validate.sh` now runs `godot --check-only` per `.gd` file + scene-load smoke test on every level scene + main menu. Catches whole classes of bug the previous "launch and see what crashes" approach missed.
- chore(ci): cleaned stale `# PAUSED` comment from `sim-gate.yml` (triggers were already live; comment was leftover).
- chore: actually un-paused all workflows on main — previous "resume" commits had updated commit messages but never edited the trigger lines.

## 2026-05-02 (auto: audit-polish — portrait frames + L3 path + Swiss German)

- polish(towers): circle-clip shader on tower Sprite2D — all towers now render as circular portraits regardless of source texture background; fixes Joe/Justus/Seve showing as rectangular card sprites (closes playtest #148)
- polish(tower-info): circle-clip shader applied to tower info panel portrait + shop row icon TextureRect for consistent circular portrait look across all UI surfaces
- fix(L3): PathBorder/PathDraw width 50/40 → 26/18 px, alpha reduced — path overlay less intrusive on the tight W-zigzag, opening up the playfield (closes playtest #152)
- fix(i18n): tower stats panel "Kills" → "K.O." for Swiss German consistency

## 2026-04-30 (manual session — content + UX polish batch)

- feat(levels): L8 Coop-Einbruch (rival store, blue 3-aisle grid path), L9 Cumulus-Punkte-Kern (16-point spiral, purple neon), L10 Finale im Tüüfel-Äste (14-point epic finale, dark red). All three with full lore via 6-page multi-character `pages` array. MAX_LEVELS now 10 (was 7). Level select grid colours added.
- feat(story): D22 — multi-character paginated dialogue for L2-L7 intros (was legacy single-block text). Each level gets 6-7 pages with rotating speakers + guest characters Micheli (L3 security) and Trudi (L5 cashier). story_screen.gd `_LEFT_SPEAKERS` array drives portrait highlighting.
- feat(atmosphere): D17 — `CPUParticles2D` overlays per level via `game_level._spawn_atmosphere_particles()`. L2 frost / L3 flour / L4 acid bubbles / L5 confetti / L6 rain / L7 wind leaves / L8 blue sparks / L9 purple data-glitch / L10 rising embers.
- feat(vfx): D13 — dust-puff particles when each grounded enemy completes a step. Detection via zero-crossing on `sin(_walk_phase)` from negative to positive. Skips flying + slow-bobbing tank enemies. New `EffectPlayer.spawn_step_dust()`.
- fix(ux): #11 — per-tower taunt sub-pool. Each `BaseTower` instance maintains `_taunt_pool` Array, shuffled copy of `TAUNTS[data.id]`. Pop until empty, then reshuffle. Same-type towers no longer chorus the same line.
- feat(ux): #9 — gold-bordered shop row highlight while placing. `set_placing(false)` clears via `btn.get_meta('shop_base_style')`.
- feat(ux): #10 — enemy icons in next-wave preview. 22×22 TextureRect from `enemy_data.custom_texture`; colored swatch fallback for camo / lead / regrow / swarm.
- fix(F18): dynamic `ScrollContainer.scroll_deadzone` — 0 for `InputEventMouse`, 12 for touch. Fixes mouse click-through that the touch-fix accidentally regressed.
- docs: ROADMAP — D17, D20, D22, D23, F18, #5, #7, #8, #9, #10, #11, #13 ticked. Levels 8/9/10 content items closed.

## 2026-04-20 (audit-polish — P0 playtest fixes: backgrounds, enemies, main menu)

- fix(backgrounds): all 7 levels now use maps_v3 AI-generated art via Sprite2D at (640,360); L4 CellarTiles + L6 FloorPattern seam nodes removed; closes #147 #140 #149 #142
- fix(enemy): enemy_pool.gd sets e.data before add_child so _ready() applies texture immediately; base_enemy.reset_for_pool() calls _update_visual() after _apply_data() for pool reuse; closes #141
- fix(main-menu): added dark BG ColorRect as first child so menu is never blank-white; closes #146 #139
- fix(playtest): auto_playtest.gd waits 0.5s before menu screenshot instead of 1 process_frame (was capturing before renderer completed)

## 2026-04-20 (audit-polish — L6 balance + level-select star glyphs)

- balance(level): L6 "S'Parkhuus ★" rebalanced — starting_gold 1500→1800 (matches L7), all wave counts reduced ~25% so the bonus level is clearly easier than the L7 finale; wave-1 swarm dropped 60→30; description updated to mention bonus-challenge nature; closes ROADMAP balance item #15
- polish(ui): level_select _stars_text now uses real Unicode star glyphs ★/☆ instead of */- (comment already said "Unicode stars" but code still used ASCII)

## 2026-04-19 (self-improve — placement toast clears on cancel)

- fix(placement): toast now dismisses immediately when placement is
  cancelled (HUD cancel button, invalid drag-drop, focus-out, or
  re-entry). Previously the "Z'nöch am Wäg!" / "Z'nöch am Turm!" /
  "Am Rand bleibe!" label lingered through its 1.6s fade even after
  the error context was gone — visible in playtest shots 096 vs 097
  (pixel-identical toast 0.35s after cancel). New `HUD.clear_toast()`
  is wired to `TowerPlacement.placement_cancelled` and also reused
  inside `show_toast()` (the old inline dedup loop was duplicated).
  Closes playtest-feedback #104.

## 2026-04-19 (evening close-out — bug batch + audit round 4 + perf/ux polish)

- feat(roadmap): perf+ux+sfx batch — tier-pip geometry cache, healer
  redraw per-enemy jitter, taunt throttle during `is_spawning`,
  cost amber %-based threshold, instant ghost on selection,
  boss_roar + life_lost procedural sweeps wired into celebration
  and flash paths (PR #117)
- fix: agent audit 30-item systematic review — 12 bugs fixed,
  18 perf/ux/idea items filed into ROADMAP. Source-tower meta
  cleared on pool release, splash kills now credit source,
  drag-from-shop tap race via `_fresh_placement` flag, taunt
  Timer named + idempotent, enemy-intro responsive width,
  tower-info re-clamp post-upgrade, resize tears down stale
  overlays, boss HP bar respects inset_top, boss-shake debounce,
  celebration reparent to scene, warmup auto-discovery (PR #116)
- fix: audit round 4 — tier pips now above pedestal (were hidden
  in shadow), toast dedup via group (queue_free race cleared),
  collapsed SideShop hides scroll contents, shop toggle 22→36px,
  L6 display-name renamed to "S'Parkhuus ★", taunt edge clamp,
  drag-drop invalid-drop auto-cancels (PR #115)
- fix: single-toast policy + robust playtest observability commit
  (snapshot-reset replaces fragile `git checkout main` dance) (#113)
- docs: README / CLAUDE / CHANGELOG / ROADMAP / audit notes refresh
  (PR #114)
- feat: Level 7 "S'Dach vo de Migros" + tier pips + boss-kill
  celebration (3× sparks + shake + "TÜÜFEL GSTÜRZT!" text) (PR #109)
- feat: Level 6 "S'Parkhuus" bonus stage (5-boss finale, 16-point
  serpentine path) + enemy drop shadows (PR #100)
- Force playtest trigger via project.godot direct-push after
  concurrency lock suspected for push events (commit f65c3146)

## 2026-04-19 (afternoon session — side-shop sprint + audits)

- feat(hud): BTD-style side-shop refactor in 3 PRs (#110 scene + populate,
  #111 per-row StyleBox + affordability visuals, #112 collapsible handle
  + responsive width) — shop now right-anchored scrollable widget with
  per-friend tint, whole-row dim on unaffordable, ▶/◀ collapse toggle
  with 0.22s cubic slide, width clamped `[136, 190]` by viewport.
- fix: single-toast policy — rapid-fire invalid placements no longer
  stack frozen "Z'nöch am Wäg!" labels (playtest-feedback #104) (#113)
- fix: playtest observability commit robustness — snapshot-and-reset
  approach replaces the fragile `git checkout main` dance that was
  silently eating the commit (#113)
- feat: Level 7 "S'Dach vo de Migros" + tier pips + boss-kill
  celebration (#109). MAX_LEVELS 6 → 7. Tier pips draw colored dots
  around tower pedestal showing upgrade tier at a glance.
- feat: Level 6 "S'Parkhuus" bonus stage — 5-boss finale, 16-point
  serpentine path, enemy drop shadows (#100). MAX_LEVELS 5 → 6.
- fix: audit round 3 — hide/show flash on tower re-tap, screen-shake
  concurrency guard, options-menu double-instance guard, focus-loss
  ghost cleanup, CLAUDE.md cleanup (duplicate Pitfalls removed,
  9-autoload list, correct UI file list) (#108)
- fix: deep-audit mega-batch — pause-menu Godot 3 API crash,
  drag-drop tap-to-buy regression, star save/load key inflation,
  boss HP bar NaN guard, HUD WaveManager group-lookup robustness,
  swarm scale 0.9 → 1.4, L6 balance 1100 → 1500g + 5 → 4 bosses (#107)
- feat: per-tower kill counter — projectile credits source tower on
  kill, shown on tower-info stats line (#102)
- feat(ux): persistent stats badge on main menu + level select
  (★ / ☠) + "Wälle gschafft!" celebration between waves (#97)
- feat: drag-and-drop tower placement + tower-meme taunts
  ("BIO BANANE!" / "LOTTO!" / "ATSCHII!") + tower pedestal/shadow
  polish + Level 2 pretzel path (#99)
- feat: Level 5 "D'Kasse — Endkampf" + wave progress bar +
  tower-info viewport clamp (#87)
- feat: Level 4 "D'Chäsi-Keller" + chapter 4 lore + MAX_LEVELS 3→4
  (#84)

## 2026-04-19 (morning)

- fix(perf): pool PROCESS_MODE_DISABLED propagates to children (ProgressBar + Area2D no longer processed while idle); enemy pool size 60→100; wave_manager preloads enemy .tres resources at setup_waves() to eliminate L1 wave-1 freeze; upgrade tints more saturated for Lemurius/Cordula so tiers are visually distinct (closes #71 #72 #73)

## 2026-04-18

- feat(observability): workflows commit results to `docs/observability/` — chat-session Claude can now Read ledger.md, playtest_latest.md, sim_latest.md, deploy_latest.md instead of guessing at workflow state (PR #62)
- fix(audit-batch): 7 CRITICAL+HIGH findings — healer signal leak on pool reuse, safe-area idempotency guard, tower-info auto-hide on tap-outside, spawn-children bounds check + validation, pool race with pooled-meta flag, double-release guard in both pools, healer heal-radius via progress-delta not global_position (PR #60)
- fix(photo): Stability-first generator order + diagnostic step — issues #24/25/26 were stuck because Gemini model renames made Gemini-first unreliable; Stability (paid, known-good) now primary, Gemini bonus fallback (PR #59)
- perf(pool): enemy object pool — pre-allocated 60 instances, acquire/release API with pooled-meta flag, reset_for_pool resets all runtime state; closes #45 #52 (PR #57)
- perf(pool): projectile object pool — 40 pre-allocated, reset_for_pool clears transient state, base_tower uses acquire with instantiate fallback (PR #56)
- fix(ci): auto-merge with `--auto` flag + playtester 60s window at 4× time_scale + stress scenario proper signal wiring + L1 texture preload in GameManager (PR #55)
- fix(game): upgrade tint strength formula 0.55/0.80/1.00 per tier (was 0.20/0.40/0.60 invisible) + enemy PathFollow2D v_offset/h_offset stagger for visual distinction (PR #54)
- feat(gameplay): DamageType enum finally applied in base_enemy.take_damage — PHYSICAL full armor, MAGIC 70% bypass, PURE ignore; color-coded damage numbers; spawn_delay MIN_DELAY 0.35s floor fixes stacking at spawn; 1% Juice Pass — pop SFX pitch by enemy health, +50% starting gold, tower sprite ±35° rotation, victory 2s hold, ✦ mini-floater on every hit (PR #43)
- fix(photo): Gemini model candidate fallback + auth header for user-attachments URLs + always-comment-on-failure so issues stop going silent (PR #42)
- polish(mobile): all HUD buttons ≥ 52px touch targets; PauseButton 60px; safe-area margins via DisplayServer.get_display_safe_area() for notched phones; TowerInfo panel taller for new button sizes (ROADMAP P1 #34 #35 #36); ticked 10 completed ROADMAP items that were shipped in #43 but never checked off (PR #44, via loop)
- docs(roadmap): 5 new spec'd ideas — Migros-Cumulus meta-progression, "De Chef!" boss finisher, Rausch-Modus combo frenzy, Züri-Tram MOAB boss, Wagli-Räge active power; architecture note on wave_manager spawn-stacking root cause
- polish(placement): invalid placement toast ("Z'nöch am Turm!" / "Z'nöch am Wäg!" / "Am Rand bleibe!") with tween fade-out (ROADMAP P0 #24); health bar smoothly tweens over 0.2s on damage (ROADMAP P1 #41)

## 2026-04-17

- chore(validate): removed orphaned root main.tscn (empty bare Node2D, unreferenced); full signal/resource/scene audit passed clean
- polish(hud): tower cost label turns red when unaffordable, gold when affordable (ROADMAP P0 #28)
- Set up autonomous dev loop (GitHub Actions, 6h cron, 4 rotating modes)
- Added ROADMAP.md as the shared task list for the loop
- Fix(tower): JoJo splash can now target flying enemies (ROADMAP P0)
