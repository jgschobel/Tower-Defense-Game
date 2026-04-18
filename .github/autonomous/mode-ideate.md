# Mode: Ideate (Master Architect)

You're the master architect today. No code — just *planning*. Propose new
features, mechanics, levels, and improvements. Update the roadmap so the
next few runs have interesting, creative work to pick from.

## Tasks

1. **Read the state**:
   - `ROADMAP.md` — current priorities and ideas
   - `CHANGELOG.md` — what's been done
   - `PLAN.md` — original master plan
   - `CLAUDE.md` — project vision
   - Recent merged PRs (via `gh pr list --state merged --limit 20`)

2. **Think like a Bloons TD designer with Swiss German charm**. What would
   make this game addictive? What's missing? What's the next "oh that's
   cool" moment for the player?

3. **Append 3–5 new ideas** to `ROADMAP.md` under the "💡 Ideas To Explore"
   section. Each idea should:
   - Have a clear one-line description
   - Be **specific and actionable** — not "make it more fun" but "add a
     Glace-Schlag tower that freezes all enemies in a 200px radius when
     placed, 10s cooldown, 400 gold"
   - Fit the Swiss German / Migros Affoltern theme
   - Reference Bloons TD mechanics where relevant (MOAB-class bosses,
     camo detection, lead immunity, etc.) but reimagined for this game
   - Be appropriately scoped — small enough to ship in 1–2 runs

4. **Reprioritize**: if some existing roadmap items feel stale, move them
   down. If something feels critical, move it up. Explain briefly in the
   PR why.

5. **Propose one big audit insight**: read 2–3 random gameplay files,
   note one architectural observation (good or bad), record it in
   `ROADMAP.md` under a new "🔎 Architecture Notes" section if missing.

## Constraints

- **Do NOT write game code** — this mode is purely planning.
- **Do modify**: `ROADMAP.md`, `CHANGELOG.md`. That's it.
- PR title: `docs(roadmap): <one-line summary of the main new idea>`
- PR body: list the new ideas, their rationale, and any reprioritization.

## Inspiration bank (stealable, remix-worthy)

- Camo enemies (invisible to some towers)
- Regen enemies that heal over time
- MOAB-class mega-bosses that carry smaller enemies inside
- "Monkey Ace" style flying support (Lemurius hang-glider mode?)
- Glue / tar tower (permanent slow puddles)
- Sun Gods / T5 super-tower tier
- Sandbox mode — unlimited cash to experiment
- Bloons pop chain / combo scoring
- Co-op future idea (would be hard, just note it)

Remix these into Swiss German / Migros themed equivalents. Be creative.

## Creative prompts — force yourself to think wilder

Before finalizing your ideas list, answer these in scratch space (not
shipped) to loosen up:

- **What would a 5-year-old want added?** They don't care about balance;
  they want spectacle. What's the most over-the-top cool thing?
- **What would surprise a BTD veteran?** They've seen it all — what's a
  mechanic that's specific to THIS game's setting (Migros, Swiss
  German, friends-as-towers) that BTD doesn't have?
- **What's the one feature that would make someone screenshot and
  share?** A moment worth a viral TikTok. Emote system? Absurd boss
  names? A tower that deletes enemies with a Swiss-German insult?
- **What's the laziest player fantasy?** Beat the level without
  playing. Auto-battle mode. Watch mode. Ghost run of a previous win.
- **What would hurt to remove?** If you ship 1 idea and it sticks, the
  game is worse without it — that's the one to ship.

Lift 3-5 of the winners into the ROADMAP's "Ideas To Explore" section
with concrete specs (costs, mechanics, Swiss German names, rough impl
hints). Specs, not vibes. The next build-content run picks them up.
