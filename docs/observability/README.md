# Observability — how workflows report back

The chat-session Claude has **no direct access to GitHub Actions logs
or run status**. MCP tools cover Issues / PRs / Commits / Files but
NOT workflow runs. This directory is the workaround.

Every non-trivial workflow commits a small artifact here at the end
of each run. The chat Claude `Read`s these files to see what happened
instead of guessing.

## Files kept up-to-date by workflows

| File | Written by | What it contains |
|------|------------|------------------|
| `ledger.md` | All workflows (one line each) | Single append-only log: timestamp, workflow, result, key metrics |
| `playtest_latest.md` | `playtest.yml` | Last playtest run's full summary.md + links to key screenshots |
| `sim_latest.md` | `sim-gate.yml` | Last sim-gate CSV + pass/fail |
| `deploy_latest.md` | `deploy-web.yml` | Last deploy commit, URL, status |
| `photo_latest.md` | `photo-to-character.yml` | Last photo-gen run's diagnostic + outcome |

## Rotation

The `cleanup.yml` daily cron truncates `ledger.md` to last 150 lines
to stop it growing unbounded. Per-run detail files are overwritten
each run (not appended), so they're always just the latest.

## Why the commits don't loop

- All observability commits go to a `chore(observability):` scoped
  commit on `main` directly (bypasses PR/validation)
- `deploy-web`, `playtest`, `sim-gate` are all `paths`-scoped and
  EXCLUDE `docs/observability/**` from their trigger paths, so
  writing here does NOT trigger a new workflow cascade
