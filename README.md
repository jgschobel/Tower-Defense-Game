# Affoltern Banani Raubzug

A mobile tower defense game built in Godot 4.6, set in Migros Affoltern, Zürich. All text in Swiss German (Züridütsch).

**Live web build**: https://jgschobel.github.io/Tower-Defense-Game/

## The Story

Lemurius (lemur, throws bananas), Amösius (gecko, stuns with tongue), Kühne (flower girl, pollen attacks), JoJo (mad chemist, splash chemicals + acid pool), and Cordula (pirate carnival girl, volleyballs) fight cursed vegan supermarket products controlled by De Vegan-Tüüfel.

## Features

- **5 playable tower characters** with branching BTD-style upgrade paths (A+B), per-tower projectile styles, per-character taunt dialogue
- **7 enemy types**: Brötli, Turbo-Toblerone, Cervelat, Dr. Rivella (healer, visible aura), Fliegendi Fondue, Tofu-Schwarm, De Vegan-Tüüfel (boss)
- **7 playable levels** with unique paths + themes:
  - L1 Migros Eingang, L2 Tiefchüel-Abteilig (pretzel path), L3 Bäckerei, L4 Chäsi-Keller, L5 Kasse (3-boss finale), L6 Parkhuus (bonus, 5-boss), L7 Dach
- **10 waves per level** escalating through basic → fast → tank → flying → healer → boss
- **BTD-style side-shop**: right-anchored scrollable tower shop, collapsible handle, drag-and-drop placement from shop button straight to the map
- **Landscape orientation** (1280x720) optimized for mobile landscape; responsive safe-area handling
- **Story cutscenes** — typewriter text + character portraits, Swiss German throughout
- **Procedural chiptune music** with menu/game track switching, drums on the game track
- **Visual polish**:
  - Tower: stone pedestal, drop shadow, tier pips showing upgrade state
  - Enemy: drop shadow, healer heal-aura, bobbing walk, death spin
  - Combat: muzzle flash, impact sparks, screen-shake on boss reveal/death
  - HUD: wave progress bar, next-wave preview panel, ⚕/☠ threat badges, boss HP bar, life-lost red flash, gold pulse
- **Save/load** with star ratings (1–3 stars per level), lifetime kill counter, total stars badge on menu

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

The repo runs a 24/7 agent loop via GitHub Actions:
- `playtest` cron runs 4×/day, spawns 6 scenarios, files issues with `playtest-feedback` label
- `autonomous-dev` cron picks a ROADMAP item, ships it as a PR, auto-merges on validation pass
- `deploy-web` publishes to GitHub Pages on every merge to `main`
- Circuit breaker: max 25 merges / 24h, 4 Opus runs / 5h

Observability at `docs/observability/ledger.md` and `docs/observability/playtest_latest.md`.
