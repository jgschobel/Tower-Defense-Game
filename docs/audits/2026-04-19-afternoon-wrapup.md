# Audit 2026-04-19 afternoon — session wrap-up

Summary of state after the side-shop sprint + 2 audit rounds + L6/L7
content + EffectPlayer.

## Big shipped work in this session

- **BTD-style side-shop** (PR #110/#111/#112) — right-anchored scrollable,
  per-row tint, affordability visuals (dim + tri-color cost),
  collapsible ▶/◀ handle with 0.22s cubic slide, responsive width
- **Drag-and-drop tower placement** (#99, fixed tap regression in #107)
- **Tower memes** (#99) — each friend character floats random Swiss-German
  taunt lines every 6-12s
- **Tower visuals**: stone pedestal, drop shadow, tier pips (#99, #109)
- **Enemy drop shadows + healer aura** (#100, #101)
- **Per-tower kill counter** (#102) + **lifetime kill counter** (#90)
- **Level 4 D'Chäsi-Keller** (#84), **Level 5 D'Kasse Endkampf** (#87),
  **Level 6 S'Parkhuus bonus** (#100), **Level 7 S'Dach** (#109).
  MAX_LEVELS 3 → 7.
- **Tofu-Schwarm enemy** (#96)
- **EffectPlayer autoload** — muzzle flash, impact sparks, boss
  screen-shake, concurrent-shake guard (#82, #108)
- **Boss HP bar** + threat badges (⚕/☠) + next-wave preview (#94, #93)
- **Boss-kill celebration** — 3× sparks + shake + "TÜÜFEL GSTÜRZT!"
  floating text (#109)
- **Wave progress bar** + "Wälle gschafft!" celebration between waves
- **Persistent stats badge** on main menu + level select (★/☠)
- **Life-lost red flash**, **gold pulse**, **speed-button tint**,
  **auto-wave toggle green-when-on**

## Audit findings addressed

Three audit rounds ran in parallel with the feature work:

- **Round 1** (#92) — 8 findings: `data.health` typo, glow-tween leak,
  enemies_in_range dedupe, L4/L5 bg map, ★☆ unicode stars, shop
  idempotency, click SFX on 7 buttons, DRAWN_STYLES hoist
- **Round 2** (#101) — 7 findings: sell-confirm silently disarmed on
  gold tick, healer-aura skipped on photo-skinned healers,
  threat-timer idempotency, boss-bar responsive width, next-wave pulse
  stacking, healer redraw throttle, `show` shadow rename
- **Round 3** (#108) — 4 findings: hide/show flash on tower re-tap,
  screen-shake concurrency, options-menu double-instance guard,
  focus-loss ghost cleanup + CLAUDE.md doc drift cleanup
- **Deep audit** (#107) — 3 P0 + 4 P1 + doc drift: pause-menu Godot3
  API crash, drag-drop tap regression, star save/load key inflation,
  boss HP bar NaN, HUD WaveManager group lookup, _load_wave_data null
  guard, swarm scale-up, L6 balance (1100 → 1500g)

## Still open

- L8-L10 content (stubbed-out plan in ROADMAP)
- Dedicated L4-L7 background art (reusing placeholders)
- `docs/design_polish.md` spec
- PAT-based user-attachment fetch for the friend-photo issue pipeline
  (requires user to set USER_ATTACHMENT_PAT secret)
- Dust-puff particles on enemy step

## Playtest state

Playtest bot is running (issues #103-106 filed at 13:43 UTC on build
166bcf9 — ~2 hours old). Issues #103 and #106 already fixed by the
time the bot filed them. #104 toast-stacking fixed in #113. #105
stress FPS 20 is a desktop headless render limit at 80 enemies —
pool is already in place.

Observability commit step was silently failing. Replaced the
`git checkout main` rebase-loop with a snapshot-and-reset approach
in #113. Next playtest cron should populate `ledger.md` +
`playtest_latest.md` + `screenshots/`.

## Numbers

PRs shipped this session (chronologically):
#82, #83, #84, #85, #87, #88, #89, #90, #91, #92, #93, #94, #95, #96,
#97, #99, #100, #101, #102, #107, #108, #109, #110, #111, #112, #113
→ **26 PRs** merged on 2026-04-19 (afternoon+evening).

Open issues: only the 3 friend-photo ones from 2026-04-18 (blocked on
GitHub user-attachment 404 + no PAT set). 0 open playtest-feedback.
0 open ci-failure.
