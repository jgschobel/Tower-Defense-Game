#!/usr/bin/env python3
"""
Extract a photo attachment from the friend-photo issue body, send it
through our image-to-image pipeline (Gemini 2.5 Flash Image with
Stability fallback — see generators.py), and save the resulting chibi
cartoon icon under assets/textures/towers/friend_<slug>.png.

Emits GitHub Actions outputs:
    asset_path=assets/textures/towers/friend_<slug>.png
    character_name=<slug>
"""
from __future__ import annotations

import os
import re
import sys
import time
import pathlib
from typing import Optional

import requests

# Ensure we can import the sibling generators module
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from generators import generate_icon  # noqa: E402


def log(msg: str) -> None:
    print(f"[photo_to_character] {msg}", flush=True)


def emit_output(key: str, value: str) -> None:
    out_file = os.environ.get("GITHUB_OUTPUT")
    if out_file:
        with open(out_file, "a") as f:
            f.write(f"{key}={value}\n")
    log(f"{key}={value}")


def slugify(name: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "_", name.lower().strip()).strip("_")
    return slug or "friend"


def parse_fields(body: str) -> dict:
    # GitHub issue forms emit markdown with `### Field Name` sections.
    # Parse the body into a dict of section-title → section-content.
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


def extract_first_image_url(text: str) -> Optional[str]:
    # Match markdown image syntax, HTML <img src=>, or raw URL to github assets.
    patterns = [
        r'!\[[^\]]*\]\((https?://[^\s\)]+)\)',
        r'<img[^>]+src="([^"]+)"',
        r'(https://github\.com/user-attachments/assets/[^\s)"]+)',
        r'(https://user-images\.githubusercontent\.com/[^\s)"]+)',
    ]
    for pat in patterns:
        m = re.search(pat, text)
        if m:
            return m.group(1)
    return None


STYLE_PROMPTS = {
    "default (chibi cartoon, matches existing tower art)": (
        "chibi cartoon character tower defense game icon, round face, big expressive eyes, "
        "bright colors, thick black outline, transparent background, centered, Swiss alpine village vibe, "
        "high-quality digital art, no text, no watermark"
    ),
    "warrior (armored, heroic)": (
        "chibi cartoon warrior character, shining armor, heroic pose, sword or shield, "
        "bright bold colors, transparent background, game icon, centered, no text"
    ),
    "scholar (robes, books, glasses)": (
        "chibi cartoon scholar character, round glasses, flowing robes, holding a book, wise expression, "
        "warm colors, transparent background, game icon, centered, no text"
    ),
    "pirate (tricorn, eyepatch, cutlass)": (
        "chibi cartoon pirate character, tricorn hat, eyepatch, cutlass, confident grin, "
        "nautical colors, transparent background, game icon, centered, no text"
    ),
    "pixie/nature (flowers, wings, leaves)": (
        "chibi cartoon nature pixie character, delicate wings, flower crown, leaf-patterned clothes, "
        "magical sparkles, pastel colors, transparent background, game icon, centered, no text"
    ),
    "punk (leather, mohawk, shades)": (
        "chibi cartoon punk character, leather jacket, colorful mohawk, sunglasses, studded collar, "
        "bold neon colors, transparent background, game icon, centered, no text"
    ),
}

NEGATIVE_PROMPT = (
    "photorealistic, photograph, realistic skin, nsfw, nude, text, watermark, logo, "
    "multiple characters, deformed hands, blurry, low quality"
)


def download(url: str, dest: pathlib.Path) -> None:
    log(f"downloading {url}")
    headers = {}
    gh_token = os.environ.get("GITHUB_TOKEN") or os.environ.get("GH_TOKEN")
    if gh_token and "github" in url:
        headers["Authorization"] = f"Bearer {gh_token}"
    r = requests.get(url, headers=headers, timeout=60)
    r.raise_for_status()
    dest.write_bytes(r.content)
    log(f"wrote {dest} ({len(r.content)} bytes)")


def main() -> int:
    body = os.environ.get("ISSUE_BODY", "")
    if not body.strip():
        log("empty issue body — nothing to do")
        # Write a reason file so the workflow can comment back meaningfully
        _write_reason("Empty issue body — nothing to process")
        return 1

    log(f"body length: {len(body)} chars")
    sections = parse_fields(body)
    log(f"parsed sections: {list(sections.keys())}")
    name_raw = sections.get("character name (swiss german welcome)", "") or \
               sections.get("character name", "")
    if not name_raw:
        log("no character name found in issue body — aborting")
        _write_reason("No '### Character name' section found in the issue body. Open a fresh issue using the `friend-photo` template.")
        return 1

    description = sections.get("character description / vibe", "") or \
                  sections.get("character description", "")
    style_choice = sections.get("style", "").strip()
    style_prompt = STYLE_PROMPTS.get(style_choice, STYLE_PROMPTS[list(STYLE_PROMPTS.keys())[0]])

    # The photo section should contain a markdown image link.
    photo_block = sections.get("photo", "") or body
    image_url = extract_first_image_url(photo_block) or extract_first_image_url(body)
    if not image_url:
        log("no image attachment found — aborting")
        _write_reason("No image attachment found in the issue body or photo section. Make sure you dragged a photo into the 'Photo' field of the issue form (or pasted it anywhere in the body).")
        return 1

    slug = slugify(name_raw.splitlines()[0])
    log(f"character_name={name_raw!r} slug={slug!r}")
    log(f"image_url={image_url}")

    work = pathlib.Path("/tmp/friend_photo")
    work.mkdir(parents=True, exist_ok=True)
    photo_path = work / f"{slug}_input.jpg"
    try:
        download(image_url, photo_path)
    except Exception as e:
        log(f"download failed: {e}")
        _write_reason(
            f"Photo download failed: {e}.\n\n"
            "**Known GitHub issue**: user-attachment URLs return 404 to "
            "workflow clients (auth scope limitation on GitHub's side — "
            "the GITHUB_TOKEN can't fetch images the browser can).\n\n"
            "**Workaround**: upload the photo directly to "
            "`.github/friend_photos_inbox/<slug>.jpg` via GitHub mobile "
            "(Add file → Upload files). The `photo-inbox.yml` workflow "
            "will then process it reliably. See "
            "`.github/friend_photos_inbox/README.md` for the 30-second "
            "phone walkthrough."
        )
        return 1

    out_dir = pathlib.Path("assets/textures/towers")
    out_dir.mkdir(parents=True, exist_ok=True)
    # If a tower with that slug already exists, overwrite so the new icon
    # flows directly into the existing .tres wiring.
    existing = out_dir / f"{slug}.png"
    out_path = existing if existing.exists() else out_dir / f"friend_{slug}.png"

    prompt = style_prompt
    if description:
        prompt = f"{style_prompt}. Character notes: {description.strip()[:400]}"

    ok = generate_icon(photo_path, prompt, out_path)
    if not ok:
        log("all generators failed")
        _write_reason("All image generators failed. Likely causes: (1) GEMINI_API_KEY and STABILITY_API_KEY secrets missing or expired; (2) API quota exhausted for the day; (3) Gemini image model renamed. Check workflow logs for the specific HTTP error.")
        return 1

    emit_output("asset_path", str(out_path))
    emit_output("character_name", slug)
    return 0


def _write_reason(msg: str) -> None:
    """Write a human-readable reason for failure so the workflow can
    comment it back onto the issue. Previously failures went silent."""
    try:
        pathlib.Path("/tmp/photo_reason.txt").write_text(msg)
    except Exception:
        pass
    log(f"REASON: {msg}")


if __name__ == "__main__":
    sys.exit(main())
