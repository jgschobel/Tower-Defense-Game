# Roadmap — Affoltern Banani Raubzug

The autonomous dev loop reads this file every 6 hours and picks the
highest-priority unchecked item matching the current run mode.

**Priority order**: P0 (blocking) → P1 (important) → P2 (nice-to-have).
Within a priority, top-of-list wins.

---

## 🔥 P0 — Blocking / Bugs

- [x] Fix JoJo splash tower `can_target_flying = true` (PLAN #12)
- [ ] DamageType enum actually applied in base_enemy.gd (magic ignores armor, physical reduced by armor) — PLAN #16
- [ ] Show feedback text on invalid tower placement ("Z'nöch am Wäg!" / "Z'nöch am Turm!") — PLAN #24
- [ ] Tower cost affordability color (yellow/gold affordable, red unaffordable) — PLAN #28

## ⚡ P1 — Important (Polish & UX)

- [ ] Enemy count on HUD ("12 übrig" next to wave counter) — PLAN #26
- [ ] Tower range preview stat in shop buttons — PLAN #29
- [ ] Reposition tower info panel so it doesn't overlap map — PLAN #30
- [ ] HUD buttons ≥ 50px for mobile touch — PLAN #34
- [ ] Pause button 60px minimum — PLAN #35
- [ ] Safe area margins for notches/status bars — PLAN #36
- [ ] Health bar smooth tween over 0.2s — PLAN #41
- [ ] Screen shake on boss spawn (level 3 wave 10) — PLAN #42
- [ ] Wave start announcement flies across screen — PLAN #43
- [ ] UI click SFX wired to every button press — PLAN #52
- [ ] Boss entrance SFX (low rumble) — PLAN #54
- [ ] Tutorial overlay for first-time play — PLAN #27
- [ ] Level select background uses levelselect_bg.png — PLAN #31
- [ ] Story screen: small centered portraits, dark overlay — PLAN #32
- [ ] Main menu buttons: panel behind buttons over artwork — PLAN #33
- [ ] Proper star icons instead of `*`/`-` characters — PLAN #70

## 🎮 P1 — New Content

- [ ] Level 4 data + scene + story intro (D'Kasse — cash register chaos)
- [ ] Level 5 data + scene + story intro (D'Lager — warehouse descent)
- [ ] Level 6 data + scene + story intro (D'Parkhuus)
- [ ] Level 7 data + scene + story intro (D'Dach — rooftop showdown)
- [ ] Level 8 data + scene + story intro (D'Chüelraum — deep freeze)
- [ ] Level 9 data + scene + story intro (D'Zentrale — HQ infiltration)
- [ ] Level 10 data + scene + story intro (Final: De Vegan-Tüüfel's Throne)
- [ ] Endless mode after Level 10 — PLAN #76
- [ ] Katzensee level using saved photo reference — PLAN #61
- [ ] Migros entrance level using saved photo reference — PLAN #62

## 🧪 P2 — Branching Upgrades (PLAN #72)

- [ ] Lemurius: Schnelli Banane vs Scharfi Banane → Explosivi Khaki
- [ ] Amösius: Längeri Zunge vs Chläbrigeri Zunge → Insta-Reel Attacke
- [ ] Kühne: Giftige Pollen vs Iis-Blüete → Füür-Lilie
- [ ] JoJo: Stärcheri Formel vs Chaos-Chemie → Lotter JoJo
- [ ] Cordula: Volleyball Hagel vs Ankerhake → Party Kanone
- [ ] Lotter JoJo random effects — PLAN #73

## 🏎 P2 — Performance

- [ ] Object pooling for projectiles — PLAN #63
- [ ] Object pooling for enemies — PLAN #64
- [ ] Viewport scaling across phone sizes — PLAN #66
- [ ] Battery optimization: stop music gen when backgrounded — PLAN #67

## 💡 Ideas To Explore

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

## 🎯 P2 — Polish & Extras

- [ ] Upgrade visual path (tint/glow per upgrade level) — PLAN #22
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
