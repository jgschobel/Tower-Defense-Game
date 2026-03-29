# Affoltern Banani Raubzug — Master Development Plan (60+ Items)

## Workflow
Tasks executed using agent architecture from `AGENTS.md`:
- **Conductor (Opus)** — bug fixes, game logic, creative, git
- **Art Factory (Sonnet, background)** — image generation, background removal
- **Code Scout (Sonnet)** — codebase exploration, validation
- **Build Tester (Sonnet)** — pre-push validation

---

## PHASE 1: CRITICAL BUGS (Must fix, game broken without these)

- [x] 1. **AutoButton signal not connected** — hud.tscn missing `toggled` connection to `_on_auto_button_toggled`
- [x] 2. **Hit reactions only for slow towers** — `show_hit_reaction()` only called when slow > 0, should trigger for all damage
- [x] 3. **Game speed not reset on menu** — add `Engine.time_scale = 1.0` to MainMenu._ready()
- [x] 4. **Tower info panel not cleared on game over** — can show behind defeat screen
- [x] 5. **Gold label has leading space** — hud.tscn text " 200" should be "200"
- [x] 6. **Wave counter shows "Welle 0/5" at start** — confusing, should show "Welle —" or "Bereit"
- [x] 7. **Enemy spawn with missing data crashes** — wave_manager spawns enemy even if .tres missing, null errors
- [x] 8. **Health bar updates every frame** — wasteful, should only update on health change

## PHASE 2: GAMEPLAY BALANCE

- [x] 9. **Buff Healer enemies** — heal_amount 8→15, heal_radius 80→120
- [x] 10. **Buff Tank armor** — armor 5→15 to actually matter
- [x] 11. **Nerf Amösius slow** — slow_amount 0.75→0.5, duration 4→2.5
- [ ] 12. **Fix Splash tower vs flying** — set can_target_flying = true
- [x] 13. **Balance economy** — basic tower cost 100→80 to give more early options
- [ ] 14. **Smoother difficulty curve** — level 2 starting lives 20→22
- [x] 15. **Boss spawns fewer children** — spawn_count 4→3
- [ ] 16. **DamageType enum actually used** — magic damage ignores armor, physical reduced by armor

## PHASE 3: CHARACTER ART (User provides Gemini icons, we process)

- [ ] 17. **Kühne icon** — user generates in Gemini with flower theme, we process + integrate
- [ ] 18. **JoJo icon** — user generates in Gemini with chemist theme, we process + integrate
- [ ] 19. **Cordula icon** — user generates in Gemini with pirate carnival theme, we process + integrate
- [x] 20. **Cordula tower data** — pirate carnival, hook arm, throws volleyballs, 150 cost
- [ ] 21. **Cordula upgrade path** — Volleyball → Cannonball → Party Bomb
- [ ] 22. **Tower upgrade visual changes** — icon slightly changes per upgrade level (tint, glow, border)

## PHASE 4: UI/UX IMPROVEMENTS

- [ ] 23. **Auto/Speed buttons look pro** — proper toggle styling, highlight when active
- [ ] 24. **Tower placement invalid feedback** — show text "Z'nöch am Wäg!" or "Z'nöch am Turm!"
- [x] 25. **Floating gold text on kill** — "+10" rises from dead enemy
- [ ] 26. **Enemy count on HUD** — "12 übrig" next to wave counter
- [ ] 27. **Tutorial/help overlay** — first-time-play explanation of mechanics
- [ ] 28. **Tower cost highlighting** — yellow/gold color for affordable, red for too expensive
- [ ] 29. **Tower range preview in shop** — show range stat below cost
- [ ] 30. **Move tower info panel** — position above shop bar, not overlapping placement area
- [ ] 31. **Level select background** — use generated levelselect_bg.png
- [ ] 32. **Story screen readable** — small centered portraits, dark overlay, clear text
- [ ] 33. **Main menu buttons visible** — proper panel behind buttons over artwork
- [ ] 34. **HUD buttons bigger for mobile** — minimum 50px touch targets
- [ ] 35. **Pause button bigger** — 45px→60px minimum
- [ ] 36. **Safe area margins** — handle phone notches and status bars

## PHASE 5: ANIMATIONS & JUICE

