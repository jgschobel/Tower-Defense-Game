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
# Gemini img2img model candidates (tried in order for img2img transforms).
GEMINI_MODELS = [
    "gemini-2.5-flash-image",          # production GA (expected post-2025)
    "gemini-2.5-flash-image-preview",  # preview name used earlier
    "gemini-2.0-flash-exp-image-generation",  # older fallback
]
# Gemini text2img via generateContent (different endpoint from Imagen 4 predict).
# These work with a standard GEMINI_API_KEY and are tried before Imagen 4.
GEMINI_TEXT2IMG_MODELS = [
    "gemini-2.0-flash-exp-image-generation",
    "gemini-2.5-flash-image-preview",
    "gemini-2.5-flash-image",
]
IMAGEN_MODEL = "imagen-4.0-generate-001"
IMAGEN_URL = f"https://generativelanguage.googleapis.com/v1beta/models/{IMAGEN_MODEL}:predict"

NEGATIVE_PROMPT = (
    "photorealistic, photograph, realistic skin, nsfw, nude, text, watermark, logo, "
    "multiple characters, deformed hands, blurry, low quality"
)


def _log(msg: str) -> None:
    print(f"[generators] {msg}", flush=True)


def _load_style_sheet() -> str:
    """Read docs/art_style.md and return the universal style tokens
    section. Prepended to every generation prompt so all assets stay
    visually coherent across runs and providers."""
    path = pathlib.Path("docs/art_style.md")
    if not path.exists():
        return ""
    text = path.read_text()
    in_section = False
    out_lines: list[str] = []
    for line in text.splitlines():
        if line.startswith("## Universal Style Tokens"):
            in_section = True
            continue
        if in_section and line.startswith("## "):
            break
        if in_section:
            out_lines.append(line)
    sheet = "\n".join(out_lines).strip()
    return f"\n\nGlobal style guide:\n{sheet}\n" if sheet else ""


def call_gemini_img2img(photo: pathlib.Path, prompt: str, out: pathlib.Path) -> bool:
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        _log("GEMINI_API_KEY not set — skipping gemini")
        return False
    img_bytes = photo.read_bytes()
    mime = "image/png" if photo.suffix.lower() == ".png" else "image/jpeg"
    style_sheet = _load_style_sheet()
    body = {
        "contents": [{
            "parts": [
                {"text": (
                    "Transform this photo into a chibi cartoon tower defense game character icon. "
                    "Keep the face likeness recognizable but stylize heavily into a cute cartoon. "
                    "Transparent background (plain white also OK). Centered, 1:1 square. "
                    f"{prompt}"
                    f"{style_sheet}"
                )},
                {"inline_data": {"mime_type": mime, "data": base64.b64encode(img_bytes).decode("ascii")}},
            ]
        }],
        "generationConfig": {"responseModalities": ["IMAGE", "TEXT"]},
    }
    last_error = ""
    for model in GEMINI_MODELS:
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent"
        _log(f"gemini img2img {out.name} via {model}: {prompt[:100]}...")
        try:
            r = requests.post(
                f"{url}?key={api_key}",
                json=body,
                headers={"Content-Type": "application/json"},
                timeout=180,
            )
        except requests.RequestException as e:
            last_error = f"request exception: {e}"
            _log(f"gemini {model} network error: {e}")
            continue
        if r.status_code == 404 or r.status_code == 400:
            last_error = f"{r.status_code}: {r.text[:200]}"
            _log(f"gemini {model} returned {r.status_code} — trying next model")
            continue
        if r.status_code != 200:
            last_error = f"{r.status_code}: {r.text[:400]}"
            _log(f"gemini {model} unexpected status {r.status_code}: {r.text[:300]}")
            continue
        try:
            data = r.json()
            for part in data["candidates"][0]["content"]["parts"]:
                inline = part.get("inlineData") or part.get("inline_data")
                if inline:
                    png_bytes = base64.b64decode(inline["data"])
                    out.write_bytes(png_bytes)
                    _log(f"gemini {model} wrote {out} ({len(png_bytes)} bytes)")
                    return True
            last_error = "no inlineData in response"
            _log(f"gemini {model} returned 200 but no image data; payload head: {json.dumps(data)[:400]}")
        except Exception as e:
            last_error = f"parse error: {e}"
            _log(f"gemini {model} response parse error: {e}")
    _log(f"all gemini model candidates failed — last error: {last_error}")
    return False


