#!/usr/bin/env python3
"""
Generate tier-upgrade art variants for a friend character via Gemini
img2img (Stability fallback) anchored to the existing photo. Replaces
the awful hue-tinted-photo placeholders with real per-tier portraits
that PRESERVE the friend's facial likeness.

Output filenames match dev_menu's tier-thumb path:
    res://assets/textures/towers/{char}_t{1,2,3}{a,b}.png

Inputs (env):
    CHAR_ID         e.g. "cordula", "kuhne" (tower id, lowercase)
    PHOTO_PATH      "assets/textures/towers/{char}_photo.jpg"
    GEMINI_API_KEY  required
    STABILITY_API_KEY  optional fallback

Per-character tier prompts are baked into TIER_PROMPTS below. Path A is
the offensive/utility branch, Path B is the support/control branch — the
visual progression should read at a glance: t1 = subtle gear, t2 =
visible upgrade, t3 = epic transformation.
"""
from __future__ import annotations

import os
import pathlib
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from generators import call_gemini_img2img, call_stability_img2img  # noqa: E402


# tower_id (used for the output filename, must match dev_menu's
# `{tower_id}_t{tier}{path}.png` lookup) → friend photo name root.
# "kuhne" is the photo basename but the in-game tower_id is "sniper".
CHAR_TO_TOWER_ID: dict[str, str] = {
    "cordula": "cordula",
    "kuhne":   "sniper",
}


TIER_PROMPTS: dict[str, dict[str, str]] = {
    "cordula": {
        "base_persona": (
            "the woman in this photo as a chibi cartoon volleyball-spike tower defense "
            "character. Cute Pixar-style, 1:1 square, transparent background, centered, "
            "her recognizable face — same hair color, eye color, jawline as the photo."
        ),
        "t1a": "Path A tier 1: holding a glowing volleyball, sport headband, confident smirk. Subtle gold accents.",
        "t2a": "Path A tier 2: athletic gear with reinforced gloves, double volleyball juggle, mid-spike action pose, gold lightning highlights.",
        "t3a": "Path A tier 3 EPIC: fiery comet volleyball mid-smash, golden battle armor, dynamic spike pose, sparks and motion lines, hero pose.",
        "t1b": "Path B tier 1: support coach role, whistle around neck, holding a clipboard with team symbols, calm encouraging smile.",
        "t2b": "Path B tier 2: team captain with a captain's armband, megaphone in hand, energy aura tinted teal, rallying pose.",
    },
    "kuhne": {
        "base_persona": (
            "the woman in this photo as a chibi cartoon sniper tower defense "
            "character. Cute Pixar-style, 1:1 square, transparent background, centered, "
            "her recognizable face — same hair, eyes, soft smile as the photo."
        ),
        "t1a": "Path A tier 1 fire-mage: holding a small flame in one hand, warm orange tint, focused expression, light ember particles.",
        "t2a": "Path A tier 2 fire-mage: cloaked sorceress with twin flame wisps, glowing orange-red eyes, fiery hair tips, intense magic stance.",
        "t3a": "Path A tier 3 EPIC fire-mage: full inferno robe, blazing fire halo, dragon-flame staff, embers and heat distortion, hero pose.",
        "t1b": "Path B tier 1 ice-archer: light blue scarf, holding a frost-tipped arrow, cool blue tint, calm precise gaze.",
        "t2b": "Path B tier 2 ice-archer: frosty cloak with snowflake patterns, drawing a glowing ice bow, frozen breath visible, focused archer pose.",
    },
}


def log(msg: str) -> None:
    print(f"[tier_variants] {msg}", flush=True)


def generate_one(photo: pathlib.Path, prompt: str, out: pathlib.Path) -> bool:
    if call_gemini_img2img(photo, prompt, out):
        return True
    log(f"gemini failed for {out.name} — trying stability fallback")
    if call_stability_img2img(photo, prompt, out):
        return True
    log(f"both providers failed for {out.name}")
    return False


def main() -> int:
    char = os.environ.get("CHAR_ID", "").strip().lower()
    if char not in TIER_PROMPTS:
        log(f"unknown CHAR_ID '{char}'. Known: {sorted(TIER_PROMPTS)}")
        return 1
    photo_path_str = os.environ.get("PHOTO_PATH", f"assets/textures/towers/{char}_photo.jpg")
    photo = pathlib.Path(photo_path_str)
    if not photo.exists():
        log(f"photo not found: {photo}")
        return 1

    spec = TIER_PROMPTS[char]
    persona = spec["base_persona"]
    tower_id = CHAR_TO_TOWER_ID.get(char, char)
    out_dir = pathlib.Path("assets/textures/towers")
    out_dir.mkdir(parents=True, exist_ok=True)

    written: list[str] = []
    for tier_key in ("t1a", "t2a", "t3a", "t1b", "t2b"):
        out_path = out_dir / f"{tower_id}_{tier_key}.png"
        full_prompt = f"{persona} {spec[tier_key]}"
        log(f"=== {tower_id}_{tier_key} (from {char}_photo) ===")
        if generate_one(photo, full_prompt, out_path):
            written.append(str(out_path))
        else:
            log(f"skipped {out_path}")

    if not written:
        log("nothing generated — both providers failed for every tier")
        return 1

    out_file = os.environ.get("GITHUB_OUTPUT")
    if out_file:
        with open(out_file, "a") as f:
            f.write(f"asset_paths={','.join(written)}\n")
            f.write(f"char_id={char}\n")
            f.write(f"count={len(written)}\n")
    log(f"wrote {len(written)} tier variants for {char}: {written}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
