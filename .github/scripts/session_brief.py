#!/usr/bin/env python3
"""
Generate docs/observability/session_brief.md — the single document chat-session
Claude reads at the start of every session. Replaces 5 separate file reads with
one cheap fetch.

Includes:
- Open PR count (with stale > 48h call-out)
- ROADMAP P0 head item (the next-up task)
- Open ci-failure / loop-broken issue counts
- Last successful deploy timestamp
- Asset gap summary (from asset_status.md if present)
- Last autonomous-dev run status

Run via .github/workflows/session-opener.yml on a daily cron + after every push
to main that touches workflows or ROADMAP.
"""
from __future__ import annotations

import datetime
import json
import os
import pathlib
import re
import subprocess

REPO = pathlib.Path(__file__).resolve().parents[2]
OUT_PATH = REPO / "docs/observability/session_brief.md"


def _gh_json(args: list[str], default):
    """Run gh CLI and return parsed JSON; default on failure."""
    try:
        r = subprocess.run(
            ["gh"] + args, capture_output=True, text=True, timeout=30, check=True,
        )
        return json.loads(r.stdout) if r.stdout.strip() else default
    except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired,
            json.JSONDecodeError):
        return default


def _utc_now() -> datetime.datetime:
    return datetime.datetime.now(datetime.timezone.utc).replace(tzinfo=None)


def _parse_iso(s: str) -> datetime.datetime | None:
    if not s:
        return None
    try:
        return datetime.datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ")
    except ValueError:
        return None


def get_pr_summary() -> dict:
    prs = _gh_json(["pr", "list", "--state", "open", "--limit", "100",
                    "--json", "number,title,createdAt,mergeable,author,headRefName"],
                   default=[])
    cutoff_48h = _utc_now() - datetime.timedelta(hours=48)
    stale = []
    fresh = []
    for pr in prs:
        created = _parse_iso(pr.get("createdAt", ""))
        if created and created < cutoff_48h:
            age_h = int((_utc_now() - created).total_seconds() / 3600)
            stale.append({
                "n": pr["number"],
                "title": pr["title"][:70],
                "age_hours": age_h,
                "mergeable": pr.get("mergeable", "UNKNOWN"),
            })
        else:
            fresh.append({"n": pr["number"], "title": pr["title"][:70]})
    return {"total": len(prs), "stale": stale, "fresh": fresh}


def get_issue_counts() -> dict:
    counts = {}
    for label in ("ci-failure", "loop-broken", "stale-pr-tracker",
                  "playtest-feedback", "art-request", "blocked"):
        issues = _gh_json(["issue", "list", "--state", "open", "--label", label,
                           "--limit", "100", "--json", "number"], default=[])
        counts[label] = len(issues)
    return counts


def get_roadmap_p0_head() -> str:
    path = REPO / "ROADMAP.md"
    if not path.exists():
        return "(ROADMAP.md missing)"
    text = path.read_text()
    in_p0 = False
    for line in text.splitlines():
        if line.startswith("## "):
            in_p0 = "P0" in line
            continue
        if in_p0 and re.match(r"^\s*-\s*\[ \]", line):
            # First unchecked item in P0
            cleaned = re.sub(r"^\s*-\s*\[ \]\s*", "", line).strip()
            return cleaned[:200]
    return "(no unchecked P0 items)"


def get_asset_gap() -> str:
    path = REPO / "docs/observability/asset_status.md"
    if not path.exists():
        return "(asset_status.md not yet generated — first asset-manifest run pending)"
    text = path.read_text()
    # Extract the Summary section
    m = re.search(r"## Summary\n\n(.+?)(?=\n##|\Z)", text, re.S)
    if m:
        return m.group(1).strip()
    return "(asset_status.md present but no Summary section found)"


def get_loop_status() -> str:
    path = REPO / "docs/observability/loop-status.md"
    if not path.exists():
        return "(loop-status.md missing)"
    text = path.read_text()
    # First non-blank line after "**Overall:**"
    m = re.search(r"\*\*Overall:\*\*\s*(.+?)$", text, re.M)
    if m:
        return m.group(1).strip()
    return "(loop-status.md present but no Overall line)"


def main() -> int:
    pr = get_pr_summary()
    issues = get_issue_counts()
    p0 = get_roadmap_p0_head()
    assets = get_asset_gap()
    loop = get_loop_status()

    lines: list[str] = []
    lines.append("# Session Brief\n\n")
    lines.append(f"_Generated: {_utc_now().isoformat(timespec='seconds')}Z_  \n")
    lines.append("_Auto-updated by `.github/workflows/session-opener.yml` daily + on push._  \n")
    lines.append("_**Read this first. Single source of truth for 'what's the state right now?'**_\n\n")

    # State of the union — three lines
    lines.append("## Where we stand\n\n")
    lines.append(f"- **Loop status**: {loop}\n")
    lines.append(f"- **Open PRs**: {pr['total']} total, **{len(pr['stale'])} stale** (>48h)\n")
    lines.append(f"- **Open ci-failures**: {issues.get('ci-failure', 0)}\n")
    lines.append(f"- **Open loop-broken**: {issues.get('loop-broken', 0)}\n")
    lines.append(f"- **Open playtest-feedback**: {issues.get('playtest-feedback', 0)}\n")
    lines.append(f"- **Stale-PR-tracker issues**: {issues.get('stale-pr-tracker', 0)}\n")
    lines.append(f"- **Open art-request issues**: {issues.get('art-request', 0)}\n")
    lines.append(f"- **Open blocked issues**: {issues.get('blocked', 0)}\n\n")

    # Next-up
    lines.append("## Next ROADMAP P0 (top of the unchecked list)\n\n")
    lines.append(f"> {p0}\n\n")

    # Asset gap
    lines.append("## Asset gap\n\n")
    lines.append(assets + "\n\n")

    # Stale PRs (if any)
    if pr['stale']:
        lines.append("## ⚠️ Stale PRs (>48h, action needed)\n\n")
        lines.append("| PR | Age (h) | Mergeable | Title |\n|---|---|---|---|\n")
        pr['stale'].sort(key=lambda p: -p['age_hours'])
        for s in pr['stale']:
            icon = {"MERGEABLE": "✅", "CONFLICTING": "🔴", "UNKNOWN": "❓"}.get(s["mergeable"], "❓")
            lines.append(f"| #{s['n']} | {s['age_hours']} | {icon} | {s['title']} |\n")
        lines.append("\n")

    # Decision rules
    lines.append("## Suggested action\n\n")
    if len(pr['stale']) > 5:
        lines.append("🚨 **Merge-backlog mode**: 5+ PRs are stale. Don't add new work; clear the queue.\n")
    elif issues.get('ci-failure', 0) > 0:
        lines.append("⚠️ **Fix CI first**: ci-failure issues are open. Read those and clear them before new work.\n")
    elif issues.get('playtest-feedback', 0) > 5:
        lines.append("⚠️ **Playtest backlog**: many playtest-feedback issues. Prioritize bug fixes over new content.\n")
    else:
        lines.append("✅ Clear queue. Pick the ROADMAP P0 head item above.\n")

    OUT_PATH.parent.mkdir(parents=True, exist_ok=True)
    OUT_PATH.write_text("".join(lines))
    print(f"Wrote {OUT_PATH}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
