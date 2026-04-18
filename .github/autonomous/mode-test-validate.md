# Mode: Test & Validate

Focus on **catching breakage before the user does**. This mode produces
either a "everything's fine" no-op report OR a fix PR for something
discovered.

## Step 0 — Triage CI failures (per base-prompt Priority Order #1)

`gh issue list --label ci-failure --state open --limit 5`. Each issue
is an automated CI log tail. Diagnose root cause from the log, ship a
fix PR, close with `Closes #N`. Only move on if no ci-failure issues
are open.

## Steps

1. **Run a headless Godot parse check** if available on the runner:
   ```
   godot --headless --check-only --quit --path .
   ```
   If it fails, read the error, identify the broken file, fix it.

2. **Scan all `.tscn` files** for broken `ext_resource` paths. If a
   referenced script or texture doesn't exist on disk, either restore it
   or remove the reference.

3. **Scan all `.tres` files** for broken references to deleted scripts
   or assets.

4. **Validate signal connections** — `grep` for `connect(` and verify the
   target method exists.

5. **Check autoload integrity** — every autoload in `project.godot` must
   point to an existing script.

6. **Look for obviously dead scenes** — scenes that aren't referenced
   anywhere (except other dead scenes).

## Output

If you find NO issues, open a tiny PR that appends a line to
`CHANGELOG.md` like:
```
- 2026-04-17: Validation run — no issues found. Game parses clean.
```
This proves the cron ran. Do not open an empty PR.

If you find issues, open ONE PR with the most critical fix. File a
GitHub issue (if you have permission) listing any other issues for
future runs to pick up.

## Constraints

- **Do NOT add test frameworks or introduce new tooling.**
- **Do NOT rewrite working code** just because it looks weird.
- Validation only — no feature work in this mode.
