# Mode: Self-Improve Architecture

Focus on **code quality improvements**. This mode is the riskiest — be
extra careful and keep changes small.

Pick ONE of the following:

1. **Reduce duplication** — find 3+ identical code blocks and extract a
   helper. Only do this if the abstraction is obvious and well-named.

2. **Performance** — e.g., implement object pooling for projectiles per
   PLAN.md #63, skip redundant `_process` work, cache lookups.

3. **Code clarity** — rename a confusingly-named variable/function, add a
   single comment explaining a non-obvious invariant.

4. **Dead code removal** — find and delete unused variables, unreachable
   branches, or commented-out code blocks.

5. **Typed-ness** — add missing type annotations per CLAUDE.md conventions.

## Hard Rules

- **Scope**: one coherent refactor goal per PR. A full subsystem
  refactor (e.g. extracting a whole targeting module) is fine if it's
  cohesive. A grab-bag of 10 unrelated changes is not.
- **Do NOT rename public classes or signals** — that breaks scene files.
- **Do NOT change `.tres` resource schemas** — existing data files break.
- **Do NOT introduce new patterns or frameworks.**
- **Run a headless parse check** if Godot is available. If it fails,
   revert the change.
- If you aren't 100% sure the change is safe, **pick a different task
   from another mode** or open the PR as `Draft` with a note in the body.
- Max-turns is 200 — use them to verify the change actually improves
  things. Read every file that calls the refactored code. Prove the
  refactor works end-to-end.

## Example good PRs in this mode

- `refactor(tower): extract target selection into `_pick_target()` helper`
- `perf(projectile): pool projectiles, reuse instead of free/instance`
- `chore: remove commented-out debug prints in wave_manager.gd`
- `chore: add missing return type annotations across systems/`
