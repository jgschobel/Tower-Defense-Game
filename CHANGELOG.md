# Changelog

Running log of changes made by the autonomous dev loop. Newest first.
Each run appends one line.

## 2026-04-19

- polish(boss+audio): boss spawn screen-shake (amplitude 14, 0.7s) + low-rumble SFX (90→28 Hz + 220→80 Hz); is_boss field on EnemyData; master volume slider in options menu via AudioServer.set_bus_volume_db; tick stale ROADMAP items (story screen, monster intro, enemy bobbing, options menu, boss SFX/shake) (closes #42 #54)
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
