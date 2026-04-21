#!/usr/bin/env python3
"""Stitch per-level playtest screenshots into a 4x4 audit grid.

Reads PNGs from docs/playtest_shots/latest/ (matching level_*.png +
upgrade_*.png), composes a single docs/playtest_shots/<YYYY-MM-DD>/
audit_grid.png so the next session can Read it and see the whole
game state in one image. Part of ROADMAP #42.

Requires Pillow. Workflow installs it before running.
"""

from __future__ import annotations

import sys
from datetime import datetime, timezone
from pathlib import Path

try:
    from PIL import Image
except ImportError:
    print("Pillow not installed; run `pip install pillow`", file=sys.stderr)
    sys.exit(1)

ROOT = Path(__file__).resolve().parents[2]
SHOTS_ROOT = ROOT / "docs" / "playtest_shots"
SRC_DIR = SHOTS_ROOT / "latest"
TODAY = datetime.now(timezone.utc).strftime("%Y-%m-%d")
OUT_DIR = SHOTS_ROOT / TODAY
OUT_DIR.mkdir(parents=True, exist_ok=True)

TILE_W = 320
TILE_H = 180
COLS = 4
ROWS = 4
PADDING = 8


def collect_tiles() -> list[Path]:
    if not SRC_DIR.exists():
        return []
    # Prefer level_*.png then upgrade_*.png, deterministic order.
    levels = sorted(SRC_DIR.glob("level_*.png"))
    upgrades = sorted(SRC_DIR.glob("upgrade_*.png"))
    tiles = (levels + upgrades)[: COLS * ROWS]
    return tiles


def build_grid(tiles: list[Path]) -> Image.Image:
    w = COLS * TILE_W + (COLS + 1) * PADDING
    h = ROWS * TILE_H + (ROWS + 1) * PADDING
    canvas = Image.new("RGB", (w, h), (20, 20, 24))
    for idx, tile_path in enumerate(tiles):
        r, c = divmod(idx, COLS)
        try:
            img = Image.open(tile_path).convert("RGB")
        except Exception as exc:  # noqa: BLE001
            print(f"[stitch] skip {tile_path.name}: {exc}")
            continue
        img = img.resize((TILE_W, TILE_H), Image.LANCZOS)
        x = PADDING + c * (TILE_W + PADDING)
        y = PADDING + r * (TILE_H + PADDING)
        canvas.paste(img, (x, y))
    return canvas


def main() -> int:
    tiles = collect_tiles()
    if not tiles:
        print("[stitch] no source shots in %s — nothing to stitch" % SRC_DIR)
        return 0
    grid = build_grid(tiles)
    out_path = OUT_DIR / "audit_grid.png"
    grid.save(out_path, optimize=True)
    print(f"[stitch] wrote {out_path.relative_to(ROOT)} with {len(tiles)} tiles")
    # Keep a "latest" symlink-ish copy for chat agents that always Read
    # the same path.
    latest_copy = SHOTS_ROOT / "audit_grid_latest.png"
    grid.save(latest_copy, optimize=True)
    return 0


if __name__ == "__main__":
    sys.exit(main())
