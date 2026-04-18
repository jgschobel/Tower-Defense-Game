# Mode: Generate Art (Imagen 4 / Stability)

Generate new art. **Two tools at your disposal**:

- **Imagen 4** (text-to-image, preferred for non-friend art) — Google's
  latest, excellent for backgrounds, new enemy concepts, UI frames,
  props. Free tier via `GEMINI_API_KEY`. Endpoint + helper at
  `.github/scripts/generators.py::generate_background(prompt, out_path,
  aspect_ratio)`. Use `16:9` for level backgrounds, `1:1` for enemies
  and UI, etc.
- **Stability SD3.5** (fallback) — used automatically if Imagen 4 fails.

**Hard rule still applies**: never use text-to-image for friend
character icons (Lemurius, Amösius, Kühne, JoJo, Cordula). Those go
through the img2img pipeline with an actual photo as input.

## Prerequisites

Check that `$STABILITY_API_KEY` is non-empty. If it's missing, bail out
and open a tiny polish PR instead — don't block the loop.

## Tasks (pick ONE per run)

1. **Missing assets**: scan `ROADMAP.md` and `CHANGELOG.md` for notes
   about missing art (e.g., "Level 4 needs background", "boss needs
   portrait"). Pick the most-needed one.

2. **Upgrade-level variants**: some towers have upgrades but no per-level
   visual changes (PLAN.md #22). Generate a slightly-tinted / glowing
   variant for tier 2 or 3 of one tower.

3. **Enemy art variants**: elite or shiny versions of existing enemies.

4. **UI polish**: button backgrounds, HUD frame decorations, level
   select badges, achievement icons.

## How to call Stability (example)

```bash
curl -X POST "https://api.stability.ai/v2beta/stable-image/generate/core" \
  -H "Authorization: Bearer $STABILITY_API_KEY" \
  -H "Accept: image/png" \
  -F prompt="cartoon tower defense character, chibi lemur holding a banana, Swiss alpine village background, bright colors, transparent background, game asset" \
  -F output_format="png" \
  -F aspect_ratio="1:1" \
  -o assets/textures/towers/lemurius_tier2.png
```

## Constraints

- **Generate at most 2 images per run** — Stability credits are finite.
- **Always save to `assets/textures/<category>/`** — towers, enemies,
  ui, maps, projectiles.
- **Import in Godot**: after saving PNG, create or update the `.import`
  file if needed — or note in the PR body that the user may need to
  re-import on next Godot open.
- **Reference the new asset** — wire it into a `.tres` or `.tscn` so
  it's actually used. An unused image doesn't count.
- **Prompt carefully** — include: "transparent background", "game
  asset", "chibi cartoon style", "no text", and the character's
  existing visual identity. Study existing PNGs in the folder first.
- If generation fails (API error, rate limit), open a tiny polish PR
  instead — don't block the loop.

## PR format

Title: `art(tower): add tier-2 Lemurius variant`

Body:
- What was generated and why
- Where it's wired in (.tres / .tscn)
- A reminder to re-import textures in the Godot editor if needed
- Stability API credits used (if known)
