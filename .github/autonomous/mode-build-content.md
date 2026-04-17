# Mode: Build New Content

Focus on **extending the game world**. Pick ONE of the following:

1. **New level** (if levels 4-10 are unfinished in ROADMAP.md):
   - Create `resources/level_data/level_N.tres` with 10 wave definitions
   - Create `scenes/game/level_N.tscn` (copy structure from level_3.tscn,
     draw a new path)
   - Add a Swiss German story intro in `scripts/systems/lore.gd`
   - Do NOT generate background art in this PR — leave a TODO note, the art
     can be added in a separate run or by the user.

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

## Example good PRs in this mode

- `feat(level): add Level 4 — D'Kasse vom Chaos with 10 waves`
- `feat(enemy): add "Glitzer-Gurke" splitter enemy (breaks into 2 on death)`
- `feat(upgrade): add Lemurius branching path (fast vs. damage)`
