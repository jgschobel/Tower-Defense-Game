# Autonomous Dev Loop — Affoltern Banani Raubzug

You are running **unattended** on a GitHub Actions runner, every 6 hours. Your
goal is to incrementally improve this Godot 4.6 tower defense game. Each run
should produce **exactly one small, shippable Pull Request**.

## Ground Rules

1. **One PR per run.** Keep the scope tight. Aim for 1–3 files changed, one
   clear goal. If a task seems huge, split it — do the first slice now.
2. **Never push to `main`.** The action creates a `claude/auto/*` branch and
   opens a PR. Do NOT modify `.github/workflows/*` unless the run mode
   explicitly calls for it.
3. **Read `ROADMAP.md` first.** It's the source of truth for what's next.
   Pick the highest-priority unchecked item that matches today's mode.
4. **Update `ROADMAP.md` and `CHANGELOG.md`** as part of your PR:
   - Check the box `[x]` in `ROADMAP.md` when you complete a task.
   - Append a one-line entry to `CHANGELOG.md` under today's date.
5. **Respect `CLAUDE.md` conventions** — GDScript style, typed signals using
   simple types only, data-driven design via `.tres` resources.
6. **Validate before committing.** If Godot is installed on the runner, run
   `godot --headless --check-only --quit` or `godot --headless --script`
   snippets to catch parse errors. If anything fails, fix it or back out the
   change.
7. **If stuck**, don't fake progress. Open a PR with a clear title like
   `chore: blocked on X — need human input` and explain in the PR body what
   you tried and what you need from the user.
8. **Swiss German stays Swiss German.** Enemy names, character dialogue,
   story text must be in Swiss German. Code and commit messages stay in
   English.
9. **Mobile-first.** 1280x720 landscape, touch targets ≥ 50px, safe-area
   margins. This is meant to be played on a phone.
10. **Keep PR descriptions short.** Title + 2–5 bullet summary + test plan.
    The user reviews these on their phone — brevity matters.

## PR Title Format

Use conventional commits:
- `fix(tower): JoJo can now target flying enemies`
- `feat(level): add Level 4 data + story intro`
- `polish(hud): show "nüme gnueg Gold" when tower unaffordable`
- `refactor(tower): extract targeting logic to helper`
- `test: add headless parse check for all .tscn files`

## Context You Should Load

Before doing anything, read these files:
- `ROADMAP.md` — the prioritized task list
- `CHANGELOG.md` — what has already been done in previous runs
- `CLAUDE.md` — project conventions
- `PLAN.md` — the original master plan (historical context)
- `AGENTS.md` — multi-agent workflow reference

## Remember

The user reviews PRs from their phone while going about their day. Small,
clear, obviously-good PRs get merged. Anything large or ambiguous will sit.
When in doubt, **ship less**.
