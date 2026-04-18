# Mode: Audit & Polish

**FIRST**: run `gh issue list --label playtest-feedback --state open --limit 10`.
The autonomous playtester files visual-feedback issues every 3 hours. These
are your highest-priority pickings — the game has literally been played and
these are concrete problems the tester saw. Pick the top-priority one and
fix it; close the issue as part of your PR (`Closes #N` in the PR body).

If there are no open `playtest-feedback` issues, fall back to ROADMAP items.

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

- **Scope**: one coherent polish effort. Could be 1 file, could be 5 —
  whatever it takes to finish the polish *well*. Don't split a single
  polish pass across multiple runs artificially.
- **No new dependencies.**
- **No architecture refactors** — save those for `self-improve` mode.
- **Test the change** — describe in the PR body how you verified it (parse
   check, visual description, etc.).
- **Go deep** where it adds value: if you're coloring tower cost labels
  red/gold, also consider tower-icon grayscale when unaffordable, tooltip
  messaging, and any related affordance cues. Polish is an aesthetic pass,
  not a mechanical one-line change.

## Example good PRs in this mode

- `polish(hud): color tower cost red when unaffordable`
- `fix(placement): show "Z'nöch am Turm!" toast on invalid drop`
- `polish(animation): tween health bar over 0.2s instead of snapping`
- `fix(mobile): increase pause button to 60px for touch targets`
