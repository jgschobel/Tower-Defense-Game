# Affoltern Banani Raubzug

A mobile tower defense game built in Godot 4.6, set in Migros Affoltern, Zürich. All text in Swiss German (Züridütsch).

**Live web build**: https://jgschobel.github.io/Tower-Defense-Game/

## The Story

Lemurius (lemur, throws bananas), Amösius (gecko, stuns with tongue), Kühne (flower girl, pollen attacks), JoJo (mad chemist, splash chemicals + acid pool), and Cordula (pirate carnival girl, volleyballs) fight cursed vegan supermarket products controlled by De Vegan-Tüüfel.

## Features

- **5 playable tower characters** with branching BTD-style upgrade paths (A+B), per-tower projectile styles, per-character taunt dialogue (with per-instance shuffled sub-pools so two same-type towers never chorus)
- **10 enemy types**: Brötli, Turbo-Toblerone, Cervelat, Dr. Rivella (healer, visible aura), Fliegendi Fondue, Tofu-Schwarm, Schatte-Tofu (camo), Lead, Regrow, De Vegan-Tüüfel (boss)
- **10 playable levels** with unique paths + themes:
  - L1 Migros Eingang, L2 Tiefchüel-Abteilig (pretzel path), L3 Bäckerei, L4 Chäsi-Keller, L5 Kasse (3-boss finale), L6 Parkhuus (bonus, 5-boss), L7 Dach, L8 Coop-Einbruch (rival store, blue grid), L9 Cumulus-Punkte-Kern (purple spiral), L10 Finale im Tüüfel-Äste (5-boss epic finale)
- **10 waves per level** escalating through basic → fast → tank → flying → healer → camo → lead → regrow → boss
- **BTD-style side-shop**: right-anchored scrollable tower shop, collapsible handle, drag-and-drop placement from shop button straight to the map. Active row gets a gold-bordered highlight while placing.
- **Landscape orientation** (1280x720) optimized for mobile landscape; responsive safe-area handling
- **Story cutscenes** — multi-character paginated dialogue with rotating speakers, portrait highlights, typewriter text + page-crossfade transitions, guest characters (Micheli L3 security, Trudi L5 cashier). Swiss German throughout.
- **Procedural chiptune music** with menu/game track switching, drums on the game track
- **Visual polish**:
  - Per-level CanvasModulate tint (cool blue L2, acid green L4, neon cyan L6) + animated flicker for fluorescent (L1) and neon (L6) atmospheres
  - Per-level CPUParticles2D atmosphere overlays (frost, flour, acid bubbles, confetti, rain, leaves, sparks, glitch, embers)
  - Tower: stone pedestal, drop shadow, tier pips, animated dashed range circle, place-pop animation
  - Enemy: drop shadow, healer heal-aura, bobbing walk + dust-puff particles on each step, death spin
  - Combat: muzzle flash, impact sparks, screen-shake on boss reveal/death
  - HUD: wave progress bar, next-wave preview panel with per-enemy icons, ⚕/☠ threat badges, boss HP bar, life-lost red flash, gold pulse, wave-start banner slide
- **Save/load** with star ratings (1–3 stars per level), lifetime kill counter, total stars badge on menu, persistent Aminos meta-currency

## Development

- **Engine**: Godot 4.6 (GL Compatibility renderer for mobile)
- **Language**: GDScript
- **AI workflow**: Claude Opus for architecture + planning, Sonnet sub-agents for art/validation/playtesting
- **Art**: Stability AI img2img for friend character icons, Imagen 4 / Stability text-to-image for backgrounds
- **Autonomous loop**: cron-triggered playtest bot, deploy-web on every merge, observability ledger in `docs/observability/`

See `AGENTS.md` for the multi-agent architecture, `CLAUDE.md` for coding conventions, `ROADMAP.md` for priorities.

## Characters

| Tower | Cost | Projectile | Special |
|-------|------|------------|---------|
| Lemurius | 100 | Bio-Banane | All-rounder, spinning projectile |
| Kühne | 200 | Pollen-Wölkli | Long range, targets strongest |
| JoJo | 250 | Chemie-Flask | Splash AoE + lingering acid pool DoT |
| Cordula | 150 | Fasnachts-Volleyball | Fast, splash bounces |
| Amösius | 180 | Klaibrigi Zunge | 40% slow for 2.5s |

Each tower has branching upgrade paths (A + B, 3 tiers each) with unique tints + tier pips visible on the map.

## Quick Start

1. Open in Godot 4.6+
2. Run the project (F5) — main scene is `scenes/ui/main_menu.tscn`
3. "RAUBZUG STARTE" → pick a level → story cutscene → place towers → send waves

## Autonomous Loop

The repo runs a 24/7 agent loop via GitHub Actions (21 workflows total):

**Production loop:**
- `autonomous-dev.yml` — every 4h, picks a task mode (test-validate / audit-polish / ideate / build-content / self-improve / generate-art), invokes Claude Code, validates via `validate.sh`, auto-merges on pass. Circuit breaker: max 25 merges / 24h, 4 Opus runs / 5h.
- `deploy-web.yml` — every push to `main` builds Godot HTML5 export and deploys to GitHub Pages. Emits `build-info.json` next to `index.html` with current commit SHA + build timestamp + content counts (phone-checkable freshness indicator).
- `playtest.yml` — 6h cron + push trigger. Headless Godot bot runs 6 scenarios (L1/L2/L3 healthy + upgrades + stress + bughunt), Claude vision agent files issues with `playtest-feedback` label.
- `audit-grid.yml` — chains off playtest, stitches per-level screenshots into a 4×4 grid for visual review.
- `sim-gate.yml` — wave-balance simulator runs on PRs touching `tower_data` / `enemy_data` / `level_data`, fails the PR if a level is unwinnable or trivially clearable.

**Self-observation:**
- `loop-health.yml` — every 6h, files a `loop-broken` issue if autonomous-dev hasn't run in 8h, deploy-web has no success in 24h, or any workflow has been paused >7 days. Writes `docs/observability/loop-status.md` with per-workflow last-run + conclusion + last-success — single-file dashboard.
- `ci-monitor.yml` — listens to all 12 critical workflows; on any failure, files an issue AND mirrors the log tail into `docs/observability/failures/<workflow>__<run_id>.log` so chat-session debugging never depends on the user fetching logs manually. INDEX.md tracks the last 50 failures.
- `pause-watchdog.yml` — fails CI on any PR that re-introduces a `# PAUSED` comment older than 7 days.
- `workflow-lint.yml` — `actionlint` + `bash -n` on every `run: |` block on every PR touching `.github/workflows/`. Catches the prose-comment-without-`#` bug class that broke CI for 9 days in 2026-04.

**Hygiene:**
- `cleanup.yml` daily 05:00 UTC — sweeps stale `claude/auto/*` branches and old PRs.
- `drift-scan.yml` Mondays 07:00 UTC — flags dead GDScript functions, orphaned assets, ROADMAP-vs-CHANGELOG drift.
- `weekly-digest.yml` Mondays 06:00 UTC — files a digest issue summarizing the week, optionally emails via Resend.

Observability lives in `docs/observability/`:
- `loop-status.md` — health dashboard
- `deploy_latest.md` / `playtest_latest.md` / `sim_latest.md` / `photo_latest.md` — last-run summaries per system
- `ledger.md` — append-only one-line log per run, capped at 150 lines
- `failures/INDEX.md` + per-run `.log` files — full failure context for debugging