def call_stability_img2img(photo: pathlib.Path, prompt: str, out: pathlib.Path) -> bool:
    api_key = os.environ.get("STABILITY_API_KEY")
    if not api_key:
        return False
    _log(f"stability img2img {out.name}: {prompt[:120]}...")
    full_prompt = prompt + _load_style_sheet()
    with open(photo, "rb") as f:
        files = {"image": ("photo", f, "application/octet-stream")}
        data = {
            "prompt": full_prompt,
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


def call_imagen4_text2img(prompt: str, out: pathlib.Path, aspect_ratio: str = "1:1") -> bool:
    """Pure text-to-image via Imagen 4. Use for backgrounds, new monster
    concepts, UI frames, props — NEVER for friend character icons (those
    must go through img2img, hard rule).

    aspect_ratio: "1:1" (default), "16:9" (landscape backgrounds), "9:16",
    "4:3", "3:4".
    """
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        return False
    _log(f"imagen4 text2img {out.name} [{aspect_ratio}]: {prompt[:120]}...")
    body = {
        "instances": [{"prompt": prompt + _load_style_sheet()}],
        "parameters": {
            "sampleCount": 1,
            "aspectRatio": aspect_ratio,
            "personGeneration": "allow_adult",
        },
    }
    r = requests.post(
        f"{IMAGEN_URL}?key={api_key}",
        json=body,
        headers={"Content-Type": "application/json"},
        timeout=180,
    )
    if r.status_code != 200:
        _log(f"Imagen 4 API returned {r.status_code}: {r.text[:500]}")
        return False
    data = r.json()
    try:
        preds = data.get("predictions", [])
        if not preds:
            _log(f"Imagen 4 empty predictions: {json.dumps(data)[:300]}")
            return False
        b64 = preds[0].get("bytesBase64Encoded")
        if not b64:
            _log(f"Imagen 4 response missing bytes: {json.dumps(preds[0])[:300]}")
            return False
        png_bytes = base64.b64decode(b64)
        out.write_bytes(png_bytes)
        _log(f"wrote {out} ({len(png_bytes)} bytes)")
        return True
    except Exception as e:
        _log(f"Imagen 4 parse error: {e}")
    return False


def call_gemini_text2img(prompt: str, out: pathlib.Path, aspect_ratio: str = "1:1") -> bool:
    """Text-to-image via Gemini generateContent endpoint (works with standard
    GEMINI_API_KEY, unlike Imagen 4 which may require billing/special access).
    Tries GEMINI_TEXT2IMG_MODELS in order."""
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        return False
    style_sheet = _load_style_sheet()
    body = {
        "contents": [{"parts": [{"text": prompt + style_sheet}]}],
        "generationConfig": {"responseModalities": ["IMAGE", "TEXT"]},
    }
    last_error = ""
    for model in GEMINI_TEXT2IMG_MODELS:
        url = f"https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={api_key}"
        _log(f"gemini text2img {out.name} via {model}: {prompt[:80]}...")
        try:
            r = requests.post(url, json=body, headers={"Content-Type": "application/json"}, timeout=180)
        except requests.RequestException as e:
            last_error = f"network: {e}"
            _log(f"gemini {model} network error: {e}")
            continue
        if r.status_code in (400, 404):
            last_error = f"{r.status_code}: {r.text[:200]}"
            _log(f"gemini {model} returned {r.status_code} — trying next model")
            continue
        if r.status_code != 200:
            last_error = f"{r.status_code}: {r.text[:300]}"
            _log(f"gemini {model} unexpected {r.status_code}: {r.text[:200]}")
            continue
        try:
            data = r.json()
            for part in data["candidates"][0]["content"]["parts"]:
                inline = part.get("inlineData") or part.get("inline_data")
                if inline:
                    png_bytes = base64.b64decode(inline["data"])
                    out.write_bytes(png_bytes)
                    _log(f"gemini text2img {model} wrote {out} ({len(png_bytes)} bytes)")
                    return True
            last_error = "no inlineData in 200 response"
            _log(f"gemini {model} 200 but no image: {json.dumps(data)[:300]}")
        except Exception as e:
            last_error = f"parse: {e}"
            _log(f"gemini {model} parse error: {e}")
    _log(f"all gemini text2img models failed — last: {last_error}")
    return False


def generate_background(prompt: str, out: pathlib.Path, aspect_ratio: str = "16:9") -> bool:
    """Text-to-image for non-friend art. Tries Gemini Flash, then Imagen 4,
    then Stability SD3."""
    if os.environ.get("GEMINI_API_KEY"):
        # Gemini Flash generateContent endpoint (standard API key, more accessible)
        if call_gemini_text2img(prompt, out, aspect_ratio):
            return True
        _log("gemini text2img failed — trying imagen4")
        if call_imagen4_text2img(prompt, out, aspect_ratio):
            return True
        _log("imagen4 also failed — trying stability text2img")
    # Stability SD3 text-to-image fallback
    if os.environ.get("STABILITY_API_KEY"):
        api_key = os.environ["STABILITY_API_KEY"]
        _log(f"stability text2img {out.name}: {prompt[:120]}...")
        data = {
            "prompt": prompt,
            "negative_prompt": NEGATIVE_PROMPT,
            "output_format": "png",
            "aspect_ratio": aspect_ratio,
            "model": "sd3.5-large",
        }
        files = {"none": ("", "", "application/octet-stream")}
        r = requests.post(
            STABILITY_URL,
            headers={"Authorization": f"Bearer {api_key}", "Accept": "image/*"},
            files=files,
            data=data,
            timeout=180,
        )
        if r.status_code == 200:
            out.write_bytes(r.content)
            _log(f"wrote {out} ({len(r.content)} bytes)")
            return True
        _log(f"stability text2img returned {r.status_code}: {r.text[:300]}")
    return False


def generate_icon(
    photo: pathlib.Path,
    prompt: str,
    out: pathlib.Path,
    requested: Optional[str] = None,
) -> bool:
    """Try Stability first (known-good, paid, reliable). Fall back to
    Gemini Nano Banana (free tier, sometimes better quality but API
    has been churning model names). `requested` forces a specific
    provider and skips the fallback chain.

    Order changed 2026-04-18: user issues #24/25/26 went 6+ hours
    without producing icons while Gemini kept failing silently. Flip
    to Stability-first so the happy path always produces output;
    Gemini is a bonus if available."""
    if requested == "stability":
        return call_stability_img2img(photo, prompt, out)
    if requested == "gemini":
        return call_gemini_img2img(photo, prompt, out)
    if os.environ.get("STABILITY_API_KEY"):
        if call_stability_img2img(photo, prompt, out):
            return True
        _log("stability failed — trying gemini as fallback")
    if os.environ.get("GEMINI_API_KEY"):
        if call_gemini_img2img(photo, prompt, out):
            return True
    _log("both generators failed OR neither API key is set")
    return False
