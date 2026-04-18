# Changelog

Running log of changes made by the autonomous dev loop. Newest first.
Each run appends one line.

## 2026-04-18

- art(maps+enemy): regenerated Level 2 Tiefchüel background (Stability SD3.5, 16:9, frozen aisle with icicles/frost-mist/freezer doors); added "Gepanzerts Soja-Steak" elite tank enemy (soja_steak_elite.png, 700hp/30armor, tank_elite.tres); wired into Level 3 wave 9 for harder penultimate push
- polish(mobile): all HUD buttons ≥ 52px touch targets; PauseButton 60px; safe-area margins via DisplayServer.get_display_safe_area() for notched phones; TowerInfo panel taller for new button sizes (ROADMAP P1 #34 #35 #36); ticked 10 completed ROADMAP items that were shipped in #43 but never checked off
- docs(roadmap): 5 new spec'd ideas — Migros-Cumulus meta-progression, "De Chef!" boss finisher, Rausch-Modus combo frenzy, Züri-Tram MOAB boss, Wagli-Räge active power; architecture note on wave_manager spawn-stacking root cause
- polish(placement): invalid placement toast ("Z'nöch am Turm!" / "Z'nöch am Wäg!" / "Am Rand bleibe!") with tween fade-out (ROADMAP P0 #24); health bar smoothly tweens over 0.2s on damage (ROADMAP P1 #41)

## 2026-04-17

- chore(validate): removed orphaned root main.tscn (empty bare Node2D, unreferenced); full signal/resource/scene audit passed clean
- polish(hud): tower cost label turns red when unaffordable, gold when affordable (ROADMAP P0 #28)
- Set up autonomous dev loop (GitHub Actions, 6h cron, 4 rotating modes)
- Added ROADMAP.md as the shared task list for the loop
- Fix(tower): JoJo splash can now target flying enemies (ROADMAP P0)
