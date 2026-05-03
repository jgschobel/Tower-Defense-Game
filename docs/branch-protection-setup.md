# Branch Protection Setup (one-time, ~3 min from phone)

Branch protection requires repo admin permissions and cannot be enabled
via the autonomous loop or any MCP tool. **You** need to flip these
switches in the GitHub web UI once. After that, `gh pr merge --auto`
will actually wait for green CI before merging — currently it
fast-merges immediately because no checks are required.

## Steps from phone

1. Open `https://github.com/jgschobel/Tower-Defense-Game/settings/branches`
   in GitHub mobile (or any browser)

2. Click **Add branch ruleset** (or "Add rule" on older UI)

3. Settings to enable:
   - **Branch name pattern**: `main`
   - ✅ **Require status checks to pass before merging**
     - Required checks (search and add):
       - `validate` (from validate.sh — pre-flight)
       - `bash-syntax` (from workflow-lint.yml)
       - `actionlint` (from workflow-lint.yml)
   - ✅ **Require branches to be up to date before merging**
   - ❌ **Require pull request reviews** (LEAVE OFF — autonomous loop
     can't self-review and you don't want to manually approve every PR)
   - ✅ **Allow auto-merge** (this is the magic toggle —
     `gh pr merge --auto --squash` becomes meaningful)
   - ✅ **Automatically delete head branches** (kills 30% of branch
     sprawl with one click — replaces our daily cleanup pattern matching
     for cleanly-merged PRs)

4. Save

## Why each matters

- **Required checks**: Prevents `gh pr merge --auto` from merging broken
  code. Currently the auto-merge is essentially a normal merge because
  no checks block it.

- **Allow auto-merge**: Without this, `gh pr merge --auto --squash` in
  art-request.yml etc. silently fails and PRs sit open. This is why the
  art PR backlog grew despite "auto-merge" being in the workflow.

- **Auto-delete head branches**: One toggle that solves 30% of the
  branch-sprawl problem without any cleanup workflow. Combine with our
  cleanup.yml (which handles squash-merge cases) for full coverage.

## After enabling

The autonomous loop, art-request, enemy-damage-art, mass-art, and
photo-to-character workflows all already call `gh pr merge --auto --squash`.
After branch protection is on, these calls will:
1. Queue the PR for auto-merge
2. CI runs (validate + workflow-lint)
3. On green, GitHub auto-merges + deletes branch
4. No human action needed, no PR sits open

This is the missing piece that turns the whole pipeline into a
self-sustaining system.

## Verification

After enabling, the next art-request issue should result in a closed,
merged PR within ~3 min (validate.sh runs in 30s, workflow-lint in 60s,
then auto-merge fires). If a PR sits open >5 min, branch protection
isn't configured correctly — check the PR's "auto-merge" toggle on its
page.
