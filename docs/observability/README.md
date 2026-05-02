# Observability — how workflows report back

The chat-session Claude has **no direct access to GitHub Actions logs
or run status**. MCP tools cover Issues / PRs / Commits / Files but
NOT workflow runs. This directory is the workaround.

Every non-trivial workflow commits a small artifact here at the end
of each run. The chat Claude `Read`s these files to see what happened
instead of guessing.

## Files kept up-to-date by workflows

### Live dashboard (read this first)

| File | Written by | What it contains |
|------|------------|------------------|
| `loop-status.md` | `loop-health.yml` (every 6h) | Per-workflow last-run + conclusion + last-success table, open issue counters, PAUSE state, recent failure index. **One file = full health view.** |

### Per-system last-run summaries

| File | Written by | What it contains |
|------|------------|------------------|
| `deploy_latest.md` | `deploy-web.yml` | Last deploy commit, URL, status |
| `playtest_latest.md` | `playtest.yml` | Last playtest run's `summary.md` + links to 7 key screenshots |
| `sim_latest.md` | `sim-gate.yml` | Last wave-balance simulator CSV + pass/fail |
| `photo_latest.md` | `photo-to-character.yml` | Last photo-gen run's diagnostic + outcome |

### Failure investigation

| File | Written by | What it contains |
|------|------------|------------------|
| `failures/INDEX.md` | `ci-monitor.yml` | Table of recent workflow failures: timestamp, workflow, run number, branch, commit, log file. Last 50 entries. |
| `failures/<slug>__<run_id>.log` | `ci-monitor.yml` | Last ~250 lines of step logs from a failed run. Top 50 most recent are kept; older ones pruned automatically. |

When a workflow fails, the chat-session Claude reads `failures/INDEX.md` to find the run, then reads the matching log file directly via `mcp__github__get_file_contents`. No screenshots, no manual log fetching.

### Append-only ledger

| File | Written by | What it contains |
|------|------------|------------------|
| `ledger.md` | All workflows (one line each) | Single append-only log: timestamp, workflow, result, key metrics. Truncated to last 150 lines daily. |

### Browser-checkable build freshness

`build-info.json` lives in the deployed Pages payload (NOT in this directory). Hit `https://jgschobel.github.io/Tower-Defense-Game/build-info.json` from any browser to see: current commit SHA, build timestamp, content counts, run URL. Useful from the user's phone to confirm a deploy actually shipped.

## Rotation

- `cleanup.yml` daily cron truncates `ledger.md` to last 150 lines.
- `failures/` directory is capped at 50 most recent log files (oldest pruned in-place by `ci-monitor.yml`).
- `failures/INDEX.md` is capped at 50 rows + header.
- Per-run detail files (`*_latest.md`) are overwritten each run, so they're always the latest.

## Why the commits don't loop

- All observability commits go to `chore(observability):` scoped commits on `main` directly (bypasses PR / validation).
- `deploy-web`, `playtest`, `sim-gate` are all `paths`-scoped and **EXCLUDE `docs/observability/**`** from their trigger paths, so writing here does NOT cascade into new workflow runs.
- `loop-health.yml` and `ci-monitor.yml` use 5-attempt rebase-and-retry push loops to handle concurrent observability commits from other workflows racing on the same branch.
