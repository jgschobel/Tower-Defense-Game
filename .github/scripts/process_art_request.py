#!/usr/bin/env python3
"""
Process an art-request labeled issue. Parse the issue form for asset
type, filename slug, prompt, aspect ratio. Call Imagen 4 (Stability
fallback). Save to the right subfolder under assets/textures/.

Emits Actions outputs:
    asset_path = assets/textures/<category>/<slug>.png
    slug       = <slug>
"""
from __future__ import annotations

import os
import pathlib
import re
import sys
from typing import Optional

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from generators import generate_background  # noqa: E402


CATEGORY_DIRS = {
    "background (level map, 16:9)": "maps",
    "enemy (new monster concept, 1:1)": "enemies",
    "ui frame / panel / button (1:1)": "ui",
    "prop / item (1:1)": "projectiles",
    "promo / title card (16:9)": "ui",
}


def log(msg: str) -> None:
    print(f"[art_request] {msg}", flush=True)


def emit_output(key: str, value: str) -> None:
    out_file = os.environ.get("GITHUB_OUTPUT")
    if out_file:
        with open(out_file, "a") as f:
            f.write(f"{key}={value}\n")
    log(f"{key}={value}")


def parse_fields(body: str) -> dict:
    sections: dict[str, str] = {}
    current_title: Optional[str] = None
    current_lines: list[str] = []
    for line in body.splitlines():
        if line.startswith("### "):
            if current_title is not None:
                sections[current_title.strip().lower()] = "\n".join(current_lines).strip()
            current_title = line[4:].strip()
            current_lines = []
        elif current_title is not None:
            current_lines.append(line)
    if current_title is not None:
        sections[current_title.strip().lower()] = "\n".join(current_lines).strip()
    return sections


def slugify(name: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "_", name.lower().strip()).strip("_")
    return slug or "asset"


def main() -> int:
    body = os.environ.get("ISSUE_BODY", "")
    if not body.strip():
        log("empty issue body")
        return 1

    sections = parse_fields(body)
    asset_type = sections.get("asset type", "").strip()
    filename_raw = sections.get("filename slug", "").strip()
    prompt = sections.get("prompt / description", "").strip() or \
             sections.get("prompt", "").strip()
    aspect_line = sections.get("aspect ratio", "").strip()

    if not prompt:
        log("no prompt provided")
        return 1

    slug = slugify(filename_raw.splitlines()[0] if filename_raw else "asset")
    category = CATEGORY_DIRS.get(asset_type, "ui")

    # Extract aspect ratio token from the dropdown's label
    aspect_ratio = "1:1"
    for token in ("16:9", "9:16", "4:3", "3:4", "1:1"):
        if token in aspect_line:
            aspect_ratio = token
            break

    out_dir = pathlib.Path("assets/textures") / category
    out_dir.mkdir(parents=True, exist_ok=True)
    out_path = out_dir / f"{slug}.png"

    log(f"slug={slug} category={category} aspect={aspect_ratio}")
    log(f"prompt: {prompt[:160]}")

    ok = generate_background(prompt, out_path, aspect_ratio)
    if not ok:
        log("all generators failed")
        return 1

    emit_output("asset_path", str(out_path))
    emit_output("slug", slug)
    return 0


if __name__ == "__main__":
    sys.exit(main())
