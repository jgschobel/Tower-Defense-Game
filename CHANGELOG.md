# Changelog

Running log of changes made by the autonomous dev loop. Newest first.
Each run appends one line.

## 2026-04-19 (generate-art — L4+L5 backgrounds)

- art(maps): generate level4_bg.png (D'Chäsi-Keller cheese cellar, dark stone + fondue) and level5_bg.png (D'Kasse checkout area, bright fluorescent retail) via Stability Core 16:9; wire into level_4.tscn and level_5.tscn as TextureRect Background nodes replacing ColorRect placeholders (ROADMAP P1 #4 partial)

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
