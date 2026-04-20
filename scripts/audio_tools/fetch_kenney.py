#!/usr/bin/env python3
"""Download Kenney.nl CC0 audio packs and bake selected files into the
game's audio registry.

Usage:
    python3 scripts/audio_tools/fetch_kenney.py

Idempotent: skips already-present files. Safe to re-run. Updates
resources/audio_config.tres in place so sfx_manager.gd starts using
the baked clips on next game load.

CC0 attribution lives in assets/audio/sfx/kenney/README.md.
"""

from __future__ import annotations

import hashlib
import io
import os
import sys
import zipfile
from pathlib import Path
from typing import Dict, List, Tuple
from urllib.request import Request, urlopen

ROOT = Path(__file__).resolve().parents[2]
DEST_DIR = ROOT / "assets" / "audio" / "sfx" / "kenney"
CONFIG_PATH = ROOT / "resources" / "audio_config.tres"

# Mapping of game id -> (kenney pack URL, file name inside the zip,
# local filename). Every entry sourced from Kenney.nl / kenney.itch.io
# under CC0. If a URL 404s we log and skip that entry — other ids
# still bake.
#
# Pack URLs point at Kenney's Itch.io CDN direct downloads. These are
# the canonical CC0 redistributions. If they move, update here.
KENNEY_PACKS: Dict[str, Tuple[str, str, str]] = {
    # --- UI / feedback ---
    "ui.click": (
        "https://kenney.nl/media/pages/assets/ui-audio/abf3aadc95-1677693490/kenney_ui-audio.zip",
        "Audio/click_001.ogg",
        "click_001.ogg",
    ),
    "sell": (
        "https://kenney.nl/media/pages/assets/ui-audio/abf3aadc95-1677693490/kenney_ui-audio.zip",
        "Audio/drop_002.ogg",
        "drop_002.ogg",
    ),
    "upgrade": (
        "https://kenney.nl/media/pages/assets/ui-audio/abf3aadc95-1677693490/kenney_ui-audio.zip",
        "Audio/confirmation_002.ogg",
        "confirmation_002.ogg",
    ),
    "wave_start": (
        "https://kenney.nl/media/pages/assets/ui-audio/abf3aadc95-1677693490/kenney_ui-audio.zip",
        "Audio/bong_001.ogg",
        "bong_001.ogg",
    ),
    # --- Gameplay ---
    "place": (
        "https://kenney.nl/media/pages/assets/impact-sounds/43908b6d99-1677693581/kenney_impact-sounds.zip",
        "Audio/impactWood_medium_002.ogg",
        "impactWood_medium_002.ogg",
    ),
    "hit": (
        "https://kenney.nl/media/pages/assets/impact-sounds/43908b6d99-1677693581/kenney_impact-sounds.zip",
        "Audio/impactSoft_medium_001.ogg",
        "impactSoft_medium_001.ogg",
    ),
    "death": (
        "https://kenney.nl/media/pages/assets/impact-sounds/43908b6d99-1677693581/kenney_impact-sounds.zip",
        "Audio/impactPlate_medium_002.ogg",
        "impactPlate_medium_002.ogg",
    ),
    "life_lost": (
        "https://kenney.nl/media/pages/assets/impact-sounds/43908b6d99-1677693581/kenney_impact-sounds.zip",
        "Audio/impactPunch_medium_001.ogg",
        "impactPunch_medium_001.ogg",
    ),
}


def fetch_zip(url: str) -> zipfile.ZipFile | None:
    print(f"  fetching {url} ...", flush=True)
    try:
        req = Request(url, headers={"User-Agent": "tower-defense-audio-bot/1.0"})
        with urlopen(req, timeout=120) as resp:
            blob = resp.read()
        return zipfile.ZipFile(io.BytesIO(blob))
    except Exception as exc:  # noqa: BLE001
        print(f"  ! fetch failed: {exc}", flush=True)
        return None


def bake_file(zf: zipfile.ZipFile, member: str, dest: Path) -> bool:
    try:
        data = zf.read(member)
    except KeyError:
        print(f"  ! member missing in zip: {member}", flush=True)
        return False
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(data)
    print(f"  + {dest.relative_to(ROOT)} ({len(data)} bytes)", flush=True)
    return True


def update_audio_config(entries: Dict[str, str]) -> None:
    """Rewrite resources/audio_config.tres preserving existing entries,
    adding new ones from `entries` (id -> res:// path)."""
    existing_lines = CONFIG_PATH.read_text().splitlines()
    # Parse `sfx = {...}` block. Simple approach: regenerate whole file
    # from scratch since we own the format.
    keep_header: List[str] = []
    for line in existing_lines:
        keep_header.append(line)
        if line.strip() == "[resource]":
            break
    keep_header.append('script = ExtResource("1")')

    sfx_block = ["sfx = {"]
    for k in sorted(entries):
        sfx_block.append(f'\t"{k}": "{entries[k]}",')
    sfx_block.append("}")

    new_content = "\n".join(keep_header + sfx_block + ["music = {}"]) + "\n"
    CONFIG_PATH.write_text(new_content)
    print(f"  wrote {CONFIG_PATH.relative_to(ROOT)} with {len(entries)} sfx entries")


def main() -> int:
    DEST_DIR.mkdir(parents=True, exist_ok=True)
    # Group by URL so each zip is downloaded once.
    by_url: Dict[str, List[Tuple[str, str, str]]] = {}
    for sfx_id, (url, member, fname) in KENNEY_PACKS.items():
        by_url.setdefault(url, []).append((sfx_id, member, fname))

    entries: Dict[str, str] = {}
    for url, items in by_url.items():
        pending = [(sfx_id, member, fname) for sfx_id, member, fname in items
                   if not (DEST_DIR / fname).exists()]
        if pending:
            zf = fetch_zip(url)
            if zf is None:
                continue
        else:
            zf = None
        for sfx_id, member, fname in items:
            dest = DEST_DIR / fname
            if dest.exists():
                print(f"  = {dest.relative_to(ROOT)} (already present)", flush=True)
                entries[sfx_id] = f"res://assets/audio/sfx/kenney/{fname}"
                continue
            if zf is not None and bake_file(zf, member, dest):
                entries[sfx_id] = f"res://assets/audio/sfx/kenney/{fname}"

    if not entries:
        print("no entries baked (all fetches may have failed)", flush=True)
        return 1

    # Merge with any existing entries (future: AI-generated) instead of
    # blowing them away.
    existing = parse_existing_sfx()
    merged = {**existing, **entries}
    update_audio_config(merged)
    return 0


def parse_existing_sfx() -> Dict[str, str]:
    import re
    text = CONFIG_PATH.read_text()
    m = re.search(r"sfx\s*=\s*\{([^}]*)\}", text, re.DOTALL)
    if not m:
        return {}
    body = m.group(1)
    out: Dict[str, str] = {}
    for line in body.splitlines():
        line = line.strip().rstrip(",")
        if not line:
            continue
        parts = line.split(":", 1)
        if len(parts) != 2:
            continue
        k = parts[0].strip().strip('"')
        v = parts[1].strip().strip('"')
        if k and v:
            out[k] = v
    return out


if __name__ == "__main__":
    sys.exit(main())
