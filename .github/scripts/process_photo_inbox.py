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

import base64
import json
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
GEMINI_MODEL = "gemini-2.5-flash-image"
GEMINI_URL = f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent"
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


def call_gemini_img2img(photo: pathlib.Path, prompt: str, out: pathlib.Path) -> bool:
    """Use Gemini 2.5 Flash Image (Nano Banana) for image-to-image transform.
    Free tier available — see aistudio.google.com for limits."""
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        return False
    log(f"gemini img2img {out.name}: {prompt[:120]}...")
    img_bytes = photo.read_bytes()
    mime = "image/png" if photo.suffix.lower() == ".png" else "image/jpeg"
    body = {
        "contents": [{
            "parts": [
                {"text": f"Transform this photo into a chibi cartoon tower defense game character icon. Keep the face likeness recognizable but stylize heavily. Transparent background, centered, 1:1 aspect ratio. {prompt}"},
                {"inline_data": {"mime_type": mime, "data": base64.b64encode(img_bytes).decode("ascii")}},
            ]
        }],
        "generationConfig": {
            "responseModalities": ["IMAGE", "TEXT"],
        },
    }
    r = requests.post(
        f"{GEMINI_URL}?key={api_key}",
        json=body,
        headers={"Content-Type": "application/json"},
        timeout=180,
    )
    if r.status_code != 200:
        log(f"Gemini API returned {r.status_code}: {r.text[:500]}")
        return False
    data = r.json()
    try:
        for part in data["candidates"][0]["content"]["parts"]:
            if "inlineData" in part or "inline_data" in part:
                inline = part.get("inlineData") or part.get("inline_data")
                png_bytes = base64.b64decode(inline["data"])
                out.write_bytes(png_bytes)
                log(f"wrote {out} ({len(png_bytes)} bytes)")
                return True
    except (KeyError, IndexError) as e:
        log(f"Gemini response shape unexpected: {e}; payload: {json.dumps(data)[:500]}")
    return False


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


# HARD RULE (user directive): never use text-to-image for friend character
# icons. Likeness matters — always require an actual photo as input for
# Stability image-to-image. Sidecar-only entries are rejected.


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
        out_path = existing if (replace and existing.exists()) else OUT_DIR / f"friend_{slug}.png"

        # Generator selection: sidecar override > GEMINI key > STABILITY key
        requested: str = (meta.get("generator") or "").strip().lower()
        ok = False
        if requested == "stability":
            ok = call_stability_img2img(photo, prompt, out_path)
        elif requested == "gemini":
            ok = call_gemini_img2img(photo, prompt, out_path)
        else:
            # Default order: try Gemini (free tier, often better quality),
            # fall back to Stability if Gemini fails or isn't configured.
            if os.environ.get("GEMINI_API_KEY"):
                ok = call_gemini_img2img(photo, prompt, out_path)
                if not ok:
                    log(f"gemini failed for {photo.name} — falling back to stability")
            if not ok and os.environ.get("STABILITY_API_KEY"):
                ok = call_stability_img2img(photo, prompt, out_path)

        if ok:
            any_success = True
            photo.unlink()
            if sidecar.exists():
                sidecar.unlink()
        else:
            log(f"failed for {photo.name} — leaving in inbox for retry")

    # HARD RULE: text-only sidecars are rejected. Friend icons MUST be
    # produced from an actual photo via image-to-image. Any .yml without
    # a matching .jpg/.png is flagged in the logs and left alone (so the
    # user can add the photo later).
    for sidecar in INBOX_DIR.glob("*.yml"):
        has_image = any((INBOX_DIR / f"{sidecar.stem}{ext}").exists() for ext in (".jpg", ".jpeg", ".png"))
        if not has_image:
            log(f"WARN: sidecar {sidecar.name} has no matching photo — ignored (hard rule: img2img only)")

    emit_output("processed", "true" if any_success else "false")
    return 0 if any_success else 1


if __name__ == "__main__":
    sys.exit(main())
