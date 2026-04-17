# Mode: Build New Content

Focus on **extending the game world**. Pick ONE of the following:

1. **Complete new level** (if levels 4-10 are unfinished):
   - Create `resources/level_data/level_N.tres` with 10 balanced waves
     — study wave progressions in existing levels so difficulty scales
     properly
   - Create `scenes/game/level_N.tscn` with a unique, interesting path
     (copy structure from level_3.tscn but draw a *different* curve —
     avoid copying the same shape)
   - Add Swiss German story intro in `scripts/systems/lore.gd`
     — write 3-5 paragraphs of real flavor, not a one-liner
   - Wire the level into `GameManager.MAX_LEVELS` and any level-select
     metadata (colors, unlock order)
   - If art generation is needed, leave a TODO note with a specific
     Stability prompt description — the next `generate-art` run picks
     it up. Do NOT generate art in this mode.
   - **Ship all of this in ONE PR**. A "half level" isn't useful.

2. **New enemy type** — a new `.tres` in `resources/enemy_data/` with a
   distinctive mechanic (e.g., splits on death, shielded, teleporter).
   Reference it in a later level.

3. **New tower upgrade variant** — add a branching upgrade path per the
   Phase 9 plan in PLAN.md (e.g., Lemurius: Schnelli Banane vs Scharfi
   Banane). Pick one tower only per PR.

4. **Story cutscene expansion** — add dialogue lines, a mid-level intro,
   a post-level reward screen. Swiss German only.

## Constraints

- **Levels must be balanced** — don't make Level 4 drastically harder than
   Level 3. Study the wave progression in existing levels first.
- **Reuse existing enemy types** if adding a level — don't require new art.
- **New content must be wired** — a new level must be referenced in the
   level_select flow, a new enemy must appear in at least one wave.
- **Complete the content** — half-finished features are worse than
   nothing. If you start a level, finish it: data, scene, story, wiring.
- **Go deep**, not wide. Better to ship one complete level than stub
   three. Max-turns is 200 — use it.

## Example good PRs in this mode

- `feat(level): add Level 4 — D'Kasse vom Chaos with 10 waves`
- `feat(enemy): add "Glitzer-Gurke" splitter enemy (breaks into 2 on death)`
- `feat(upgrade): add Lemurius branching path (fast vs. damage)`