- [x] 37. **Tower attack animation** — bounce/pulse when firing (tween scale 1.0→1.15→1.0)
- [x] 38. **Tower upgrade celebration** — particle burst + flash on upgrade
- [x] 39. **Enemy death particles** — poof/splat on kill
- [x] 40. **Enemy damage flash** — already exists but improve (0.15s flash → proper hit stop)
- [ ] 41. **Health bar smooth tween** — animate value change over 0.2s
- [ ] 42. **Screen shake on boss spawn** — camera shake when M-Tüüfel appears
- [ ] 43. **Wave start announcement** — "WELLE 3!" text flies across screen
- [x] 44. **Next wave button pulse** — glowing pulse animation when available
- [x] 45. **Sell tower shrink animation** — scale to zero over 0.3s before free
- [x] 46. **Game over entrance** — fade in with dramatic tween
- [x] 47. **Pause menu fade** — 0.2s fade-in instead of instant appear
- [x] 48. **Selected tower glow** — pulsing outline when tower is tapped/selected

## PHASE 6: AUDIO

- [x] 49. **Tower fire SFX** — procedural beep/pop per tower type (different pitch)
- [x] 50. **Enemy death SFX** — short splat sound
- [x] 51. **Wave start SFX** — alarm/horn sound
- [ ] 52. **UI click SFX** — button press feedback
- [x] 53. **Upgrade SFX** — ascending chime
- [ ] 54. **Boss entrance SFX** — dramatic low rumble
- [ ] 55. **Music improvements** — add drum pattern, vary between levels
- [x] 56. **Music pauses during pause menu** — respect tree.paused

## PHASE 7: LEVEL CONTENT

- [x] 57. **Level 2 scene** — unique ice-blue path, frozen section background
- [x] 58. **Level 3 scene** — unique bakery path, warm brown background
- [ ] 59. **Levels 4-10 data** — wave definitions, enemy compositions, difficulty scaling
- [ ] 60. **Levels 4-10 lore** — Swiss German story intros for each chapter
- [ ] 61. **Katzensee level** — outdoor lake map using saved photo reference
- [ ] 62. **Migros entrance level** — self-scan area using saved photo reference

## PHASE 8: PERFORMANCE (Mobile)

- [ ] 63. **Object pooling for projectiles** — reuse instead of create/free
- [ ] 64. **Object pooling for enemies** — reuse instead of create/free
- [ ] 65. **Health bar update only on change** — not every frame
- [ ] 66. **Viewport scaling** — proper handling for different phone sizes
- [ ] 67. **Battery optimization** — stop music gen when backgrounded

## PHASE 9: POLISH & EXTRAS

- [ ] 68. **Lore panel in Swiss German** — main_menu backstory still partially English
- [ ] 69. **Enemy preview icons in story** — show actual sprites not just text
- [ ] 70. **Star display** — proper star icons instead of * and -
- [ ] 71. **App icon** — custom icon featuring Lemurius & Amösius
- [ ] 72. **Upgrade path system** — 2 choices per upgrade:
  - Lemurius: Schnelli Banane (fast) vs Scharfi Banane (damage) → Explosivi Khaki
  - Amösius: Längeri Zunge (range) vs Chläbrigeri Zunge (slow) → Insta-Reel Attacke
  - Kühne: Giftige Pollen (poison DoT) vs Iis-Blüete (freeze) → Füür-Lilie (AoE fire)
  - JoJo: Stärcheri Formel (damage) vs Chaos-Chemie (random effects) → Lotter JoJo
  - Cordula: Volleyball Hagel (multi-shot) vs Ankerhake (stun) → Party Kanone (AoE)
- [ ] 73. **Random Lotter JoJo effects** — 5% heal nearby, black poison DoT, Pups (AoE slow + funny), golden ticket (2x gold from kills)
- [ ] 74. **Android export preset** — configure for Samsung Galaxy testing
- [ ] 75. **Web export** — HTML5 for quick testing on any device

## PHASE 10: FUTURE IDEAS

- [ ] 76. **Endless mode** — infinite waves with scaling difficulty after level 10
- [ ] 77. **Friend photo gallery** — view all friends as their characters
- [ ] 78. **Achievement system** — "Killed 100 Tofu-Würschtli", "Won without losing a life"
- [ ] 79. **Daily challenge** — random tower/enemy restrictions
- [ ] 80. **Leaderboard** — compare scores with friends

---

## EXECUTION ORDER
1. Phase 1 (bugs) — Conductor fixes directly, ~15 min
2. Phase 4+5 (UI/animations) — Conductor codes while Art Factory generates backgrounds
3. Phase 3 (characters) — User provides Gemini icons, Art Factory processes
4. Phase 2 (balance) — Conductor adjusts .tres values
5. Phase 6 (audio) — Conductor adds procedural SFX
6. Phase 7 (content) — Conductor + Art Factory create levels
7. Phase 8-10 — Polish and future features
