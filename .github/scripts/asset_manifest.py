#!/usr/bin/env python3
"""
Generate docs/observability/asset_status.md showing the gap between
EXPECTED art (referenced in resources or implied by data conventions)
and ACTUAL art (present in assets/textures/).

Single source of truth for chat-session Claude — read this BEFORE
claiming any art is missing.

Run via .github/workflows/asset-manifest.yml on a daily cron.
"""
from __future__ import annotations
import datetime
import json
import pathlib
import re
import subprocess
from typing import Set

REPO = pathlib.Path(__file__).resolve().parents[2]


def list_pngs(folder: pathlib.Path) -> Set[str]:
    if not folder.exists():
        return set()
    return {p.name for p in folder.iterdir()
            if p.suffix == ".png" and not p.name.endswith(".import")}


def parse_ids_from_tres(folder: pathlib.Path) -> list[dict]:
    out = []
    if not folder.exists():
        return out
    for p in sorted(folder.glob("*.tres")):
        text = p.read_text()
        id_match = re.search(r'^id\s*=\s*"([^"]+)"', text, re.M)
        if not id_match:
            continue
        name_match = re.search(r'^display_name\s*=\s*"([^"]+)"', text, re.M)
        tex_match = re.search(r'path="res://assets/textures/[^/]+/([^"]+\.png)"', text)
        out.append({
            "id": id_match.group(1),
            "name": name_match.group(1) if name_match else "?",
            "texture": tex_match.group(1) if tex_match else None,
        })
    return out


def get_open_pr_files() -> Set[str]:
    """Return paths touched by any open PR. Falls back to empty set
    if gh isn't available."""
    files: Set[str] = set()
    try:
        result = subprocess.run(
            ["gh", "pr", "list", "--state", "open", "--limit", "100",
             "--json", "number,files"],
            capture_output=True, text=True, timeout=30, check=True,
        )
        for pr in json.loads(result.stdout):
            for f in pr.get("files", []):
                files.add(f.get("path", ""))
    except (subprocess.CalledProcessError, FileNotFoundError, subprocess.TimeoutExpired):
        pass
    return files


def _has_state(variant_dir: pathlib.Path, state: str) -> bool:
    if not variant_dir.exists():
        return False
    for p in variant_dir.iterdir():
        if p.suffix == ".png" and "state" in p.name and state in p.name:
            return True
    return False


def main() -> int:
    enemy_data = parse_ids_from_tres(REPO / "resources/enemy_data")
    tower_data = parse_ids_from_tres(REPO / "resources/tower_data")
    enemy_pngs = list_pngs(REPO / "assets/textures/enemies")
    tower_pngs = list_pngs(REPO / "assets/textures/towers")
    map_pngs = list_pngs(REPO / "assets/textures/maps")
    enemy_variants_dir = REPO / "assets/textures/variants/enemies"
    pr_files = get_open_pr_files()

    out: list[str] = []
    out.append("# Asset Status Report\n\n")
    out.append(f"_Generated: {datetime.datetime.utcnow().isoformat(timespec='seconds')}Z_  \n")
    out.append("_Auto-updated daily by `.github/workflows/asset-manifest.yml`._  \n")
    out.append("_Source of truth for chat-session Claude — **read this BEFORE claiming any art is missing**._\n\n")
    out.append("**Legend**: ✅ in main · ❌ missing · 🟡 in open PR\n\n")

    # ENEMIES
    out.append("## Enemies (base + 3 damage states)\n\n")
    out.append("| ID | Name | Base | Hurt | Injured | Dying | Open PR |\n")
    out.append("|---|---|---|---|---|---|---|\n")
    enemy_complete = 0
    for e in enemy_data:
        eid = e["id"]
        base_candidates = [f"{eid}_clean.png"]
        if e["texture"]:
            base_candidates.append(e["texture"])
        base_in_main = any(c in enemy_pngs for c in base_candidates)
        base_status = "✅" if base_in_main else "❌"
        variant_dir = enemy_variants_dir / eid
        states = [_has_state(variant_dir, s) for s in ("hurt", "injured", "dying")]
        state_icons = ["✅" if s else "❌" for s in states]
        pr_match = any(eid in f for f in pr_files)
        pr_status = "🟡" if pr_match else ""
        if base_in_main and all(states):
            enemy_complete += 1
        out.append(f"| `{eid}` | {e['name']} | {base_status} | {state_icons[0]} | {state_icons[1]} | {state_icons[2]} | {pr_status} |\n")
    out.append(f"\n**Enemy completeness**: {enemy_complete}/{len(enemy_data)} fully arted (base + all 3 damage states)\n\n")

    # TOWERS
    out.append("## Towers (base + 6 tier variants)\n\n")
    out.append("| ID | Name | Base | t1a | t2a | t3a | t1b | t2b | t3b |\n")
    out.append("|---|---|---|---|---|---|---|---|---|\n")
    tower_complete = 0
    for t in tower_data:
        tid = t["id"]
        base_in = f"{tid}.png" in tower_pngs
        tier_results = []
        for tier in ("t1a", "t2a", "t3a", "t1b", "t2b", "t3b"):
            tier_results.append(f"{tid}_{tier}.png" in tower_pngs)
        if base_in and all(tier_results):
            tower_complete += 1
        cells = ["✅" if base_in else "❌"] + ["✅" if r else "❌" for r in tier_results]
        out.append(f"| `{tid}` | {t['name']} | " + " | ".join(cells) + " |\n")
    out.append(f"\n**Tower completeness**: {tower_complete}/{len(tower_data)} fully arted (base + all 6 tiers)\n\n")

    # LEVELS
    out.append("## Levels (backgrounds)\n\n")
    out.append("| Level | Background |\n|---|---|\n")
    level_present = 0
    for i in range(1, 11):
        present = any(p.startswith(f"level_{i}") for p in map_pngs)
        if present:
            level_present += 1
        out.append(f"| L{i} | {'✅' if present else '❌'} |\n")
    out.append(f"\n**Level completeness**: {level_present}/10 backgrounds present\n\n")

    # SUMMARY
    out.append("---\n")
    out.append("## Summary\n\n")
    out.append(f"- Enemies fully arted: **{enemy_complete}/{len(enemy_data)}**\n")
    out.append(f"- Towers fully arted: **{tower_complete}/{len(tower_data)}**\n")
    out.append(f"- Level backgrounds: **{level_present}/10**\n")
    out.append(f"- Open PRs touching art: **{sum(1 for f in pr_files if 'assets/textures' in f)}**\n")

    out_path = REPO / "docs/observability/asset_status.md"
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("".join(out))
    print(f"Wrote {out_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
