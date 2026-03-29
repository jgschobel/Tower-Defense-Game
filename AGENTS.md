# Agent Architecture — Affoltern Banani Raubzug

## Philosophy
Opus (conductor) delegates to specialized sub-agents only when tasks can genuinely run in parallel or when isolation protects the main context from noise. We don't create agents for the sake of having agents — we use them when they're faster than doing it ourselves.

## Roles

### 1. CONDUCTOR (Opus — always active)
**Model:** claude-opus-4-6
**Responsibilities:**
- Architecture decisions, code design, creative direction
- Reading and understanding the full codebase
- Writing complex game logic (upgrade paths, new tower systems)
- Swiss German lore and dialogue writing
- Reviewing all sub-agent output before integrating
- Managing git commits and pushes
- Talking to JoJo (the user)

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
**Model:** sonnet (fast searches)
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

### 4. BUILD TESTER (validation agent)
**Model:** sonnet
**Trigger:** After major changes, before git push
**Responsibilities:**
- Running Godot headless to check for parse errors (if available)
- Grep-checking all @onready paths against scene node structures
- Verifying all resource paths (ExtResource) point to existing files
- Checking signal connections match method names
- Listing any .tres files that reference deleted textures
- Reporting pass/fail to Conductor

**Example prompt:**
> "Validate the project at c:/Users/josef/OneDrive/Dokumente/tower-defense-game/. Check: 1) All ExtResource paths in .tscn/.tres files point to existing files. 2) All signal connections in .tscn files have matching methods in their scripts. 3) No @onready paths reference non-existent nodes. Report issues."

**Why this works as agent:** Validation is purely mechanical — perfect for a fast model running in parallel.

---

## When to Use Agents (Decision Tree)

```
Is the task independent from what I'm currently doing?
├── YES: Can it run in background while I work?
│   ├── YES → Spawn agent (Art Factory or Build Tester)
│   └── NO → Do it myself
└── NO: Does it need full project context?
    ├── YES → Do it myself (Conductor)
    └── NO: Is it pure exploration/search?
        ├── YES → Code Scout agent
        └── NO → Do it myself
```

## Anti-Patterns (What NOT to do)
- Don't spawn an agent for a 5-line code fix
- Don't spawn multiple agents that modify the same files
- Don't create "Project Manager" agents — that's the Conductor's job
- Don't use agents for creative decisions (lore, game design) — Opus is better
- Don't chain agents (agent A → agent B) — just do it sequentially
