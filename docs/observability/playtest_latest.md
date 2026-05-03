# Playtest Latest

Run: 25283846968 @ 2026-05-03T16:01:56Z · Status: **ok** · Screenshots: 100 total, 7 key shots committed below

## Key screenshots (Read these for visual audit)

- `docs/observability/screenshots/00_menu.png`
- `docs/observability/screenshots/L1_healthy_final.png`
- `docs/observability/screenshots/L2_healthy_final.png`
- `docs/observability/screenshots/L3_healthy_final.png`

## Summary

# Playtest v3 Summary

Timestamp: 2026-05-03T16:01:46
Total duration: 114.8s

| Scenario | Duration (s) | Avg FPS | Min FPS | Final Lives | State | Enemies Remaining |
|---|---|---|---|---|---|---|
| ui_tour | 2.0 | 18.7 | 1.0 | 20 | MENU | 0 |
| L1_healthy | 23.6 | 14.5 | 2.0 | 25 | PLAYING | 10 |
| L2_healthy | 20.7 | 12.9 | 2.0 | 25 | PLAYING | 9 |
| L3_healthy | 22.2 | 12.6 | 2.0 | 22 | PLAYING | 11 |
| L4_healthy | 21.9 | 13.8 | 2.0 | 20 | PLAYING | 13 |
| L5_healthy | 22.3 | 12.8 | 2.0 | 18 | PLAYING | 22 |

## Interpretation hints

- **L1/L2/L3_healthy**: should end WON, lives > 0. LOST here means the scenario tower placements no longer counter the waves (rebalance or retune placements).
- **upgrades**: screenshots walk Lemurius from tier-0 through path-A then path-B. Tints should shift noticeably between states — if they look identical, the _apply_path_tint blend is broken.
- **stress**: 80 simultaneous enemies. Avg FPS < 30 = performance regression; projectile / pathfollow scaling needs attention (object pooling overdue).
- **bughunt**: rapid invalid placements. Expect placement toasts firing and no crashes. shot `bughunt_after_cancel` should show the normal HUD, no stuck ghost tower.
- **anim_*** frames are GIF source — ffmpeg stitches them in the workflow.

## Full artifact
https://github.com/jgschobel/Tower-Defense-Game/actions/runs/25283846968
