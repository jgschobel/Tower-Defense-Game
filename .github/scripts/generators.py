"""
Shared image-generation helpers used by both the issue-form workflow
(photo_to_character.py) and the inbox workflow (process_photo_inbox.py).

Two providers supported:
- Gemini 2.5 Flash Image (aka Nano Banana) — free tier, often better
  quality for character-style transforms.
- Stability AI SD3.5-large — paid, original provider.

Generator selection (for either provider to be used, the matching
API key must be set via env):
- explicit "stability" or "gemini" override via sidecar or CLI
- default: try Gemini first, fall back to Stability
"""
from __future__ import annotations

import base64
import json
import os
import pathlib
from typing import Optional

import requests


STABILITY_URL = "https://api.stability.ai/v2beta/stable-image/generate/sd3"
GEMINI_MODEL = "gemini-2.5-flash-image-preview"
GEMINI_URL = f"https://generativelanguage.googleapis.com/v1beta/models/{GEMINI_MODEL}:generateContent"

NEGATIVE_PROMPT = (
    "photorealistic, photograph, realistic skin, nsfw, nude, text, watermark, logo, "
    "multiple characters, deformed hands, blurry, low quality"
)


def _log(msg: str) -> None:
    print(f"[generators] {msg}", flush=True)


def call_gemini_img2img(photo: pathlib.Path, prompt: str, out: pathlib.Path) -> bool:
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        return False
    _log(f"gemini img2img {out.name}: {prompt[:120]}...")
    img_bytes = photo.read_bytes()
    mime = "image/png" if photo.suffix.lower() == ".png" else "image/jpeg"
    body = {
        "contents": [{
            "parts": [
                {"text": (
                    "Transform this photo into a chibi cartoon tower defense game character icon. "
                    "Keep the face likeness recognizable but stylize heavily into a cute cartoon. "
                    "Transparent background (plain white also OK). Centered, 1:1 square. "
                    f"{prompt}"
                )},
                {"inline_data": {"mime_type": mime, "data": base64.b64encode(img_bytes).decode("ascii")}},
            ]
        }],
        "generationConfig": {"responseModalities": ["IMAGE", "TEXT"]},
    }
    r = requests.post(
        f"{GEMINI_URL}?key={api_key}",
        json=body,
        headers={"Content-Type": "application/json"},
        timeout=180,
    )
    if r.status_code != 200:
        _log(f"Gemini API returned {r.status_code}: {r.text[:500]}")
        return False
    data = r.json()
    try:
        for part in data["candidates"][0]["content"]["parts"]:
            inline = part.get("inlineData") or part.get("inline_data")
            if inline:
                png_bytes = base64.b64decode(inline["data"])
                out.write_bytes(png_bytes)
                _log(f"wrote {out} ({len(png_bytes)} bytes)")
                return True
    except (KeyError, IndexError) as e:
        _log(f"Gemini response shape unexpected: {e}; payload: {json.dumps(data)[:500]}")
    return False


def call_stability_img2img(photo: pathlib.Path, prompt: str, out: pathlib.Path) -> bool:
    api_key = os.environ.get("STABILITY_API_KEY")
    if not api_key:
        return False
    _log(f"stability img2img {out.name}: {prompt[:120]}...")
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
        _log(f"Stability API returned {r.status_code}: {r.text[:500]}")
        return False
    out.write_bytes(r.content)
    _log(f"wrote {out} ({len(r.content)} bytes)")
    return True


def generate_icon(
    photo: pathlib.Path,
    prompt: str,
    out: pathlib.Path,
    requested: Optional[str] = None,
) -> bool:
    """Try Gemini first, fall back to Stability. `requested` may be
    "gemini" or "stability" to force a specific provider (skipping
    the fallback)."""
    if requested == "stability":
        return call_stability_img2img(photo, prompt, out)
    if requested == "gemini":
        return call_gemini_img2img(photo, prompt, out)
    # Auto: prefer Gemini (free tier + better quality for characters)
    if os.environ.get("GEMINI_API_KEY"):
        if call_gemini_img2img(photo, prompt, out):
            return True
        _log("gemini failed — falling back to stability")
    if os.environ.get("STABILITY_API_KEY"):
        return call_stability_img2img(photo, prompt, out)
    _log("no image generator API key configured")
    return False
