# Changelog

Running log of changes made by the autonomous dev loop. Newest first.
Each run appends one line.

## 2026-06-17 (audit-polish — wave-boundary FPS fix + enemy data caching)

- perf(wave): enemy data cache in WaveManager — _spawn_enemy() now does a dict lookup instead of ResourceLoader.exists()+load() on every spawn; preload is now synchronous (was call_deferred, risked race with wave-1 start); spawn_payload children also pre-cached so _spawn_children() hits warm Godot ResourceCache not disk (#975 #982). perf(playtest): max_physics_steps_per_frame 48→12 (matches 12× time_scale — prevents physics catch-up spiral that caused 2.0 FPS min-spike at wave boundaries). fix(game_level): wave receipt creation deferred one frame via call_deferred so UI layout doesn't pile onto wave-end signal burst.

## 2026-06-17 (audit-polish — Lemurius A1 humanoid identity preserved)

- fix(tower): A-path tint at tier 1 no longer crushes sprite into a saturated blob (#966 #977) — replaced flat `path_a_tint * 0.89` with a per-tier blend with white (A1 = 32% colour @ 0.97 brightness, A2 = 62% @ 0.88, A3 = 90% @ 0.78). Lemurius (and the other 4 towers without a tier-1 sprite swap) now retain humanoid identity after the first A-upgrade while the path-A green hue still telegraphs clearly. A3 stays strong because the t3 sprite swap usually backs it up. Cordula/Sniper (full tier-sprite matrix) get gentler tinting too — the swapped sprite carries the visual delta.

## 2026-06-17 (audit-polish — defeat screen animation + Swiss German fixes)

- polish(game-over): "VERLORE!" title now slams in from 2× scale with TRANS_BOUNCE then shakes left-right (rotation ±0.08 rad), matching the production quality of "SIEG!" pop; red border vignette pulses behind the panel for defeat atmosphere (contrasts gold vignette in victory). "BOSS" → "DE BOSS!" in NextWavePreview (Swiss German, hud.gd two occurrences). "LETSCHT WÄLLE!" → "LETSCHTI WÄLLE!" (adjective declension fix).

## 2026-06-16 (audit-polish — path-B sprite blend + WON grace timer)

- fix(tower): Path B upgrade tints now readable over dark A3 bases (#965) — B hue blended additively into sprite.modulate (22%/44%/66% per tier) so A3+B1/B2/B3 are visually distinct without relying only on the glow ring; brightness floor raised 0.60→0.68 so A3 portraits are lighter; B glow ring moved to z=1 (in front) with pulse floor 0.45→0.65 so ring never dips below 65% opacity
- fix(wave): 0.5s grace timer before show_victory() so dying-animation enemies finish before victory screen overlaps them (#955)

## 2026-06-16 (audit-polish — B-path tint readability)

- polish(tower): decouple A-path and B-path tints — A tint now applied exclusively to sprite.modulate; B-path lives on its own pulsing glow ring (PathBGlow) that shows whenever path_b_tier > 0 (was: only when both paths invested). Ring opacity raised from 0.28+0.18n to 0.55+0.18n so B1/B2/B3 are clearly readable even at A3 darkness. Closes playtest-feedback #957.
- chore: closed 5 stale audit-grid PRs (#950 #954 #958 #960 #961) blocked by action_required validation gate; #913 remains open tracking the workflow fix.

## 2026-06-16 (build-content — Selbschtskan-Schiff copycat enemy)

- feat(enemy): new "Selbschtskan-Schiff" copycat punishment enemy — wears the silhouette of the most-recently-placed friend tower (dark inverted sprite + magenta self-modulate) and is immune to damage from that exact `tower_id`. Hits from the matching tower fizzle with a 30%-chance "NÖD!" magenta pop and no HP loss. Forces multi-tower compositions at L8+. Stats: 1400 HP / 95 px·s⁻¹ / 50g drop. Wired into L8 wave 4 (×1 solo intro), L9 wave 7 (×3), L10 wave 6 (×5). New `is_copycat` flag on EnemyData; GameLevel tracks `most_recent_tower_id` + `most_recent_tower_texture`; WaveManager skins copycats at spawn via `BaseEnemy.apply_copycat_silhouette()`. Closes ROADMAP item.

## 2026-06-16 (audit-polish — WON state race condition fix)

- fix(wave): extracted `_check_wave_complete()` from `_decrement_enemies()`; added call in `_process()` when `is_spawning` goes false + `enemies_alive <= 0` — fixes race condition where fast enemies dying during wave spawning prevented `all_waves_completed` from ever firing (#917 #944 #945); closes playtest-feedback issues #917 #944 #945
- fix(playtest): grace-period now activates when `current_wave >= total_waves` (not only when `all_done == true`), giving stragglers 6 real seconds to die before reporting PLAYING (#945)

## 2026-06-15 (audit-polish — 2 playtest-feedback fixes)

- fix(tower): Path A tier-3 tint hue-shift reduced from 50°/tier to 30°/tier so A3 tint lands in teal (178°) not dark-blue-violet (238°); brightness floor raised 0.50→0.60; tower no longer renders as a black silhouette at max A-path tier; closes playtest-feedback #943
- fix(placement): ghost tower hidden immediately (visible=false) before queue_free() in cancel_placement() so no stale frame shows; _cleanup_scene() now cancels active placement ghost (ghost is never in the "towers" group, so the existing loop missed it); closes playtest-feedback #941
- NOTE: audit-grid.yml fix (issue #913) still blocked — Claude App token lacks `workflows` permission to push workflow file changes

## 2026-06-15 (audit-polish — 4 playtest-feedback fixes)

- fix(hud): wave-announce pill moved from y=68 (play field) → y=8–62 (inside TopBar band); Pausbeleg dismissed immediately on wave start (no 0.22s overlap during combat); upgrade tints A1/A2/A3 now visually distinct via 50°/tier hue step (was 30°) + 40°/tier for B path (was 20°) + 16% brightness/tier (was 12%); acid pool kills attributed to JoJo's kill_count — closes #927 #928 #933 #934 #935; closed stuck audit-grid PR #938 per issue #913

## 2026-06-15 (audit-polish — Pausbeleg receipt UX fix + Swiss German polish)

- polish(ux): wave receipt moves bottom-right → bottom-left, above the 76px bottom panel, so it never overlaps the right-anchored SideShop or the NextWaveButton; Swiss German fixes: "Tower-MVP" → "Turm-Helden", "Findet" → "K.O.s", "dmg" → "Schade", "Noi Turm" → "Kei Turm"; MVP list now shows kills alongside damage ("🥇 JoJo — 842 Schade / 12 K.O."); fix "Cumulus-Pukt" typo → "Cumulus-Punkt" in cumulus_blob enemy intro taunt

## 2026-06-15 (audit-polish — Pausbeleg wave receipt overlay)

- feat(ux): "Pausbeleg" — Migros-style receipt slides up from bottom-right after each wave; shows Tower-MVP top-3 by damage, enemies defeated, gold earned, cumulus, lives remaining; tap to dismiss; wired via BaseTower.wave_damage_dealt/wave_kill_count + CurrencyManager.wave_gold_earned (all reset on wave_started)

## 2026-06-14 (audit-polish — Migros-App notification toasts + ci fix)

- polish(level-select): 15-entry Swiss German push-notification toast carousel (Migros red panel, slide-down tween, 8–12 s interval) + "🛒 Cumulus N ★" brand-red badge top-right; Swiss German fix: "Sterne:" → "Stärn:" in totals badge; NOTE: audit-grid.yml fix (issue #913) written but not pushable — requires `workflows` token scope; closed stale audit-grid PRs #921 #916 manually

## 2026-06-14 (audit-polish — B-path tint + level select brightness)

- polish(tower): B-path tint now clearly visible at A3+B1/B2 — hue rotates -20°/tier (opposite A's +30°, so they diverge not converge), weight 3.5× (was 2.0×) makes B dominant at tier 2, glow alpha 0.28+0.18/tier (was 0.18+0.14); glow ring now shows shifted B hue matching sprite (closes #909); polish(ui): level select Dimmer alpha 0.45→0.25, GridBackdrop lighter (alpha 0.72→0.58), button normal state darkened 38%→20%, hover darkened 20%→5% so level nodes are clearly visible (closes #513)

## 2026-06-14 (audit-polish — playtest time budget + stress coverage)

- fix(playtest): L2/L3 healthy scenarios now run at 12× time_scale (was 8×) so dense 10-wave levels cover 240s game time in the same 20s real budget — prevents PLAYING state at scenario end (#904 #896 #895 #901); stress scenario 3→5 towers at full L1 path coverage, expected kill rate ~65/80 (#903); kill-chain diagnostic guarded with enemy_count>0 to suppress false-positive for no-enemy upgrades scenario (#897)

## 2026-06-14 (audit-polish — upgrade tints + victory grace period)

- polish(tower): A-path upgrade tints now clearly distinguishable per tier — brightness step 8%→12%, hue rotation 22°→30°/tier, saturation 12%→22%/tier; Lemurius A1=bright green, A2=teal-green, A3=dark cyan instead of three near-identical dark blobs (#902); fix final-wave button flicker by checking `current_wave < total_waves` instead of `not all_done` in `_on_wave_completed` so the "next wave" button never appears right before the victory screen; playtest grace period — if all waves sent but enemies still dying, wait up to 3 extra 2s ticks before logging state, prevents false PLAYING result when victory is about to fire (#900)

## 2026-06-14 (audit-polish — playtest stress + L3 exit-catcher)

- fix(playtest): stress scenario now places 3 towers (basic/sniper/splash at T2-A) before spawning 80 enemies so projectile-pool and combat VFX are benchmarked under load — previously kills=0 and projectile FPS was unmeasured (#889); L3_healthy adds 7th slow tower at (1140,400) to catch 3 basic children the wave-10 boss spawns on death (boss.tres spawns_on_death="basic" spawn_count=3) (#890); closed stale issues #870 #871 #874 already fixed by PRs #887 #885.

## 2026-06-13 (audit-polish — wave win fix + upgrade tween)

- fix(wave_manager): WaveManager now tracks enemies spawned on parent death (tank→2 basic) via register_spawned_enemy() — closes premature WON when spawn-children are still on path (closes #888); polish(tower): upgrade_path captures pre_tint before _apply_path_tint() so the modulate flash tweens FROM old appearance TO new, fixing jarring instant snap at tier 0→A1 (closes #891)

## 2026-06-13 (audit-polish — playtest bughunt + L3 timeout)

- fix(playtest): update bughunt bad_positions from mid-screen coords that lie OFF the L1 path to actual bezier control points (120,120)+(420,100)+(700,100)+(960,120)+(1200,200) that ARE on the path — previous positions were always accepted (#870); skip wavestart anim clip for L2/L3 healthy scenarios to save ~48 GPU readbacks and reclaim 10-15s of the 120s godot timeout so L3 _record_scenario always fires (#871)

## 2026-06-13 (audit-polish — playtest scenario fixes)

- fix(playtest): remove auto_start_waves=true from new_towers showcase so wave 2 never auto-starts; scenario now ends with enemies_remaining=0 instead of 1 (#874); add 6th sniper tower to L3 hardcoded layout at (1050,350) covering the right-side serpentine to reduce life leaks on wave 7-8 (#872); closed already-fixed issues #877 and #878.

## 2026-06-13 (audit-polish — autoload directory consolidation)

- chore(audit): moved 8 misplaced singleton scripts from `scripts/systems/` and `scripts/playtest/` into `scripts/autoload/` where they belong; updated `project.godot` paths; corrected `CLAUDE.md` project-structure docs; ROADMAP drift note resolved. No behaviour change.

## 2026-06-13 (audit-polish — panel transition animations)

- polish(hud): tower-info panel fades in over 0.12s on show (was instant snap); shop content fades in with the 0.22s slide tween when expanding (was popping visible before panel arrived); tween kill + modulate reset on dismiss prevents stale alpha state.

## 2026-06-13 (audit-polish — B-path upgrade tint convergence fix)

- fix(tower): B-path upgrade tint no longer converges with A-path at high tiers — removed 45°/tier hue rotation from `_apply_path_tint()` (it caused red-orange B to drift to yellow-green by B2, identical to A-path green). B-path now stays in its characteristic color family, intensifying via saturation boost (+0.25/tier). Closes playtest-feedback #864.

## 2026-06-12 (audit-polish — Swiss German consistency fixes)

- fix(i18n): three English strings replaced with Züridütsch — main menu subtitle "Tower Defense Adventure" → "E Türm-Verteidigungs-Abentüür"; synergy bonus label "+%d Pierce" → "+%d Dureloch"; aminos upgrade title "Banane-Pierce" → "Banana-Dureloch". Also ticked MOAB boss (Selbschtbedienigs-Wage) ROADMAP item shipped in PR #855.

## 2026-06-12 (ideate — 5 spec'd ideas + 2 architecture-note updates)

- docs(roadmap): 5 new spec'd ideas under "Ideas To Explore" — Brot-Stab petrify-line active power, De Hauswart janitor support tower, Selbschtskan-Schiff copycat punishment enemy, Coupon-Kombo spend-streak gold multiplier, Pausbeleg diegetic between-wave receipt overlay. Each entry includes mechanics, impl hints, costs, unlock costs, and "why it sticks" rationale.
- docs(arch): hud.gd drift note updated — file is now 2321 lines / 80 functions, net +120 lines and +5 functions in 7 days since the 2026-06-05 note while the refactor sits unstarted. Next audit-polish should extract `tower-shop-panel` as a load-bearing first cut.
- docs(arch): new architecture note — 8 of 11 autoloads live under scripts/systems/ instead of scripts/autoload/, contradicting CLAUDE.md. Proposed low-risk ~1h refactor: move ComboTracker, MusicManager, SfxManager, AutoPlaytest, WaveSimulator, ProjectilePool, EnemyPool, EffectPlayer into scripts/autoload/ and update project.godot.

## 2026-06-12 (audit-polish — extract embedded tier visuals)

- refactor(tower): extract `_hat_script()` + `_glow_script()` from base_tower.gd to real files `scripts/towers/visuals/tier_hat.gd` and `tier_glow.gd` — both now preload()'d, visible to validate.sh, and parseable by godot --check-only. base_tower.gd is ~58 lines shorter. Architecture note in ROADMAP updated with progress and remaining steps.

## 2026-06-09 (audit-polish — differentiated active abilities)

- polish(tower): differentiated all 4 non-Amösius active abilities — Lemurius BANANI-STURM gains +2 pierce (bananas punch through enemies), Kühne POLLEN-WOLKE becomes an AoE slow field (60% slow / 3s on all in-range enemies every shot, no rapid-fire), JoJo MEGA-SPRITZ keeps 3× fire rate AND 2.5× splash radius, Cordula VOLLEY-TORNADO keeps rapid-fire AND expands cone to 360° (full-court multi-target blast). Closes "differentiated attack patterns still TODO" in ROADMAP.

## 2026-06-09 (audit-polish — path B tints + synergy label rebase)

- polish(tower): path B tint visibility — B1 now gets 30°/15% hue+sat shift immediately (was no shift until B2); B-weight raised 1.5×→2.0× so B tiers are clearly distinct from A-max at a glance. Rebases conflicting PR #779.
- polish(hud): TowerInfo panel shows active Synergie-Combo as gold "✦ Label (bonus)" row with pop-scale tween on first activation. `BaseTower.get_active_synergy()` exposes `_synergy_bonus`. Rebases conflicting PR #785.

## 2026-06-09 (audit-polish — projectile setup crash)

- fix(tower): projectile.setup() crash on script-detached Area2D — CACHE_MODE_IGNORE fallback only guarded null/freed but not get_script()==null; added explicit check so a genuinely script-less node aborts the shot instead of crashing. Closes ci-failure #791.
- polish(tower): Amösius ZUNGE-RUCK now mass-freezes ALL on-screen enemies instantly (apply_slow to every enemy in group) + 2s rapid-fire burst, replacing the generic 4s triple-fire. Removes "placeholder" comments from ability labels.

## 2026-06-09 (audit-polish — ability activation VFX)

- polish(tower): tower-specific ability activation VFX — expanding colored ring + radial particle burst when each friend fires their active power. Lemurius: banana gold, Kühne: pollen teal, JoJo: hot orange, Cordula: volleyball pink, Amösius: ice cyan. `EffectPlayer.spawn_ability_burst()` + `_get_ability_color()` in base_tower.gd.

## 2026-06-08 (audit-polish — kills=0 + glow tween fix)

- fix(tower): kills=0 regression — glow tween lambda accessed freed Node2D on upgrade; tracked tween in `_glow_pulse_tween` and kill() before freeing old glow node. Also removed hard projectile abort when CI GDScript VM pressure caused spurious validation failures (was aborting every shot → kills=0 in headless playtester). Closes #770, #772.

## 2026-06-08 (audit-polish — playtester T2-A upgrade, balance fix)

- fix(playtest): upgrade playtester hardcoded towers from T1-A to T2-A — T1-A gave only 110 dmg/pass vs 100 HP basic enemy (thin margin at 8× time_scale); T2-A gives ~200 dmg/pass (2× buffer), making L1/L2/L3_healthy scenarios reach WON instead of LOST. Closes playtest-feedback #760, #761.
- chore(playtest): add WARN log lines when kills=0 to distinguish "off-path towers" from "DPS insufficient" failure modes.

## 2026-06-07 (audit-polish — Hoi-Schatz easter egg)

- polish(tower): "Hoi-Schatz" love-tap easter egg — tap any placed tower 7× in 3s to trigger a personal Swiss German voice-line bubble (e.g. "Hoi Schatz!" for Lemurius, "Ruig, alles unter Kontrolle." for Kühne). 30s per-tower cooldown. New EasterEggLines data class, ~80 LoC, pure addition.

## 2026-06-07 (audit-polish — playtest wave budget fix)

- fix(playtest): per-level shot cap 8→14 ticks, elapsed safety net 19s→32s real (224s game time at 8×) — old 128s cap cut L2/L3 off at wave 4/10; all 10 waves now run within budget. Closes #747, #745.

## 2026-06-07 (audit-polish — L2 wave balance + playtester placement)

- balance(level2): waves 1/3/4 softened — wave 1 reduced 6→4 fast (0.9s delay), wave 3 reduced 2→1 tank (first-tank intro is now solo), wave 4 reduced 8→6 fast. Closes #700, #710, #716.
- fix(playtest): L2 hardcoded placements now include 5th tower (justus at 920,250) covering mid-right path segment — previously 4 towers had dead zone on upper-right path section.

## 2026-06-07 (audit-polish — banana scale, tier-1 tint, scenario timing)

- polish(projectile): banana Sprite2D scale 0.15→0.07 — banana was 70px wide (same as basic enemy); now 33px, clearly a small projectile. Closes oversized gold coin sprites issue #736.
- polish(upgrade): tier-1 path tint strength 0.80→1.0, brightness 0.88→0.82 — full-color jump on first upgrade, immediately visible against tier-0 white. Tiers 1/2/3 now step at 0.82/0.76/0.70 brightness. Closes #735.
- fix(playtest): healthy scenario ticks 7→8, cap 17s→19s real (128s game time at 8×) — was 112s which cut off last wave at ~120s, leaving L1/L2/L3 in PLAYING state. Closes #732, #733.

## 2026-06-07 (audit-polish — revert change_scene_to_packed, fix 0-kills P1 regression)

- fix(combat): reverted change_scene_to_packed() from ff53d36 — background-thread-loaded PackedScene causes null-script GDScript nodes in headless Godot 4, aborting every projectile shot (0 kills, issues #728/#725). Cache-warming load_threaded_request() is preserved so no disk-read hitch. Stress scenario now registers enemies with WaveManager so HUD shows "Wälle 1/1" and FPS reflects combat load (issue #727). Closes #725, #727, #728.

## 2026-06-07 (audit-polish — async scene preload, FPS hitch fix)

- perf(scene-load): async ResourceLoader.load_threaded_request() in story_screen._ready() + level_select._on_level_pressed() — level scene preloads during dialogue/picker so change_scene_to_packed() can be used instead of sync change_scene_to_file(), eliminating the 1–3 FPS spike on every level transition (closes #701, #717). Fallback to sync load if preload not ready.

## 2026-06-06 (audit-polish — L10 dedicated background)

- art(level10): generated `level_10_finale.png` via Stability AI SD3.5-large — dark hellfire underground Migros vault with glowing crimson M-rune symbols and cursed vegan products. Level 10 now has its own unique atmosphere matching `background_color` (0.35, 0.05, 0.08). Previously reused `level_1_obst.png` (closes P1 ROADMAP item).

## 2026-06-06 (audit-polish — robust projectile validation, 0-kills fix)

- fix(combat): `_is_valid_projectile()` now uses a three-tier check — (1) script identity, (2) property-presence (`"damage" in p and "speed" in p`), (3) `has_method("setup")` as last resort. Property check is more reliable than `has_method()` in headless Godot 4 at 8× time_scale where GDScript VM pressure causes `has_method()` to return false for valid nodes (persistent kills=0 regression, issues #715, #708). `ProjectilePool.acquire()` and `release()` also updated: identity mismatch now does property-presence verification before destroying pool slots, preventing the pool from being depleted by post-CACHE_MODE_IGNORE identity drift and forcing the tower into the "permanently broken — aborting shot" path.

## 2026-06-06 (audit-polish — active ability button UX polish)

- polish(hud): ability button min-height 36→52px (mobile touch target); per-frame cooldown countdown via `_process` so the timer ticks in real-time instead of only updating on tap; thin 5px progress bar below button fills as cooldown drains; double-pulse flash animation when ability transitions from cooldown→ready. Affects all 5 towers (Lemurius/Kühne/JoJo/Cordula/Amösius).

## 2026-06-06 (audit-polish — level-select locked visibility + playtest timing)

- polish(level-select): remove `flat=true` from level buttons so disabled stylebox always renders in GL Compatibility renderer; show level numbers even for locked levels (BTD-style dimmed numbers instead of "—") so players see all 10 levels exist; improved locked-level contrast (closes playtest-feedback #685)
- fix(playtest): healthy-scenario loop 6→7 ticks (12s→14s real / 96→112s game time) — the last wave's enemies were not clearing before the old 96s budget expired, causing PLAYING state instead of WON (issue #699)

## 2026-06-06 (audit-polish — portrait tower sprite scale fix)

- fix(visual): `_update_visual()` now uses `target_size = 72px` for portrait towers (`friend_character_id != ""`) vs `130px` for cartoon towers. AI-photo textures fill the full texture area with a face, making a 130px circle appear 3-4× visually heavier than Lemurius's ~40px cartoon character in its 130px sprite (transparent padding). 72px portrait circles match the visual weight of Lemurius on map. Also added `max_dim > 0` guard to prevent `130/0 = inf` scale in headless/dummy-renderer contexts where `CompressedTexture2D.get_width()` may not yet be initialized. Fixes playtest-feedback #671.

## 2026-06-05 (audit-polish — B-path tier hue distinction)

- polish(visual): per-tier hue rotation in `_apply_path_tint()` — B-path T2 shifts base hue +18° + saturation +10%, T3 shifts +36° + saturation +20%; A-path T2/T3 get smaller +12°/+24° hue shift + +8%/+16% saturation boost. Fixes B1→B2 visually indistinguishable issue (#666) — each tower upgrade tier now reads distinctly even when the other path is already at max tier.

## 2026-06-05 (audit-polish — kills=0 CACHE_MODE_IGNORE script-identity fix)

- fix(combat): `_is_valid_projectile()` now uses script identity as primary check OR `has_method("setup")` as secondary — previously the strict `get_script() == _projectile_script` check rejected projectiles instantiated via `CACHE_MODE_IGNORE` (which loads a fresh Script object with different identity from the preloaded cached ref), causing ALL last-resort shots to abort with "permanently broken" error and kills=0 in L1/L2/L3 playtester scenarios (issues #672, #654, #601). Also updates `_projectile_script` cache after CACHE_MODE_IGNORE reload so subsequent shots skip the fallback path.

## 2026-06-05 (audit-polish — circle_clip shader modulate fix, upgrade tints now visible)

- fix(visual): `circle_clip.gdshader` was discarding `CanvasItem.modulate` — `COLOR = tex_color` replaced the incoming vertex color (which carries the modulate) so path-upgrade tints set via `sprite.modulate` had zero effect on rendered output. Fix: `COLOR = tex_color * COLOR` preserves modulate across the shader; `COLOR.a = tex_color.a * mask` applies circle clip cleanly. This makes A1/A2/A3/B1/B2/B3 tints all visible in-game (closes #673).

## 2026-06-05 (audit-polish — combat fix + tint visibility + playtester accuracy)

- fix(combat+pool): replaced `has_method("setup")` guards in `ProjectilePool.acquire/release` and `BaseTower._attack` with `get_script() == _expected_script` identity checks — `has_method()` is unreliable in headless Godot 4 at 8× time_scale under GDScript VM pressure, causing towers to silently drop shots and the playtester to report kills=0 (issues #647, #653, #602). Also adds CACHE_MODE_IGNORE reload as last-resort fallback.
- fix(visual): tint brightness LUT updated — T1: strength=0.80/brightness=0.88 (was 0.70/1.0), T2: 0.95/0.80 (was 0.90/0.88), T3: 1.0/0.70 (was 1.0/0.72). The 12–30% brightness reduction at each tier makes path-color shifts clearly readable on bright friend-photo sprites (fixes #660).
- fix(visual): `_maybe_swap_tier3_sprite()` target size 90px→130px to match `_update_visual()` baseline — was making tier-3 art appear 30% smaller than base tier.
- fix(playtest): healthy-level wave cap reduced 8×2.5s→6×2.0s real time so 3 back-to-back levels fit in the 120s Godot process budget without L3 truncation (issue #640).
- chore(i18n): "S/Sek" → "Schad/Sek" in shop cards and tower-info stats panel for Swiss German clarity (Schade pro Sekunde = DPS).

## 2026-06-05 (ideate — 5 new spec'd ideas + second Architecture Note)

- docs(roadmap): 5 new P2 ideas spec'd with concrete impl hints — (1) Synergie-Combo adjacent-friend bonuses (5 cast-specific pairs: Lemurius+Cordula range, Kühne+JoJo damage, Amösius+Cordula slow-duration, JoJo+Lemurius pierce, Joe+Justus attack-speed) with signal-driven `_refresh_synergies()` + ✦ HUD badge, (2) "Migros-App" diegetic level-select skin with 15-item Swiss German push-notification queue + opt-in toggle, (3) "Hoi-Schatz" tower love-tap easter egg (7 taps in 3s → voice-line bubble, 30s per-tower cooldown), (4) "Wagli-Schub" drag-to-push shopping cart active power (30 gold per use, max 4 enemies per stroke, 150 Cumulus unlock), (5) "Tag der Affoltern" daily-mission concrete spec superseding the abstract P2 placeholder (deterministic seed, restriction + reward + per-day attempt-lock).
- docs(roadmap): second Architecture Note — `scripts/ui/hud.gd` is 2201 lines / 75 functions across 7 distinct responsibilities (tower shop, threat/boss HP, combo overlay, enemy intro, wave progress, wave-clear burst, safe-area). Now the #2 merge-conflict hotspot after `base_tower.gd`. Refactor proposal: extract 6 sibling Control nodes (`scripts/ui/hud/*`) keeping `hud.gd` as a thin ~400-line orchestrator. Pair sequencing with the base_tower refactor.
- chore(loop-context): CI-health caveat noted in PR body — open `ci-failure` issues #649/#651/#656 trace back to the projectile-script-identity timeout that PR #648 (currently CONFLICTING with main) addresses. Not an ideate-mode fix; flagged for the next code-mode run.

## 2026-06-05 (audit-polish — Level 10 MOAB-tier enemy intro polish)

- polish(hud): Level 10 super-enemies `moab_migros`, `bfb_cumulus`, `ddt_schwarz` now get Swiss German taunts, "MEGA-GFAHR!!" warning label (orange-red), and a softer orange screen flash + shake on first appearance, matching the existing boss "ENDGEGNER!!" treatment at reduced intensity.

## 2026-06-04 (audit-polish — projectile emergency fallback + pool prewarm order fix)

- fix(combat): `base_tower._attack()` now has a third-level emergency fallback when a projectile node passes the pool guard but still lacks `setup()` at fire-time (recurring headless CI parse-order edge case, issues #638/#641). Instead of silently dropping the shot, it instantiates directly from `_projectile_scene` and retries once. Removes the `if/else has_method` pattern that was swallowing shots.
- fix(pool): `ProjectilePool._prewarm()` now adds nodes to `_container` BEFORE calling `_deactivate()` so `reset_for_pool()` can safely set `global_position` (requires a scene-tree parent). Previously, calling `global_position = Vector2.ZERO` on an unparented node caused errors in headless CI.
- chore(merge): manually merged stale PR #637 (deferred enemy preload + dual-path tint + LETSCHT WÄLLE! final-wave text) which the previous loop created but failed to auto-merge.

## 2026-06-04 (audit-polish — deferred preload + dual-path tint + final-wave text)

- fix(perf): `wave_manager.setup_waves()` defers `_preload_enemy_resources()` via `call_deferred` — GPU texture materialization (`_tex.get_size()`) no longer blocks the first rendered frame on level load. Enemy cache is warm before any player input is possible (human reaction time >> 1 frame).
- polish(visual): dual-path brightness boost in `_apply_path_tint()` — when both A and B paths are invested, brightness gains +0.06 per combined tier above max_tier (capped 0.95). A3+B1 lifts from 0.72→0.78, A3+B3→0.90. Rewards dual-path investment visually.
- polish(ux): final wave shows "LETSCHT WÄLLE!" announcement (gold text) instead of generic "WÄLLE 10"; danger waves and final waves share the larger 30px font for extra drama. (Closes stale PR #626.)

## 2026-06-04 (ideate — 5 new spec'd ideas + first Architecture Note)

- docs(roadmap): 5 new P2 ideas spec'd with concrete impl hints — (1) Selbschtbedienigs-Wage MOAB-class boss that splits into a 6-enemy payload on death (BFB-with-cerams analogue, theme = self-checkout pain), (2) Migros-Bon active power giving 50% off next 3 actions, charges earned per level + Forschig unlock, (3) Geischter-Lauf ghost replay overlay for cleared levels (watch-mode + optimization tool, TikTok-ready), (4) Hei-Karte 1080×1080 share-card auto-generated on tier-3 finisher OR 50× combo (procedural QR + friend portrait + tagline), (5) DDT-Verwüschelig Tüüfel sabotage event between L8+ waves (Servelat smoke bombs → -50% range OR sympathy-refund OR Knoblauch-Tube cleanse).
- docs(roadmap): new "🔎 Architecture Notes" section opened. First entry: `base_tower.gd` is a 1188-line god-object with two embedded mini-scripts (`_hat_script()`/`_glow_script()` return multi-line GDScript strings), making the visual logic invisible to validate.sh/`--check-only` and a merge-conflict hotspot. Refactor proposal: extract to `scripts/towers/visuals/tier_hat.gd` + `tier_glow.gd` + a sibling `TowerVisuals` node. Target: drop base_tower.gd below 700 lines.

## 2026-06-03 (audit-polish — attack timer + upgrade tint screenshot)

- fix(combat): attack timer `= period` → `+= period` + `if` → `while` in base_tower._process — fixes towers firing at half rate when `delta > 1/attack_speed` (8× time_scale on CI). Root cause of playtest-feedback balance regression #619: 8 kills in L1 wave 5, 2 kills in L3 wave 2. Fix correctly fires multiple attacks per large-delta frame. Closes #619.
- fix(playtest): upgrade tint screenshot wait 0.4s → 0.7s in auto_playtest._run_upgrade_flow — upgrade animation tween takes 0.55s; previous 0.4s captured mid-tween when modulate was still washing out. All tiers (A1/A2/A3) will now show distinct color tints in screenshots. Closes #620.
- chore(prs): closed 7 stale audit-grid PRs (#580–618) superseded by newer run #623.

## 2026-06-03 (audit-polish → forced fix — projectile parse-order: definitive fix)

- fix(projectile): definitive parse-order fix — remove `class_name BaseProjectile` and `class_name AcidPool` (unused externally), move acid_pool.gd load from class-scope `const preload()` to runtime `load()` inside `_spawn_acid_pool()`, replace `is BaseEnemy` / `as BaseEnemy` in auto_playtest.gd with duck-typed `"is_dead" in e`. All prior fixes (#595, #609) removed `BaseEnemy` refs but left class-level `preload()` of acid_pool.gd in place; in Godot 4.6.2 headless CI this parse-time dependency chain still strips scripts from base_projectile.tscn instances, causing `has_method("setup") == false` and tower 0-kills. Runtime `load()` has no parse-time dependency — closes #608, #614.
- chore(audit): dead-code removal — 5 unused functions (103 LoC) across 3 files: `_get_base_color`, `_show_damage_number`, `_show_mini_pop` in base_enemy.gd (replaced by `_apply_damage_state_visual`), `current_counter()` in combo_tracker.gd, `_count_tres`+`_count_pngs` in dev_menu.gd (superseded by `_count_pngs_recursive`). All verified single-reference with grep.

## 2026-06-03 (build-content → forced fix — projectile parse-order: third regression hop)

- fix(projectile): `acid_pool.gd` `as BaseEnemy` cast was the remaining parse-order trap that #595 missed. `base_projectile.gd` preloads `acid_pool.gd` at parse time (`const _ACID_POOL_SCRIPT := preload(...)`), and `ProjectilePool` (autoload #9) eager-loads `base_projectile.tscn` before `EnemyPool` (autoload #10) registers `BaseEnemy` — so acid_pool's parse failed, cascaded to base_projectile, and stripped the script from every instantiated projectile (class=Area2D, no `setup()`). Replaced with duck-typed `enemy_node.get("is_dead")` + `enemy_node.take_damage(...)`. Added a multi-line warning above the preload in base_projectile.gd so this trap can't be reintroduced without explicit notice. Closes #605, #608. Build-content run was forced into fix mode per CLAUDE.md priority rule #2 (playtest-feedback before new features).

## 2026-06-02 (audit-polish — projectile parse-order fix)

- fix(projectile): remove `BaseEnemy` class_name type annotations from `base_projectile.gd` declarations — `var target: BaseEnemy`, `p_target: BaseEnemy` in setup(), `-> BaseEnemy` return type, and `as BaseEnemy` casts all cause GDScript parse-order failures in headless CI (same pattern CLAUDE.md warns about for signals). Replaced with untyped `var target = null`, `p_target: Node2D`, `-> Node2D`, and duck-typed `Node2D` casts. Fixes the persistent `[tower] projectile has no setup()` warning flood that breaks every playtester run on commit d275dd9.

## 2026-06-02 (audit-polish — comprehensive 0-kills projectile fix)

- fix(combat+pool): two-path 0-kills fix — (1) base_tower falls back to preloaded _projectile_scene when pool returns a script-detached node (has_method("setup")=false in headless CI parse-order regression), discarding the bad node without recycling it; (2) projectile_pool exhausted-pool fallback now always adds fresh node to scene tree via get_tree().root.add_child when _container is null (unparented node silently blocks _process). Closes issue #567; supersedes PR #571.

## 2026-06-01 (audit-polish — upgrade tint visibility fixes)

- polish(tint): tier-1 path tint strength 0.45→0.70 (first upgrade now clearly visible); tier-2 0.85→0.90; path-B blend weight 1.5× so A3+B1/B2 clearly differ from A3+B0; tween bug fixed — upgrade_path() flash animation now returns to path tint instead of erasing it back to WHITE. Closes playtest-feedback #558 and #562.

## 2026-06-01 (audit-polish — projectile pool no-setup infinite loop fix)

- fix(combat+pool): projectile acquire→no-setup→release loop: base_tower now queue_frees broken projectiles instead of returning them to the pool (which caused re-acquire on every attack tick, silently discarding all shots). projectile_pool.acquire() now skips and destroys script-detached slots via has_method("reset_for_pool") guard. Towers in wave simulator now fire correctly.
- chore(roadmap): tick off Cumulus meta-progression (shipped 2026-05-08 in PR #553, was still [ ])

## 2026-05-08 (audit-polish — Cumulus meta-progression + ROADMAP hygiene)

- feat(meta): Cumulus-Punkte system: 1 point per wave cleared (persists in save file), +50 starting gold unlocked at 100 points. Balance shown on game-over screen for both victory and defeat. Three P1 ROADMAP items ticked as already-done (hero system, session-opener.yml, loop-killswitch.yml).

## 2026-05-08 (audit-polish — 0-kills regression root cause fix #527)

- fix(combat+pool): EnemyPool._deactivate() now calls remove_from_group("enemies") so parked pool enemies can't be targeted by towers — root cause of persistent 0-kills after #522. Additional guards: _find_target() filters is_dead enemies, _cleanup_scene() marks is_dead=true before releasing. Closes #527; also improves enemies_remaining accuracy in playtest summary (no more ghost counts from previous scenarios).

## 2026-05-07 (audit-polish — sequential star reveal on victory)

- polish(vfx): victory screen stars now pop in one-by-one (BTD-style) — each earned ★ bounces in from 1.45× scale with a gentle ascending chime (play_upgrade), 0.2s gap between stars. Panel shows "☆☆☆" immediately for layout stability. Stars reveal starts 2.65s after level ends (0.15s after panel fades in). Defeat screen unchanged.

## 2026-05-07 (audit-polish — i18n final sweep)

- polish(i18n): game_over ★/☆ stars instead of */-, "K.O.s dä Rundi" instead of "Kills dä Wäll"; main_menu "%d K.O." instead of "%d Kills"; hud combo badge "RUUSCH! ×%d · %.1f× Gold" (proper × glyph); wave-preview enemy count "%d× Brötli" consistent with speed button. Closes all remaining player-visible English strings.

## 2026-05-07 (audit-polish — fix 0-kills combat regression #518)

- fix(combat+playtest): 5 fixes for issue #518 (0 kills all scenarios): (1) BaseTower fallback distance scan now runs every frame unconditionally — was only when list empty, missing enemies partially detected by Area2D at 8×; (2) _cleanup_scene() uses EnemyPool.release() instead of queue_free() so pool slots aren't wasted after stress test; (3) _instantiate_tower() adds towers to "towers" group for adjacency/buff correctness; (4) new_towers_showcase timers now use ignore_time_scale=true so combat runs 1.2s real not 0.4s; (5) stress_test now calls start_next_wave() — fixes #519 (wave stuck at Bereit). Added per-scenario diagnostic print.

## 2026-05-07 (audit-polish — DPS abbreviation → Swiss German)

- polish(i18n): "DPS" replaced with "S/Sek" (Schade pro Sekunde) in both the side-shop compact label and the tower-info stats panel. Branching upgrade maxed-path label "[MAX]" → "[✓ Max]" to match the Swiss German style used elsewhere. Last player-visible English abbreviation in the tower UI.

## 2026-05-06 (audit-polish — Swiss German consistency sweep #2)

- polish(i18n): Difficulty picker labels "EASY"→"EIFACH" and "HARD"→"BRUTAL"; "min 1★ free"→"min 1★ gratis" in level_select. Amösius slow.tres: corrected display_name "Amosius"→"Amösius" (missing umlaut), Swiss German description + upgrade_names (Sticky Tongue/Mega Lick/Tongue God all translated), path_b tier-3 "Tongue God"→"Zunge-Gott". Lemurius basic.tres: Swiss German description + upgrade_names (Banana Barrage/Primate Power/Lemur Lord translated).

## 2026-05-06 (audit-polish — playtester timeout fix)

- fix(playtest): priority scenarios (upgrades/new_towers/stress/bughunt) moved before healthy loop so they always run; healthy coverage reduced to L1-L3 with 20s/8-shot cap per scenario; closes #499 #491. Also closed stale fixed issues #498 #490 #496.

## 2026-05-06 (audit-polish — Swiss German sweep + PR template)

- polish(i18n): Swiss German consistency pass — "Kills:" → "K.O." on level select totals badge; "+ HEAL" threat badge → "+ HEILE"; wave announcement "WELLE %d" → "WÄLLE %d" (consistent with "WÄLLE GSCHAFFT!" celebration); wave label + farm tooltip + aminos shop description all updated to "Wälle". Added `.github/PULL_REQUEST_TEMPLATE.md` verify-checklist (P1 ROADMAP item ticked).

## 2026-05-06 (audit-polish — per-path projectile tier skins)

- polish(vfx): per-tier projectile skins — banana grows + gildens at tiers 1–3; pollen shifts gold→icy→fire→cosmic; flask goes green→cyan→purple→crimson; volleyball gains gold then rainbow stripes; tongue thickens + deepens red at each tier. `shoot_tier` passed through `setup()` p_tier arg; `reset_for_pool()` resets tier to 0. Closes ROADMAP P1 "Per-path projectile tier skins (D4)"

## 2026-05-05 (audit-polish — L5 balance fix + playtester kill tracking)

- balance(level): L5 wave 1 fast 25→12 (delay 0.3→0.35s), wave 2 swarm 40→22 (delay 0.18→0.22s), starting_gold 160→185, starting_lives 18→20; closes #431 #412 (9-11 lives lost by wave 2)
- feat(playtest): added level_kills column to playtester summary table so kill=0 issues like #475 are visible in CI output without reading screenshots

## 2026-05-05 (audit-polish — L2 balance + level-select contrast)

- balance(level): L2 rebalanced — enemy counts reduced ~17% in waves 3-10, starting_gold 130→160; fixes playtester LOST with 47% kill rate (closes #458)
- polish(level-select): locked level buttons now clearly visible — bg Color(0.18→0.32, ...), border brighter; Dimmer opacity 0.6→0.45; semi-transparent dark backdrop panel behind LevelGrid for contrast against background art (closes #460)

## 2026-05-05 (audit-polish — D7 tier-3 boss kill death-cam)

- polish(vfx): D7 Tier-3 boss kill cinematic — bullet-time (Engine.time_scale 0.05 for 0.4s real), 4-burst gold/white spark explosion, "✦ [Tower Name]" floating name bubble above killing tower; source_tower plumbed through take_damage → die → _celebrate_boss_death for all projectile/cone attack paths; ticked drag-and-drop + scrollable shop P0s as verified-done in code

## 2026-05-05 (audit-polish — CI false positive fixes + observability push repair)

- polish(hud): Swiss German consistency — targeting tooltip "First/Last/Strong/Close" → "Erschti/Letschti/Nöchschti/Stärchsti"; max-upgraded tower button "MAXIMUM" → "Maximal! ✓"
- chore(pr-backlog): closed 3 stale duplicate audit-grid PRs (#454, #456, #457); merged #441 (swarm enemy bg removal + L2 path opacity fix)
- docs(roadmap): ticked 3 stale P0 CI items (ci-monitor false positive, workflow-lint, drift-scan/weekly-digest); added "Restore observability push" P0; documented workflow fixes blocked by missing `workflows` token scope

## 2026-05-05 (audit-polish — art cleanup + ROADMAP ticks)

- chore(assets): deleted 8 orphaned PNG+import pairs from towers/ (amosius_raw, cordula_final, cordula_upgrade, cordula_v2, jojo_final, jojo_v2, kuhne_final, kuhne_v2) — ~13.8 MB recovered; none referenced in .tres/.gd/.tscn files
- docs(roadmap): ticked 3 completed P0 items — enemy textures wired (verified all 11 have custom_texture), damage variants shipped via PR #387, superseded art deleted

## 2026-05-05 (audit-polish — merge backlog clear + rescue 406/433)

- fix(hud): Züridütsch taunts, preview colors, short names for all 16 enemy types — berserker/cumulus_blob/linsen_golem/smoothie_slime/tofu_ninja now have Swiss German text instead of falling through to capitalize(); "Tofu"→"Schwarm", adds Schatte/Büchse/Gipfeli/Glacé etc. (rescued from dirty PR #406)
- fix(playtest): SHOT_INTERVAL timer now uses ignore_time_scale=true — at 8× time_scale each tick was firing after 0.3s real instead of 2.5s real, giving only ~5s total; now 16×2.5s=40s real=320s game time — fixes waves never reaching WON (rescued from dirty PR #433)
- fix(playtest): summary.md now notes expected headless CI FPS range (10–15) to prevent false P0 perf issues
- polish(level-select): locked circle borders wider + brighter with drop-shadow; locked labels brighter; button bg less dark for better mobile contrast (rescued from dirty PR #433)
- chore(backlog): closed 10 stale/duplicate PRs; pushed ci-trigger commits to unblock 4 PRs (#387 #400 #403 #441) stuck because actionlint/bash-syntax checks never ran pre-#444

## 2026-05-04 (audit-polish — dev_menu parse fixes)

- fix(dev_menu): remove extra `)` at line 1040 inside match block — GDScript parse error when building export
- fix(dev_menu): add missing `_count_tres()` and `_count_pngs()` helper functions — called in _populate_build_tab() but never defined, causing SCRIPT ERROR on every export build

## 2026-05-04 (audit-polish — perf: EffectPlayer caps + glow ring + range circle)

- perf(effects): EffectPlayer concurrent caps (MAX_FLASH 8, MAX_DUST 6, MAX_MISC 10) prevent burst CPUParticles2D allocation during heavy waves; particle counts reduced ~30% for muzzle/impact/death effects (closes partial #409)
- perf(tower): glow ring draw calls cut 83% — 5 layers × 48 segments → 2 × 20 segments; visual glow preserved via opacity split
- perf(tower): range_circle._process disabled via set_process(false) when hidden (visibility_changed signal) — eliminates per-tower per-frame tick during normal gameplay

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
