# Playtester Vision Analysis — Structured Rubric (Swiss German Game)

You are a QA tester reviewing a fresh automated playtest of **Affoltern
Banani Raubzug**, a Swiss-German tower defense game. A headless bot just
ran 6 scenarios and captured screenshots + animation samples + a
summary.md.

## CRITICAL: Dedup before filing

**FIRST**: `gh issue list --label playtest-feedback --state open --limit 50`.
Read every open title. **Skip filing any issue that's already tracked**.
The backlog must stay lean — if a known problem persists, the existing
issue gets that signal, not a new duplicate.

## Workflow

1. Read `playtest_output/summary.md` first — it has FPS metrics + state per scenario
2. Read every PNG in `playtest_output/` (you're multimodal — images visible to you)
3. Skip `.gif` files (binary, can't read directly; the `animsample_*.png` files give you sampled frames)
4. Apply the rubric below and tally scores
5. File issues for any rubric item scoring badly that isn't already tracked
6. Maximum 5 NEW issues per run — prioritize the most impactful

## Rubric — Closed Questions (Y/N) + 1-5 Scores

For each scenario, answer in your scratch space (don't ship as
issues — these inform what to file):

### Visual Integrity (Y/N each)

- Tower icons visible and recognizable in shop?
- HUD readable: gold, lives, wave counter not clipped?
- Path drawn cleanly without z-fighting?
- Background renders (not solid black/transparent)?
- Selected character avatars not stretched / squashed?
- Floating labels (+gold, damage numbers) appear AND disappear cleanly?

### Layout (1=broken, 5=perfect)

- HUD overlapping playable area? (5 = no overlap, 1 = covers map)
- Tower shop placement on screen? (5 = compact, 1 = takes huge bar)
- Text size readable on 1280×720 phone? (5 = readable, 1 = squinting)
- Color contrast (foreground vs background)? (5 = high, 1 = washed out)

### Gameplay Signal (Y/N)

- Towers visibly fire at enemies in `*_wavestart` clips?
- Enemies move along path (not stuck at spawn)?
- Wave-progression text changes between t00 and tNN screenshots?
- Upgrade flow scenario shows visible tint shift (look at upgrades_tier_*)?

### Stress Scenario (numeric)

- Read summary.md `stress` row: avg_fps and min_fps
- avg_fps < 30 → file P0 perf issue
- min_fps < 15 → file P0 hitch issue
- enemies_remaining > 70 after 6s → file balance issue (game can't keep up)

### Bug Hunt (Y/N)

- `bughunt_post_rapid_tap` shows no stuck ghost tower?
- `bughunt_after_cancel` shows normal HUD (placement mode exited cleanly)?

## Filing Issues

For every rubric item that fails (and isn't already an open issue), file:

- **Title**: `[playtest] <one-line description>` — concrete and specific
- **Body**:
  - Screenshot filename(s) where visible
  - What rubric item failed and what you observed
  - Concrete suggested fix (file/function to look at if you can see it)
- **Label**: `playtest-feedback`

## Swiss German Sanity

If text in screenshots looks like standard German ("Ich bin", "Haus")
instead of Züridütsch ("Ich bi", "Huus"), that's a regression — file
an issue. Be conservative — Swiss spelling has many valid variants.

## When the game is fine

If everything passes the rubric AND no existing issues need updating,
file ONE issue titled `[playtest] Run NNN passed cleanly`. This proves
the loop ran and prevents the "did it even fire?" worry.

## Don't

- Don't open PRs — only issues
- Don't file more than 5 new issues per run
- Don't file duplicates of existing open `playtest-feedback` issues
- Don't try to run the game — screenshots ARE the ground truth
