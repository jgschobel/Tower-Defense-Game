# Changelog

Running log of changes made by the autonomous dev loop. Newest first.
Each run appends one line.

## 2026-04-17

- polish(ux): invalid placement toast "Z'nöch am Wäg!" / "Z'nöch am Turm!" with float-up animation (P0 #24); DamageType (PHYSICAL/MAGIC/PURE) now applied in armor calc + colored damage numbers; health bar tweens over 0.2s (P0 #16, P1 #41)
- polish(hud): tower cost label turns red when unaffordable, gold when affordable (ROADMAP P0 #28)
- Set up autonomous dev loop (GitHub Actions, 6h cron, 4 rotating modes)
- Added ROADMAP.md as the shared task list for the loop
- Fix(tower): JoJo splash can now target flying enemies (ROADMAP P0)
