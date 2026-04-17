# Mode: Audit & Polish

Focus on **small, safe improvements**. Pick ONE of the following:

1. **Bug fix from ROADMAP.md** — find the highest-priority unchecked bug/polish
   item and fix it. Examples:
   - Invalid placement feedback text
   - Tower cost affordability coloring
   - Mobile-sized touch targets
   - Safe area margins

2. **Visual polish** — tween a value that currently snaps, add a missing
   animation, improve a hit flash, fix an off-by-one padding issue.

3. **Quality-of-life** — add a tooltip, improve an error message, make a
   common action more discoverable.

4. **Swiss German consistency** — find English strings that should be Swiss
   German and fix them.

## Constraints

- **1-3 files changed max.**
- **No new dependencies.**
- **No refactors** — save those for `self-improve` mode.
- **Test the change** — describe in the PR body how you verified it (parse
   check, visual description, etc.).

## Example good PRs in this mode

- `polish(hud): color tower cost red when unaffordable`
- `fix(placement): show "Z'nöch am Turm!" toast on invalid drop`
- `polish(animation): tween health bar over 0.2s instead of snapping`
- `fix(mobile): increase pause button to 60px for touch targets`
