# Archived Workflows

Per the 2026-06-20 audit, the repo had **31 GitHub workflows** vs comparable
indie Godot TD projects (youtd2: 1; Brotato/Cassette Beasts: 2-3).
~60% of ours were scaffolding around the autonomous-dev loop rather
than work that shipped the game itself.

This folder holds 11 workflows that were moved out of `.github/workflows/`
to keep CI legible. They're preserved here (not deleted) so they can be
revived with a single `mv` if they ever become useful again.

| File | Why archived |
|---|---|
| `loop-health.yml` | Pushed to `docs/observability/loop-status.md` every 6h; pushes have been rejected by the branch ruleset since 2026-05-03. Workflow runs but its output never lands. |
| `loop-killswitch.yml` | Auto-pauses the autonomous loop after 3 consecutive failures. Useful in theory but adds noise; can be re-introduced if runaway loops become a problem. |
| `pause-watchdog.yml` | Checks the kill-switch flag. Coupled to `loop-killswitch.yml`. |
| `pr-staleness-watchdog.yml` | Files issues for PRs > 12h old. The autonomous loop merges fast enough that staleness is rarely the issue. |
| `weekly-audit.yml` | Friday-morning self-audit summary. Useful concept; if revived, simpler to run on demand. |
| `weekly-digest.yml` | Broken since 2026-04-20 per `loop-status.md` — never had a single successful run. |
| `drift-scan.yml` | Broken since 2026-04-20 — same status. Concept: detect ROADMAP/code drift. |
| `session-opener.yml` | Writes `docs/observability/session_brief.md` daily. The chat-session reads `loop-status.md` directly now. |
| `deploy-itch.yml` | Pushes a build to itch.io. Never used — game ships via `deploy-web.yml` only. |
| `deploy-pr-preview.yml` | Per-PR preview deployment. Disabled in May 2026 (197MB `index.pck` exceeded GitHub's 100MB git push limit). |
| `cleanup.yml` | Daily cleanup of merged branches and old artifacts. Replaced by `purge-artifacts.yml`. |

## How to revive one

```bash
mv .github/archived-workflows/<name>.yml .github/workflows/
git add . && git commit -m "ci: revive <name>"
```

The active set (`.github/workflows/*.yml` after this archive) is 20 files,
still heavy but justifiable: 10 essentials (dev loop, deploy, playtest,
validate, etc.) plus 10 art/photo/audio generation pipelines.
