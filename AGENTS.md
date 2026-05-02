# Agent Architecture — Affoltern Banani Raubzug

> **READ THIS AT THE START OF EVERY NEW CONVERSATION.**
> This file + CLAUDE.md define how to work on this project.
> Always use sub-agents for parallel work. Never ask the user questions you can answer yourself.
> API keys are GitHub repository secrets, not local files.

## Philosophy
Conductor delegates to specialized sub-agents only when tasks can genuinely run in parallel or when isolation protects the main context from noise. We don't create agents for the sake of having agents — we use them when they're faster than doing it ourselves. Model selection follows the discipline in CLAUDE.md (Haiku for search, Sonnet for code, Opus only for novel architecture).

## Roles

### 1. CONDUCTOR (Sonnet 4.6 default — Opus 4.7 only for novel architecture)
**Responsibilities:**
- Architecture decisions, code design, creative direction
- Reading and understanding the full codebase
- Writing complex game logic (upgrade paths, new tower systems)
- Swiss German lore and dialogue writing
- Reviewing all sub-agent output before integrating
- Managing git commits and pushes
- Talking to the user

**Model rule:** Default Sonnet. Escalate to Opus only when the task introduces a new system or affects 5+ files architecturally — at most once per week per CLAUDE.md user directives. Never spawn Opus for what Sonnet handles.

**When NOT to delegate:** Sequential bug fixes, quick edits, anything that needs full project context.

---

### 2. ART FACTORY (background agent)
**Model:** sonnet (fast, good enough for API calls)
**Trigger:** When 2+ images need generating, or background removal batch jobs
**Responsibilities:**
- Calling Stability AI API to generate images
- Running rembg for background removal
- Resizing and cropping images
- Saving processed art to correct project folders
- NOT wiring art into game code (Conductor does that)

**Example prompt:**
> "Generate 3 enemy sprites using Stability AI. API key at C:/Users/josef/.api_keys/keys.json. Save to assets/textures/enemies/. Prompts: [list]. Then remove backgrounds with rembg isnet-general-use model."

**Why this works as agent:** Image generation takes 10-30 seconds per image. While Art Factory waits for API responses, Conductor can write code.

---

### 3. CODE SCOUT (exploration agent)
**Model:** Haiku 4.5 (5× cheaper than Sonnet, fully capable for search)
**Trigger:** When Conductor needs to understand a part of the codebase before making changes, or when searching for all occurrences of a pattern
**Responsibilities:**
- Reading multiple files to answer specific questions
- Finding all usages of a function/signal/variable
- Checking if node paths in .tscn match @onready in .gd
- Verifying signal connections across scene files
- Reporting findings back to Conductor

**Example prompt:**
> "Find every place in the codebase where 'body_entered' or 'body_exited' is used — in both .gd scripts and .tscn scene files. Report file paths and line numbers."

**Why this works as agent:** Exploration can involve reading 20+ files. Doing it in a sub-agent keeps the main context clean.

---

### 4. BUILD TESTER (validation agent — usually run as workflow, not subagent)
**Trigger:** Pre-push via `.github/autonomous/validate.sh`. Also runs as a step in `autonomous-dev.yml` before auto-merge.

**What it actually checks (validate.sh):**
1. All `ext_resource path="res://..."` references in `.tscn` / `.tres` resolve to existing files
2. All `preload("res://...")` paths in `.gd` files resolve
3. All autoload scripts referenced in `project.godot` exist
4. Signal-connection heuristic — every `.connect("name", ...)` target has a matching `func name(` somewhere in `scripts/`
5. **Per-script `godot --check-only`** on every `.gd` file (catches type errors, parse errors, undeclared identifiers)
6. Headless launch test (`godot --headless --quit-after 1`)
7. **Scene-load smoke test** — every `level_*.tscn` + main menu scene loads without `SCRIPT ERROR` / `PARSE ERROR` / `Failed to load`
8. Main scene exists, Godot version pin matches

**Returns non-zero on any hard failure.** Autonomous-dev closes the PR + files an issue when validation fails.

---

## Autonomous Loop Architecture (CI-side)

The Conductor doesn't run continuously — instead 21 GitHub Actions workflows form a self-managing loop. See `README.md` for the full list and `docs/observability/loop-status.md` for live health.

**Critical chain:**
```
push:main → deploy-web → GitHub Pages
         → playtest    → audit-grid (4×4 stitch)
                      → vision agent → playtest-feedback issues

cron 4h  → autonomous-dev → preflight (PAUSE check + rate limit + mode rotation)
                          → Claude Code action (mode-specific prompt)
                          → validate.sh
                          → auto-merge OR close+file issue
```

**Self-observation chain:**
```
Any workflow fails → ci-monitor → file ci-failure issue
                                → mirror log tail to docs/observability/failures/<wf>__<run>.log
                                → append row to failures/INDEX.md

cron 6h → loop-health → write docs/observability/loop-status.md (per-workflow last-run dashboard)
                     → file loop-broken issue if no autonomous-dev runs in 8h or no deploy success in 24h
```

**Bug-class prevention:**
- `workflow-lint.yml` runs `actionlint` + `bash -n` per `run: |` block on every PR touching `.github/workflows/`. Catches the "prose comment without `#`" class that previously broke deploy-web for 9 days.
- `pause-watchdog.yml` fails CI on PRs with `# PAUSED` comments older than 7 days — forces explicit re-pause or unpause.

The chat-session Claude can read all observability files via the GitHub MCP (`get_file_contents`), but **cannot directly access the Actions logs API**. That's why log mirroring exists.

---

## When to Use Agents (Decision Tree)

```
Is the task independent from what I'm currently doing?
├── YES: Can it run in background while I work?
│   ├── YES → Spawn agent (Art Factory or background investigation)
│   └── NO → Do it myself
└── NO: Does it need full project context?
    ├── YES → Do it myself (Conductor)
    └── NO: Is it pure exploration/search?
        ├── YES → Code Scout agent (Haiku)
        └── NO → Do it myself
```

## Anti-Patterns (What NOT to do)
- Don't spawn an agent for a 5-line code fix
- Don't spawn multiple agents that modify the same files
- Don't create "Project Manager" agents — that's the Conductor's job
- Don't use agents for creative decisions (lore, game design) — keep them with Conductor
- Don't chain agents (agent A → agent B) — just do it sequentially
- Don't spawn Opus for tasks Sonnet handles. Don't spawn Sonnet for tasks Haiku handles. Per CLAUDE.md model discipline.
- Don't ask the user to manually trigger workflow runs — fix the workflow trigger config instead.
