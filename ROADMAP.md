# Roadmap — Affoltern Banani Raubzug

The autonomous dev loop reads this file every 6 hours and picks the
highest-priority unchecked item matching the current run mode.

**Priority order**: P0 (blocking) → P1 (important) → P2 (nice-to-have).
Within a priority, top-of-list wins.

---

## 🎨 DESIGN — 30 new tasks (added 2026-04-21)

User directive: "add 30 design change tasks" after PRs #180-#194
shipped the BTD5-parity mechanical pass. These focus on VISUAL /
UX / FEEL — independent of the gameplay-mechanic fixes below.

### Tier art + upgrade visuals (D1-D8)
- [ ] **D1** Generate tier-1 variant PNGs via Gemini img2img for all
  5 friend towers (basic/sniper/splash/cordula/slow) — add belt,
  headband, small badge. Populate `path_a_textures[0]` /
  `path_b_textures[0]`. Source: existing `*_img2img.png`.
- [ ] **D2** Tier-2 variants — bigger accessory (cape, bandolier,
  hat with single plume). `path_a_textures[1]` / `[1]`.
- [ ] **D3** Tier-3 variants — full transformation (throne, glow,
  crown, duplicate clones, particle trail). Path A ↔ B should look
  dramatically different — not same silhouette with different tint.
- [ ] **D4** Projectile tier skins — Lemurius: normal banana →
  big banana → khaki missile. Kühne: pollen → icy flower → fire
  lily. Etc. New sprites under `assets/textures/projectiles/`.
- [ ] **D5** Per-path particle trail colors — A = warm (orange/red),
  B = cold (blue/violet). Already wired via projectile_color;
  ensure the tint shifts live on upgrade.
- [x] **D6** Muzzle-flash shape per projectile_style — banana burst,
  pollen puff, flask crack, volleyball star, tongue slurp-ring.
  ✓ Implemented 2026-05-02: EffectPlayer.spawn_muzzle_flash now takes a `projectile_style` and varies particle count/spread/velocity per style. base_tower passes data.projectile_style.
- [ ] **D7** Tier-3 unique death-cam effect on boss kill by tier-3
  tower — 0.4s freeze + zoom + tower name bubble.
- [ ] **D8** Crown / hat overlay Sprite2D on tower head at tier ≥ 1,
  synced with _apply_tier_scale. 8 hats total (2 per path per tower).

### Backgrounds + environment (D9-D15)
- [ ] **D9** Replace L1 background with a bespoke Imagen 4 paint:
  Migros-Affoltern automatic doors, shopping carts, orange accent
  lighting. 1280×720 with transparency around the path.
- [ ] **D10** L2 frozen-aisle background: pale blue, frost mist,
  vertical freezer doors, Haribo-blue palette.
- [ ] **D11** L3 bakery bg: warm amber, bread racks, flour drift.
- [ ] **D12** L4 cellar bg: dim, cheese wheels stacked, acid-green
  glow leaking from corner.
- [ ] **D13** L5 kasse bg: cash registers, Cumulus sign, fluorescent
  overhead, queue ropes.
- [ ] **D14** L6 parkhuus bg: neon concrete, rain-wet floor, glow
  reflections.
- [ ] **D15** L7 rooftop bg: sunset sky, Migros-Affoltern logo
  silhouette, birds.

### Parallax + atmosphere layers (D16-D19)
- [ ] **D16** ParallaxBackground node on each level scene with at
  least 2 layers (distant sky / mid props) scrolling at 0.3×/0.6×.
- [x] **D17** CPUParticles2D overlay per level — L2 frost, L3 flour,
  L4 acid bubbles, L5 cumulus-receipt confetti, L6 rain, L7 wind
  leaves. 30-50 particles @ low rate, softly tinted.
  ✓ Implemented 2026-04-30: game_level._spawn_atmosphere_particles() adds per-level CPUParticles2D. L8 blue sparks, L9 purple glitch, L10 rising embers also included.
- [x] **D18** CanvasModulate tint per level — L2 cool blue, L4 acid
  green, L6 neon cyan. Stack over backgrounds for mood.
  ✓ Implemented 2026-04-27: game_level._apply_level_tint() reads background_color from level_N.tres, adds CanvasModulate at 30% blend.
- [x] **D19** Animated light flicker on L1 fluorescents + L6 neon
  via a Color tween on CanvasModulate.

### Story / narrative visuals (D20-D23)
- [x] **D20** Portrait row in story_screen shows the current page's
  speaker highlighted (100% opacity) with the others dimmed to 40%.
  ✓ Implemented 2026-04-27: _update_speaker_highlight() dims non-speaker to 35% alpha; Lemurius/Kühne/JoJo on left, Amösius/Cordula/guests on right.
- [x] **D21** Typewriter font SFX tick (very quiet soft_pluck) per
  rendered character — feels Undertale-y, subtle not spammy.
