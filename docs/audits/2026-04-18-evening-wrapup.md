# Audit 2026-04-18 evening — session wrap-up before user sleep

## State of the game

### What works
- Menu → level select → gameplay loop
- 5 towers (Lemurius, Kühne, JoJo, Cordula, Amösius) with branching upgrades
- Per-tower projectile styles (banana, volleyball, flask, pollen, tongue)
- JoJo acid pool DoT on impact
- 3 levels with 10 waves each
- Object pooling for projectiles + enemies
- 2-track music bank (menu vs gameplay) with drums
- Enemy intro overlay on first-appearance per type
- Enemy bobbing walk
- HUD: top bar (gold/lives/wave/speed/auto/pause) + bottom shop + tower-info panel
- Playtest bot with 6 scenarios + screenshot capture
- Observability ledger + key screenshots committed every run
- Auto-merge loop (25/24h cap, 4 Opus 4.7/5h cap)

### What's broken
- **Friend photo pipeline via issue template**: GitHub user-attachment URLs return 404 to workflow clients. Inbox fallback works but user reports mobile web doesn't allow file upload. Needs either a desktop upload or a PAT-based fetch in the workflow.
- **Price-popup edge position**: when tower is placed near the right/left edge, the info panel clamps off-screen. Not yet fixed.
- **Design**: game still reads as "teenager garage" per user — needs a coherent polish pass.

### Potentially fixed but not yet verified on mobile build
- Crash/freeze on first attack (PR #68 just merged — deploy-web will ship fix in ~3 min)
- Blurry-empty-text-box artifacts on pooled enemies (same PR)

## Architecture snapshot

```
scripts/autoload/     → GameManager, CurrencyManager
scripts/systems/      → MusicManager, SfxManager, WaveManager,
                        TowerPlacement, GameLevel, ProjectilePool,
                        EnemyPool, LoreManager
scripts/towers/       → BaseTower, TowerData, RangeCircle
scripts/enemies/      → BaseEnemy, EnemyData
scripts/projectiles/  → BaseProjectile, AcidPool
scripts/ui/           → HUD, MainMenu, LevelSelect, GameOver,
                        PauseMenu, StoryScreen, OptionsMenu
scripts/playtest/     → AutoPlaytest (6 scenarios), WaveSimulator
```

## Known risks / tech debt

1. **Photo pipeline**: requires user action (desktop upload or PAT secret). Documented in `.github/friend_photos_inbox/README.md`.
2. **Pool stale-ref**: fixed in PR #68 but not yet validated by playtest screenshots post-deploy.
3. **Level content**: only 3 levels. Need 7+ to feel full. Queued for overnight loop.
4. **No strike animations**: towers fire but no muzzle flash or impact spark. Queued.
5. **No design polish**: typography + palette + shadow rules need consistent spec. Queued.

## Overnight autonomous loop — priority order

See ROADMAP.md "Autonomous Loop — overnight work queue" section (just added at top). Six priorities, one per run. Circuit breaker already configured.

## Session stats

14 PRs merged today across infrastructure, game correctness, perf, game feel,
per-tower projectiles, music, monster intro, and the evening's crash fix.
Roughly matches the "big day" line in ROADMAP.
