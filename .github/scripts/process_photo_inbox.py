#!/usr/bin/env python3
"""
Scan .github/friend_photos_inbox/ for .jpg/.jpeg/.png files. For each,
look for an optional sidecar <slug>.yml with metadata (name, description,
style). Call Stability AI image-to-image to produce a chibi cartoon
icon, save to assets/textures/towers/friend_<slug>.png, and delete the
inbox entries.

Emits GitHub Actions output:
    processed=true        if any icon was generated
    processed=false       otherwise
"""
from __future__ import annotations

import os
import pathlib
import re
import sys
from typing import Optional

import requests

try:
    import yaml
except ImportError:
    yaml = None  # optional


STABILITY_URL = "https://api.stability.ai/v2beta/stable-image/generate/sd3"
INBOX_DIR = pathlib.Path(".github/friend_photos_inbox")
OUT_DIR = pathlib.Path("assets/textures/towers")


DEFAULT_PROMPT = (
    "chibi cartoon character tower defense game icon, round face, big expressive eyes, "
    "bright bold colors, thick black outline, transparent background, centered, "
    "Swiss alpine village vibe, high-quality digital art, no text, no watermark"
)

NEGATIVE_PROMPT = (
    "photorealistic, photograph, realistic skin, nsfw, nude, text, watermark, logo, "
    "multiple characters, deformed hands, blurry, low quality"
)


def log(msg: str) -> None:
    print(f"[photo_inbox] {msg}", flush=True)


def emit_output(key: str, value: str) -> None:
    out_file = os.environ.get("GITHUB_OUTPUT")
    if out_file:
        with open(out_file, "a") as f:
            f.write(f"{key}={value}\n")
    log(f"{key}={value}")


def slugify(name: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "_", name.lower().strip()).strip("_")
    return slug or "friend"


def call_stability_img2img(photo: pathlib.Path, prompt: str, out: pathlib.Path) -> bool:
    api_key = os.environ.get("STABILITY_API_KEY")
    if not api_key:
        log("STABILITY_API_KEY not set — skipping")
        return False
    log(f"img2img {out.name}: {prompt[:120]}...")
    with open(photo, "rb") as f:
        files = {"image": ("photo", f, "application/octet-stream")}
        data = {
            "prompt": prompt,
            "negative_prompt": NEGATIVE_PROMPT,
            "mode": "image-to-image",
            "strength": "0.75",
            "output_format": "png",
            "aspect_ratio": "1:1",
            "model": "sd3.5-large",
        }
        r = requests.post(
            STABILITY_URL,
            headers={"Authorization": f"Bearer {api_key}", "Accept": "image/*"},
            files=files,
            data=data,
            timeout=180,
        )
    if r.status_code != 200:
        log(f"Stability API returned {r.status_code}: {r.text[:500]}")
        return False
    out.write_bytes(r.content)
    log(f"wrote {out} ({len(r.content)} bytes)")
    return True


def call_stability_text2img(prompt: str, out: pathlib.Path) -> bool:
    api_key = os.environ.get("STABILITY_API_KEY")
    if not api_key:
        log("STABILITY_API_KEY not set — skipping")
        return False
    log(f"text2img {out.name}: {prompt[:120]}...")
    data = {
        "prompt": prompt,
        "negative_prompt": NEGATIVE_PROMPT,
        "output_format": "png",
        "aspect_ratio": "1:1",
        "model": "sd3.5-large",
    }
    # SD3 text-to-image requires at least one file field per API quirks
    files = {"none": ("", "", "application/octet-stream")}
    r = requests.post(
        STABILITY_URL,
        headers={"Authorization": f"Bearer {api_key}", "Accept": "image/*"},
        files=files,
        data=data,
        timeout=180,
    )
    if r.status_code != 200:
        log(f"Stability API returned {r.status_code}: {r.text[:500]}")
        return False
    out.write_bytes(r.content)
    log(f"wrote {out} ({len(r.content)} bytes)")
    return True


def load_sidecar(path: pathlib.Path) -> dict:
    if not path.exists() or yaml is None:
        return {}
    try:
        with open(path) as f:
            data = yaml.safe_load(f) or {}
            return data if isinstance(data, dict) else {}
    except Exception as e:
        log(f"failed to parse sidecar {path}: {e}")
        return {}


def build_prompt(meta: dict) -> str:
    prompt = DEFAULT_PROMPT
    desc = meta.get("description", "").strip()
    style = meta.get("style", "").strip().lower()
    if style == "warrior":
        prompt = prompt.replace("Swiss alpine village vibe", "heroic warrior with shining armor")
    elif style == "scholar":
        prompt = prompt.replace("Swiss alpine village vibe", "scholar with round glasses and flowing robes")
    elif style == "pirate":
        prompt = prompt.replace("Swiss alpine village vibe", "pirate with tricorn hat and cutlass")
    elif style == "pixie":
        prompt = prompt.replace("Swiss alpine village vibe", "forest pixie with delicate wings and flower crown")
    elif style == "punk":
        prompt = prompt.replace("Swiss alpine village vibe", "punk with leather jacket and colorful mohawk")
    if desc:
        prompt = f"{prompt}. Character notes: {desc[:400]}"
    return prompt


def main() -> int:
    if not INBOX_DIR.exists():
        log("no inbox dir — nothing to do")
        emit_output("processed", "false")
        return 0

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    photos: list[pathlib.Path] = []
    for ext in (".jpg", ".jpeg", ".png"):
        photos.extend(INBOX_DIR.glob(f"*{ext}"))
        photos.extend(INBOX_DIR.glob(f"*{ext.upper()}"))

    if not photos:
        log("no photos found in inbox")
        emit_output("processed", "false")
        return 0

    any_success = False
    for photo in photos:
        slug = slugify(photo.stem)
        sidecar = INBOX_DIR / f"{photo.stem}.yml"
        meta = load_sidecar(sidecar)
        prompt = build_prompt(meta)
        replace = bool(meta.get("replace_existing", False))
        existing = OUT_DIR / f"{slug}.png"
        if replace and existing.exists():
            out_path = existing
        else:
            out_path = OUT_DIR / f"friend_{slug}.png"
        ok = call_stability_img2img(photo, prompt, out_path)
        if ok:
            any_success = True
            photo.unlink()
            if sidecar.exists():
                sidecar.unlink()
        else:
            log(f"failed for {photo.name} — leaving in inbox for retry")

    # Also process text-only entries — sidecar .yml with no matching image
    for sidecar in INBOX_DIR.glob("*.yml"):
        slug = slugify(sidecar.stem)
        # Skip if a matching image exists (already handled above)
        has_image = any((INBOX_DIR / f"{sidecar.stem}{ext}").exists() for ext in (".jpg", ".jpeg", ".png"))
        if has_image:
            continue
        meta = load_sidecar(sidecar)
        if not meta.get("text_only"):
            continue
        prompt = build_prompt(meta)
        replace = bool(meta.get("replace_existing", False))
        existing = OUT_DIR / f"{slug}.png"
        if replace and existing.exists():
            out_path = existing
        else:
            out_path = OUT_DIR / f"friend_{slug}.png"
        ok = call_stability_text2img(prompt, out_path)
        if ok:
            any_success = True
            sidecar.unlink()
        else:
            log(f"text-only failed for {sidecar.name} — leaving for retry")

    emit_output("processed", "true" if any_success else "false")
    return 0 if any_success else 1


if __name__ == "__main__":
    sys.exit(main())