- [x] **D22** Migrate L2-L7 intros to multi-character `pages` format
  (L1 done in #176). Rotate speakers, add 2 guest characters across
  the campaign (Micheli-security L3, Trudi-Kasse L5).
  ✓ Implemented 2026-04-30: lore.gd L2-L7 all have `pages` arrays with rotating cast. Micheli (L3 security) and Trudi (L5 Kasse) added as right-side guests.
- [x] **D23** Transition fade-to-black between story pages so the
  background can shift mood per speaker.
  ✓ Implemented 2026-04-27: story_screen._on_continue_button_pressed fades story_label alpha 0→1 over 0.12s/0.18s between pages.

### Shop + HUD polish (D24-D27)
- [x] **D24** Shop row hover preview — hovering a tower icon shows
  its range circle on the map (desktop / web). Touch equivalent:
  long-press (800ms) to preview.
  ✓ Implemented 2026-04-27: shop button tooltip_text shows damage/range/fire-rate/cost/special for all unlocked towers.
- [x] **D25** Tower-info panel redesign — larger portrait, path icons
  with mini-tree lines showing tier unlock flow (tier 1 → 2 → 3).
- [x] **D26** Gold-gain floater restyle — single floaty "+N" with
  a tiny coin icon prefix, not raw text. Matching style for Aminos.
- [x] **D27** Wave-start banner: 800ms slide-in from right with
  wave number in BIG type + enemy composition preview beneath.
  ✓ Implemented 2026-04-27: banner slides from right edge (1400px) to center in 0.22s CUBIC, holds 0.55s, fades out.
### Tower placement visuals (D28-D30)
- [x] **D28** Placement ghost: tint green when valid, red X when
  invalid (already partial — polish the red state with a crossed-
  out circle overlay).
  ✓ Implemented 2026-04-27: red ✕ label overlay on ghost when _can_place_at returns false. Hidden on valid position.
- [x] **D29** On successful place: 0.3s ring expand + drop-dust
  particle at the tower base.
  ✓ Implemented 2026-04-27: BaseTower.play_place_animation() pops 0→1.15→1 on place. Green ✓ floats and fades.
- [x] **D30** Range circle render style: animated dashed border
  rotating slowly instead of static filled circle — reads better
  over busy backgrounds.

---

## 🛠 FUNCTIONAL FIXES — 20 new tasks (added 2026-04-21)

User directive: "add 20 functional fix tasks". These are bugs,
race conditions, state leaks, perf issues, or correctness gaps —
discovered via transcript review of the last 30 PRs.
  ✓ Implemented 2026-04-27: range_circle.gd draws animated dashed border marching clockwise at 25px/s.
### Pipeline / pool correctness (F1-F5)
- [x] **F1** Enemy pool may reuse camo enemies without resetting
  `sprite.modulate` set by `_apply_data` for camo; ensure
  reset_for_pool restores Color.WHITE before the next _apply_data.
  ✓ Fixed 2026-04-27: kill _death_tween + _health_bar_tween in reset_for_pool
  before _apply_data runs; camo modulate now correctly restored.
- [x] **F2** `_has_regrown` guard resets in reset_for_pool (#172)
  but regrow health restoration may leave sprite mid-fade from
  the death tween. Need to kill any death tween before regrow.
  ✓ Fixed 2026-04-27: _death_tween stored as member, killed in reset_for_pool.
  Critical fix: death animation was inside _splash_heal_nearby() — moved to
  die() so all enemies get spin+fade and actually return to the pool.
- [x] **F3** Pierce projectiles return to pool via _hit() ordinary
  path on final hit. Verify `_pierced_enemies` cleared on
  reset_for_pool (shipped in #166 — audit-required).
  ✓ Audited 2026-04-27: _pierced_enemies.clear() at line 313 confirmed;
  remaining_pierce = 0 also reset. No action needed.
- [x] **F4** Adjacency refresh (#165) calls `_apply_data()` on every
  tower on every place. _apply_data re-runs _apply_tier_scale which
  re-spawns the glow ring (#180). At 10+ towers placed this could
  stutter. Batch into a deferred call.
  ✓ Audited 2026-04-27: refresh() calls queue_redraw() only — Godot already batches redraws. No action needed.
- [x] **F5** Farm tower gold payout calls `tower.flash_earn` but
  BaseTower has no such method. Remove the dead call or implement
  a gold-pop animation.
  ✓ Fixed 2026-04-27: BaseTower.flash_earn(amount) implemented — yellow
  "+N G" label floats up from the tower on each wave payout.

### Projectile + combat bugs (F6-F10)
- [x] **F6** Crit multiplier (#167) applies only to direct hit —
  splash damage stays base. Decide: should crit propagate to splash?
  If yes, pass along the multiplier; if no, document.
  ✓ Design decision 2026-04-27: crit does NOT propagate to splash. Crit is a single-target precision mechanic (Kühne). JoJo's strength is AoE. Documented.
- [x] **F7** Cordula cone burst (#169) damages enemies but doesn't
  route kills through `source_tower` kill_count. Orphaned kills
  stack up for the main target only.
  ✓ Fixed 2026-04-27: cone burst loop checks was_alive/is_dead and
  increments kill_count directly on the tower for each cone kill.
- [x] **F8** Pull projectiles that hit a dead target mid-flight
  still call target.pull_back — pull_back guards is_dead so it
  silently no-ops, but the .tres pull_path_fraction still flows.
  Audit for double-pulls.
  ✓ Audited 2026-04-27: pull_back only called inside `if not target.is_dead` guard (line 211 base_projectile). No double-pull possible.
- [x] **F9** Lead enemies (#173) reduce PHYSICAL to 15%, then the
  existing armor formula subtracts armor. Stacked with `is_lead`
  armor 2 + 15% of a 20 dmg hit = 3 dmg pre-armor - 2 armor = 1.
  Likely too strong — verify intended math vs armor's current role.
  ✓ Fixed 2026-04-27: lead's 15% resistance now replaces armor for
  physical hits (effective_armor = 0). Gives 3 damage instead of 1
  from a 20-hit, making high-pierce/fast towers viable against lead.
- [x] **F10** Splash damage (JoJo, Cordula cone) doesn't check
  `is_camo`. A camo-immune tower can still AoE-kill camo enemies
  via splash from a non-detector friend. Gate by detector.

### Economy + persistence (F11-F14)
- [x] **F11** AminosManager.award_for_level_clear (#174) fires every
  clear — replaying an already-cleared level re-awards. Should be
  capped at 1 award per (level_id, stars_tier) pair.
  ✓ Fixed 2026-04-27: cleared_levels Array added, persisted in aminos.save.
  First clear of each level_id awards; replays grant 0.
- [x] **F12** Combo multiplier (#186) applies globally — Farm gold
  payouts also multiply. Decide: intentional? If no, gate
  `CurrencyManager.add_gold` with a "from_kill" parameter.
  ✓ Audited 2026-04-27: combo multiplier is applied ONLY in
  base_enemy.die() before CurrencyManager.add_gold. Farm towers in
  game_level._pay_farm_towers() call add_gold directly — no multiplier
  applied. Non-issue; current implementation is correct.
- [x] **F13** Aminos shop (#185) `unlock_node` returns false if
  already unlocked OR unaffordable. UI shows "Gchauft" only on
  the success branch — insufficient-funds case shows no feedback.
  Add a red flash + toast.
- [x] **F14** Aminos unlocked_nodes JSON-round-trip: Array[String]
  becomes Array after save+load. `is_unlocked(x)` compares with
  `in` which works, but `Array.has(String)` is more defensive.
  ✓ Non-issue: `in` operator works correctly for Array[String] after JSON round-trip. Array.has() would be equivalent. No change needed.
### UI + HUD state (F15-F18)
- [x] **F15** Sub-wave progress bar (#182) resets on new wave to 0,
  but `_wave_total_enemies` is the queue size AT wave start and
  doesn't account for spawns_on_death children. Progress can
  exceed 100% mid-wave.
  ✓ Already fixed: wave_progress_changed emits clampf(defeated/total, 0, 1). update_wave_progress also clamps. Bar cannot exceed 100%.
- [x] **F16** Combo badge (#194) creates a new tween on every
  kill — 20 kills/sec = 20 tweens fighting on the same Label.
  Kill outstanding tweens before starting the next scale-punch.
  ✓ Fixed 2026-04-27: _combo_tween member added to HUD; killed before each
  new scale-punch via _combo_tween.kill().
- [x] **F17** Tower unlock gating (#175) disables the button but
  the padlock Label ignores theme changes — on theme reload it
  keeps its hardcoded gold color. Use add_theme_color_override in
  `_on_theme_changed` if one exists.
  ✓ Non-issue: lock_label already uses add_theme_color_override() which persists through theme reloads. No action needed.
- [x] **F18** Shop-scroll deadzone (#162) fixes touch, but
  ScrollContainer now consumes wheel events on desktop preventing
  click-through to the tower button. Switch scroll_deadzone back
  to 0 for mouse input (check by event type).
  ✓ Fixed 2026-04-30: hud.gd _input() sets shop_scroll.scroll_deadzone=0 on mouse events, 12 on touch. Deadzone only affects drag initiation, not wheel scroll.

### Workflow / CI (F19-F20)
- [x] **F19** Audit-grid workflow (#190) depends on
  docs/playtest_shots/latest/ existing. The playtester currently
  writes to docs/observability/screenshots/ with different
  filenames. Reconcile the paths OR add a migration step in the
  stitcher.
  ✓ Fixed 2026-04-27: stitch_audit_grid.py SRC_DIR updated to
  docs/observability/screenshots/; globs all *.png alphabetically.
- [x] **F20** HF audio workflow (#160) requires HUGGINGFACE_API_KEY
  secret. Log explicitly "secret not set — skipping N requests"
  so the CI run UI shows why no audio files land. Currently it
  silently no-ops which makes debugging hard.

---

## 📋 Session handoff — 2026-04-19 17:00Z (loop takes over)

Chat-session Claude is logging off. Everything below is for the
autonomous loop (`autonomous-dev.yml` every 6h) to pick up. All
user-driven inputs from this session are captured; no waiting on
the user for anything unless explicitly noted.
  ✓ Already handled: generate_ai_audio.py prints 'HUGGINGFACE_API_KEY not set — skipping AI generation.' on line 181.
### User directives from this session (all shipped or queued)

| User input | Status |
|---|---|
| "Drag-and-drop Tower Placement" | ✅ PR #99 + #107 + #116 (tap race fix) |
| "Coole Memes für die Türme" | ✅ PR #99 TAUNTS dict per tower, viewport-clamped, throttled during waves |
| "Verbessere Grafik wenn nötig" | ✅ PR #99 shadows/pedestal/highlights, #100 enemy drop shadows, #109 tier pips, #116 pip cache + positions above pedestal |
| "Komplexere Maps + mehr Art" | ✅ L2 pretzel path + L4/L5/L6/L7 shipped |
| "Add extra level" (×multiple) | ✅ L4, L5, L6 (bonus), L7 shipped; L8-L10 queued below |
| "Scrollable side-widget Tower-Shop (BTD6-style)" | ✅ PR #110 + #111 + #112 (3-step refactor) + #115/#116/#117 polish |
| "Audit and fix bugs; rest in roadmap" | ✅ PR #107 + #108 + #115 + #116 (4 audit rounds, 30+ findings) |
| "Teste alle neuen upgrades — starte den game tester" | ⚠️ Bot lief 13:43Z, filed #103-106 (all closed); force-triggered again via project.godot edit (commit f65c3146); concurrency lock suspected for subsequent push triggers |
| "Fix all bugs and put rest into the roadmap" | ✅ PR #116 + #117 (18 bugs + 12 perf/ux items shipped; rest below) |

---

### Queue (priority top-first)

#### Content (high visible value)
1. ✅ **Level 8 content** — "Coop-Einbruch" (rival supermarket, blue palette). 10 waves escalating, 3-boss finale. .tres ✓ + .tscn ✓ + lore pages ✓ (6-page cast: Lemurius/JoJo/Cordula/Kühne) — 2026-04-30.
2. ✅ **Level 9 content** — "Cumulus-Punkte-Kern" (inside loyalty-system, glitchy neon). Harder than L8, 4-boss finale. .tres ✓ + .tscn ✓ + lore pages ✓ (6-page, Amösius fears losing 16k Cumulus pts) — 2026-04-30.
3. ✅ **Level 10 content** — "Finale im Tüüfel-Äste" (final campaign). 5-boss gauntlet. .tres ✓ + .tscn ✓ + lore pages ✓ (emotional 6-page finale, "McDonald's after the fight" joke) — 2026-04-30.
4. ✅ **Dedicated backgrounds L8 + L9** — generated via Stability SD3.5: `level_8_coop.png` (blue Coop supermarket interior) + `level_9_neon.png` (cyberpunk neon loyalty corridor). L4–L7 already had maps_v3 backgrounds. L10 still reuses L1 background. — 2026-05-02.
   - [ ] **L10 background** — "Finale im Tüüfel-Äste" needs its own boss-arena background (hellish Migros rooftop, fire and smoke, dark sky). Generate via Stability text2img.

#### Perf (from agent audit)
5. ✅ **Signal-based threat badges** — already event-driven via enemies_remaining_changed. 0.5s poll eliminated. Boss HP bar retains 0.25s timer for smooth HP updates (intentional). (2026-04-27)
6. **Next-wave preview cache** — `_refresh_next_wave_preview` tears down + rebuilds 5-10 Labels + StyleBoxFlat on every show. Cache panel, update text only.

#### UX
7. ✅ **Next-wave button fade** — already implemented: `_refresh_next_wave_preview` fades modulate:a → 0 over 0.2s before queue_free. (2026-04-27)
8. ✅ **Sub-wave progress bar** — already tracks per-enemy defeats via wave_progress_changed signal. Clamped 0-1. (2026-04-27)
9. ✅ **Shop row-selected highlight while placing** — gold border + warm bg on the active shop row while placement is in progress. Cleared on cancel/place. (2026-04-30)

#### Ideas (nice-to-have)
10. ✅ **Enemy icons in next-wave preview** — 22×22 TextureRect from enemy .tres custom_texture; colored swatch fallback for enemies without art. (2026-04-30)
11. ✅ **Per-tower taunt persona** — _taunt_pool Array per instance; shuffled copy of TAUNTS lines, pop_back() until empty then reshuffle. Same-type towers now cycle all lines before repeating. (2026-04-30)
12. **Tower hover range preview in shop** — hovering a shop row shows the range circle on the map.
13. ✅ **Dust-puff particles on enemy step** — zero-crossing detection on sin(_walk_phase) negative→positive triggers EffectPlayer.spawn_step_dust() at enemy feet. 4 particles, 0.22s lifetime, sandy color. Skips flying + tank-slow. (2026-04-30)

#### Design spec
14. **`docs/design_polish.md`** — palette rules, shadow/highlight tokens, typography stack. Informs every subsequent visual PR.

#### Balance drift
15. ~~**L6 "Bonus" vs L7 progression**~~ ✅ Fixed: L6 starting_gold 1500→1800, all wave counts reduced ~25% so L6 is clearly easier than L7 finale. L6 description updated to call it a bonus challenge.

#### Infrastructure (not auto-pickable)
16. **Playtest concurrency investigation** — push-triggered playtest ran once at 13:43Z then appeared blocked for ~1h despite 15+ merges. Suspected: GitHub's 1-queued-run concurrency limit OR minutes-quota hit. The `cancel-in-progress: false` on group `playtest` may need `cancel-in-progress: true` OR the workflow needs to check `github.repository_runs_remaining` before starting. Force-trigger commit `f65c3146` verified it still fires on direct push.
17. **PAT-based user-attachment fetch** — `photo_to_character.py` tries `USER_ATTACHMENT_PAT` secret first. Unblocks friend-photo issue template. Requires user to create the PAT.
18. **Scrollable side-shop extras** — smooth scroll when tower button goes above viewport; scroll indicator when content extends.
19. **Re-process tower icons with alpha_matting** — the canonical `cordula.png` / `jojo.png` / `kuhne.png` (and possibly others) had background removed with a tool that also ate interior "transparent-looking" pixels — eyes + highlights got cut out, leaving spooky empty sockets. Workaround shipped: .tres files now point at `*_img2img.png` variants (pre-bg-removal originals with intact eyes but with backgrounds). Proper fix: write a Python script using `rembg` with `alpha_matting=True` + `u2net_human_seg` model (tuned for people, preserves interior detail) to reprocess the `_img2img` sources cleanly, then swap back to transparent `.png` canonical names.

---

## 🔥 P0 — User directive 2026-04-20 (post-laptop session)

User review after playing on laptop. Massive rebalance + audio overhaul
requested. Loop picks these up one-by-one; each is a PR-sized slice.

### Pacing + economy (P0)
20. **30 waves per level** (currently 10). Extend every `resources/level_data/level_N.tres` wave array from 10 → 30. Gradient of difficulty: waves 1-10 tutorial/early, 11-20 mid-game, 21-30 escalation → boss(es) in 30. Keep existing 10 as a skeleton and interpolate. Player should feel progression arc, not 10-wave sprint.
21. ✅ **Starting gold: tighter early budget** — L1=120, L2=130, L3=140, L4=150, L5=160, L6=170, L7=180, L8=200, L9=200, L10=220. ✓ 2026-05-02.
22. ✅ **Upgrade cost curve steeper** — Lemurius path_a [210,455,1140] path_b [245,560,1260]; Amösius tier2+3 bumped ~15%. Other towers already in target ranges. ✓ 2026-05-02.
23. **Upgrade visual delta — MUCH bigger** — user says "man sieht Unterschiede der Upgrades kaum". Today tier pips are small dots + subtle tint. Need: per-tier sprite scale change (tier 1 = +8%, tier 2 = +16%, tier 3 = +25%), per-tier glow ring (pulse, brighter per tier), per-tier projectile size + trail length, path-specific crown/hat badge (one of 3 hats per path when tier≥1). Tier should READ from across the map, not require squinting.

### Audio overhaul (P0)
24. **Per-tower shoot SFX variation** — today every tower uses the same `play_shoot()` (880Hz square 0.06s). Each tower + each TIER should sound distinct:
    - Lemurius: soft thump (bio banana) → rubberier as it upgrades
    - Kühne: pollen whoosh → chime on higher tiers
    - JoJo: glass clink + fizz → bigger boom at tier 3
    - Cordula: volleyball pop → crowd cheer at tier 3
    - Amösius: sticky "schleck" → tongue-whip at tier 3
    Wire via `SfxManager.play_shoot(tower_id, tier)`. Add 15 new procedural variants.
25. **SFX audit + cleanup** — user says "fast alle aktuellen sounds sind kurra scheisse". Run a full review of `scripts/systems/sfx_manager.gd`:
    - Re-record every procedural SFX (shoot, hit, death, upgrade, sell, place, click, wave_start, boss_roar, life_lost)
    - Goal: warm, non-piercing, sub-200Hz fundamentals where possible, always with envelope ramps (no instant attacks)
    - Use Minecraft / Slay-the-Spire / BTD6 as reference — subtle, layered, never thin-beep-y
    - Delete `_play_tick` and unify on `_play_soft_pluck` family
26. **Per-wave / per-level music change** — music track currently binary (menu vs game). Want per-level mood variation: L1 cheery, L2 icy ambient, L3 bakery-organ, L4 cellar-dub, L5 boss-intense, L6 parkhuus-industrial, L7 rooftop-cinematic. `MusicManager.set_level_track(level_id)` with 7 procedural variants.
27. **Per-enemy hit/death SFX** — today all enemies share size-based pitch. Differentiate: basic = bread crunch, fast = wrapper crinkle, tank = meat slap, healer = bottle clink, flying = wet splat, boss = demonic roar (already partial), swarm = tiny squeak.
28. **Reorganize sfx_manager.gd** — split into sfx_manager.gd (public API), sfx_library.gd (per-effect data dicts), sfx_synth.gd (waveform helpers). Today one 200-line file mixes public + internal.

### Art (P0)
29. **Generate dedicated backgrounds for ALL levels via Gemini** — all 7 maps need better art. Use Gemini Imagen 4 (or Stability) at 1280×720 with Swiss-themed prompts:
    - L1 Migros entrance: auto-doors + shopping carts, midday bright
    - L2 Tiefchüel-Abteilig: frozen aisle, icy blue, breath fog
    - L3 Bäckerei: warm lit bakery, bread racks, flour dust
    - L4 Chäsi-Keller: dim cellar, cheese wheels, green acid glow
    - L5 Kasse: cash registers, Cumulus sign, warm orange
    - L6 Parkhuus: neon parking garage, concrete, rain
    - L7 S'Dach: rooftop sunset, Migros sign silhouette, birds
    Each level scene should reference `res://assets/textures/maps/level_N_bg.png` directly (not the placeholder reuse).
30. **Regenerate tower icons with alpha_matting** — see item #19. This is part of the art batch now, higher priority.
31. **New enemy variants per level** — each level should have at least ONE exclusive enemy:
    - L1 Brötli (already), L2 add Glacé-Golem (ice flying), L3 add Kamikaze-Gipfeli (fast exploder), L4 add Fondue-Bomb (splash on death), L5 add Quittung-Geist (ghost — partial immune), L6 add Coupon-Cyborg (tank+fast hybrid), L7 add Sturmmöwe (flying+fast). One new enemy .tres + .png per level.

### Playtest bot (P1)
32. **Playtest bot captures per-level screenshots** — today the bot runs all 7 levels but only commits 7 key shots. Extend to commit one final screenshot per level (`L1_final.png` ... `L7_final.png`) + one `upgrade_comparison.png` showing tier 0/1/2/3 side by side. User wants visual proof the level art + upgrade visuals actually changed.
33. **Playtest coverage: run upgrade flow for EACH tower** — today only Lemurius gets upgraded through paths. Add loop: per tower (basic/sniper/splash/cordula/slow/joe/justus/seve), place + tier up to A3 + capture shot.
34. **Audit screenshot grid** — workflow stitches 7 level screenshots + 8 upgrade screenshots into a 4×4 grid PNG so chat-session Claude can Read a single image and see the whole game state.

### General organization (P1)
35. **Sound + music config file** — `resources/audio_config.tres` with every SFX / music track referenced by id, tunable from the editor without touching code. Current state: everything hardcoded in sfx_manager.gd.

### 🔥 User directive 2026-04-20 late — "copy BTD5" deep pass (P0)

User playtests say the game is still too shallow. Each item below is a
PR-sized slice for the autonomous loop.

38. **Tower mechanical diversity — BTD5 parity.** "Rn all basically just
    shoot." Each tower needs a fundamentally different *mechanic*, not
    just different stats on the same shoot-projectile loop. Target:
    - **Lemurius (banana)**: piercing projectile (bananas pass through
      up to N enemies at higher tiers — like dart monkey).
    - **Kühne (pollen sniper)**: first-strike + camo-detection + crit
      (like sniper monkey / ninja monkey hybrid).
    - **JoJo (acid flask)**: lingering ground puddle that DoTs
      (already partial — ensure puddle scales with tier) + corrosion
      debuff (enemies take +X% from all sources while acid-coated).
    - **Cordula (volleyball)**: wide arc burst hitting N targets in a
      cone (like boomerang monkey). Tier 3 = full-screen spike.
    - **Amösius (tongue)**: single-target reel-in *pull* mechanic —
      grabs farthest enemy, drags back 30% of path. Tier 3 = eats
      small enemies whole (instant kill ≤50 HP). Like glue gunner +
      tack shooter hybrid.
    - Plus a **farm tower** (non-combat, generates gold per round —
      BTD5 banana farm) and a **support tower** (buffs adjacent in
      ~200px radius — BTD5 village). These are new .tres files.
39. **Path A vs Path B = fundamentally different roles, not stat
    bumps.** Today A is "more damage" and B is "more speed". Need:
    - A-path = single-target specialist (damage, crit, armor-pierce)
    - B-path = crowd-control specialist (multi-shot, slow, AoE, debuff)
    So player actually makes a choice per tower. Each tier adds a
    NEW visible behavior (not a +% stat), e.g. A1 = projectile gets
    longer range, A2 = piercing, A3 = crit; B1 = extra shot, B2 =
    slow on hit, B3 = full cone.
40. **Per-tier art — real image variations, not color tint.** User:
    "right now they just slightly change their color which looks
    absolutely horrendous." Need: per-tier img2img generations using
    the existing character face as source, adding tier-appropriate
    gear/pose/accessories. Example: Lemurius tier-1 wears a headband,
    tier-2 holds a bigger banana, tier-3 sits on a banana throne.
    Generate 5 towers × 2 paths × 3 tiers = 30 img2img variants via
    the existing `art-request` workflow. base_tower._update_visual()
    already supports path_a_textures / path_b_textures arrays — just
    need to populate them.
41. **Tower synergies / adjacency effects (BTD5 village-style).**
    Placing tower X within ~150px of tower Y grants a visible buff:
    - Lemurius + Kühne → Lemurius bananas +15% range + pierce
    - Cordula + Amösius → Cordula attack speed +20% while Amösius
      has a target glued
    - JoJo + farm tower → JoJo acid puddles give +1 gold per pop
    - Kühne + support tower → Kühne crit chance +10%
    - Farm + support tower → farm pays +25%
    Render as faint gold lines between synergy pairs + small icon
    on each tower sprite.
42. **Regular screenshot-based playtest analysis loop.** User:
    "you REALLY NEED to take screenshots and really look at them!"
    Every N autonomous runs (N=3), run the playtest bot with
    --capture-per-level flag (ROADMAP #32) that saves 7 final-wave
    screenshots + 1 upgrade-comparison grid, commits them under
    `docs/playtest_shots/YYYY-MM-DD/`. Chat-session Claude can then
    `Read` the grid image and evaluate visual regressions without
    running the game. Add an "audit-via-screenshots" mode to the
    autonomous-dev workflow that pipes the grid into a Claude
    inference call with prompt "list 5 visual issues in this image".
43. **Level difficulty curve — BTD5 reference.** User: "the levels
    still look ass — for difficulty and how fast happens copy
    BTD5." BTD5 curve: wave 1 = easy warmup (5-8 enemies), wave 10 =
    first real threat, wave 20 = first boss, wave 30 = first ceramic
    bloon equivalent (Cervelat tier?), wave 40 = MOAB (boss fight),
    wave 50 = BFB. Apply to our 30-wave extension (#20): wave 1 = 1
    enemy, wave 5 = first real group, wave 10 = first tank, wave 15
    = first healer, wave 20 = first boss, wave 25 = boss+minions,
    wave 30 = gauntlet finale. Document the curve as a constant
    `DIFFICULTY_WAVES` table in `scripts/systems/wave_curve.gd` and
    have level_N.tres builders pull from it.
44. **Side-widget shop not actually scrollable.** User reports
    dragging to scroll doesn't work on touch. Fix: ensure the
    ScrollContainer has `scroll_deadzone = 8` + `touch_scroll =
    true` (Godot 4.x flag), and that child buttons don't eat the
    scroll gesture. Verify on mobile Chrome via DevTools device
    emulation.
45. **More maps + more levels.** User: "not enough maps and
    levels." Target: Level 8 (Coop-Einbruch), Level 9 (Cumulus-
    Punkte-Kern), Level 10 (Finale Tüüfel-Äste — multi-path like
    BTD5's "Workshop"). Each with 30 waves. Plus 3 bonus-mode
    levels from section E (Self-Scan-Hölli, Banani-Träume, De
    Tüüfel kommt heim).
46. **Backgrounds look boring.** User: "background images and maps
    look very boring." Combine with ROADMAP #29 but require: each
    background needs at least 2 visible parallax layers + 1
    particle effect (frost for L2, flour for L3, etc.). Not just a
    single flat painting. `scenes/game/level_N.tscn` should layer:
    - back layer (distant building / sky)
    - mid layer (shelves / props, parallax_scale = 0.5)
    - front overlay (CPUParticles2D for atmosphere)
47. **Story evolves across levels — multiple characters.** User:
    "intro talk / level intros need to be more varied and with
    other characters as well, evolve the story!" Today each level
    has 1 Swiss-German text block. Target: 3-5 page dialogue
    with:
    - rotating narrator (Lemurius → Kühne → Cordula → JoJo →
      Amösius → back to Lemurius) per level
    - a new supporting character every 2-3 levels
      (e.g. Micheli-the-security-guard L3, Trudi-the-cashier L5,
      Beni-the-parking-attendant L6)
    - plot arc: wake up (L1) → realize the curse (L3) → confront
      De Vegan-Tüüfel (L5) → chase through parkhuus (L6) → rooftop
      showdown (L7)
    Extends the story-screen-rework item already in P0 bugs.
48. **Extra persistent currency per level-clear (Aminos).** User
    wants a second currency (name suggestion: "Aminos" — since
    Amösius has "amino") that accumulates across runs, spent in a
    dedicated shop on permanent upgrades. Distinct from the
    existing Spezial-Münzen concept — Aminos are earned
    automatically (not mission-gated) at 5 per level clear,
    scaling with difficulty. Spend in `scenes/ui/aminos_shop.tscn`
    on: unlock new towers, unlock new map backgrounds, unlock new
    tier-3 projectile skins.
49. **Tower roster is progression-gated.** User: "initially not
    all towers available — need to play to get them." Day-one
    roster: Lemurius + Cordula only. Unlock order (by total
    stars): 3 stars unlocks Kühne, 6 stars unlocks Amösius, 10
    stars unlocks JoJo, 15 stars unlocks farm tower, 20 stars
    unlocks support tower. Shop rows for locked towers show a
    padlock icon + "Brich 3 Stärn um z'unlocke".
50. **BTD5 feature parity pass — compile + pick.** Audit BTD5's
    feature list and port what fits: Monkey Knowledge (passive
    tree — we have Cumulus for that), Abilities (we have P0 "Active
    Powers"), Hero Monkey (we have P0 hero system), MOABs (#20
    boss-wave arc), camo bloons (nominate one enemy type to be
    camo-until-revealed, e.g. "Schatte-Tofu"), regrow bloons (one
    enemy that resurrects mid-path unless killed with specific
    damage type), lead bloons (one enemy immune to physical
    damage unless magic/explosion). Three new enemy behaviors
    total — add to enemy_data.gd + wave_manager hooks.

### Wave pacing (P0 new)
36. ✅ **Level 1-4 all start with Brötli** — L2 opens fast, L3 opens healer+basic, L4 opens tank+basic. ✓ (implemented in prior run, confirmed 2026-05-02)
37. ✅ **Early-wave enemy variety knob** — L1 wave 2 now basic×7+fast×3; L2 wave 2 now fast×6+basic×3. All levels have ≥2 enemy types in first 3 waves. ✓ 2026-05-02.


---

### Autonomous loop rules (unchanged)

**Circuit breaker**: 25 merges / 24h, 4 Opus 4.7 runs / 5h. Don't exceed. If rate-limited, stop and log to `docs/observability/ledger.md`.

**Do NOT do**: anything requiring user input. No new issue-template changes, no secrets, no PR reviews. Auto-merge everything validated by sim-gate + playtest.

**Close-out target**: get to L10 + 0 audit findings + observability pipeline writing consistently. Then wait.

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
- [x] **Monster first-appearance intro animation** (PR #67) — shipped
  via `enemy_introduced` signal + HUD zoom-fade overlay + sprite preview
  thumbnail (PR #88). Original spec follows for reference:
  when a new enemy type spawns for the first time in a session (track
  via WaveManager._seen_enemy_ids), freeze the wave for 1.2s and play
  a big reveal animation: enemy zooms in from offscreen to 2× scale at
  center, portrait slides in with name label + Swiss-German taunt
  speech bubble, music ducks 50% briefly, screen flashes. After first
  reveal, enemies never show name labels again (removes the constant
  floating text over every enemy). Spec:
  - `GameManager.seen_enemy_ids: Array[String] = []`
  - On wave_manager.\_spawn_enemy, check if enemy_id NOT in seen_enemy_ids
  - If new: emit enemy_introduced(id, data) signal, add to seen
  - HUD listens, builds an EnemyIntroOverlay, animates 1.2s, frees
  - base_enemy removes its persistent name label; only the intro shows it
- [x] **Enemy movement polish** (PR #67) — bobbing walk via `v_offset`
  in `base_enemy._process` shipped. Dust-puff particles still TODO
  if further juice is wanted.

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
- [x] Level 5 data + scene + story intro — D'Kasse — Endkampf (PR #87)
- [x] Level 6 data + scene + story intro — S'Parkhuus Bonus (PR #100)
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
- [x] **Better music** (PR #66) — triangle wave + kick/snare/hi-hat
  drums on the game track + menu/game track bank switch. Original
  spec retained for reference:
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
