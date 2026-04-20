#!/usr/bin/env python3
"""Generate AI audio via HuggingFace Inference API.

Reads resources/audio/requests.yaml, for each entry whose target_path
file is missing, calls the appropriate HF model (AudioGen for SFX,
MusicGen for music), saves the bytes as .ogg, and updates
resources/audio_config.tres so sfx_manager.gd + music_manager.gd
start using the baked clip on next game load.

Auth: requires HUGGINGFACE_API_KEY env var (GitHub secret in CI).
Free tier covers ~30k calls / month, more than enough for the whole
requests.yaml (~35 entries, one-shot bake).

Safe to re-run. Never overwrites existing files — delete first to
regenerate.
"""

from __future__ import annotations

import json
import os
import re
import sys
import time
from pathlib import Path
from typing import Any, Dict, List
from urllib.request import Request, urlopen
from urllib.error import HTTPError

ROOT = Path(__file__).resolve().parents[2]
REQUESTS_PATH = ROOT / "resources" / "audio" / "requests.yaml"
CONFIG_PATH = ROOT / "resources" / "audio_config.tres"

SFX_MODEL = "facebook/audiogen-medium"
MUSIC_MODEL = "facebook/musicgen-small"
HF_API_BASE = "https://api-inference.huggingface.co/models/"


def load_requests() -> Dict[str, List[Dict[str, Any]]]:
    # Tiny hand-parsed YAML — only the subset we use (top-level keys
    # "sfx" / "music" each holding a list of flat dicts). Keeps the
    # script dependency-free for the workflow.
    text = REQUESTS_PATH.read_text()
    out: Dict[str, List[Dict[str, Any]]] = {"sfx": [], "music": []}
    section = None
    current: Dict[str, Any] | None = None
    for raw_line in text.splitlines():
        line = raw_line.rstrip()
        if not line or line.lstrip().startswith("#"):
            continue
        if re.match(r"^[a-zA-Z_]+:\s*$", line):
            if current is not None and section is not None:
                out[section].append(current)
                current = None
            section = line.strip().rstrip(":")
            continue
        m = re.match(r"^\s*-\s*([a-zA-Z_]+):\s*(.+)$", line)
        if m:
            if current is not None and section is not None:
                out[section].append(current)
            current = {}
            key, val = m.group(1), m.group(2)
            current[key] = _coerce(val)
            continue
        m = re.match(r"^\s+([a-zA-Z_]+):\s*(.+)$", line)
        if m and current is not None:
            current[m.group(1)] = _coerce(m.group(2))
    if current is not None and section is not None:
        out[section].append(current)
    return out


def _coerce(val: str) -> Any:
    val = val.strip()
    if (val.startswith('"') and val.endswith('"')) or (val.startswith("'") and val.endswith("'")):
        return val[1:-1]
    try:
        if "." in val:
            return float(val)
        return int(val)
    except ValueError:
        return val


def call_hf(model: str, prompt: str, duration: float, token: str, attempt: int = 1) -> bytes | None:
    url = HF_API_BASE + model
    body = json.dumps({
        "inputs": prompt,
        "parameters": {"duration": duration},
    }).encode("utf-8")
    req = Request(url, data=body, method="POST", headers={
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json",
        "Accept": "audio/flac",
    })
    try:
        with urlopen(req, timeout=180) as resp:
            ct = resp.headers.get("Content-Type", "")
            data = resp.read()
            if ct.startswith("application/json"):
                # Model warming up — back off + retry
                payload = json.loads(data)
                if "estimated_time" in payload and attempt <= 4:
                    wait = float(payload["estimated_time"]) + 2.0
                    print(f"  model warming, waiting {wait:.0f}s ...", flush=True)
                    time.sleep(wait)
                    return call_hf(model, prompt, duration, token, attempt + 1)
                print(f"  ! unexpected JSON response: {payload}", flush=True)
                return None
            return data
    except HTTPError as exc:
        if exc.code == 503 and attempt <= 4:
            print(f"  503, retry {attempt}/4 after 10s", flush=True)
            time.sleep(10)
            return call_hf(model, prompt, duration, token, attempt + 1)
        print(f"  ! HTTP {exc.code}: {exc.read()[:200]}", flush=True)
        return None
    except Exception as exc:  # noqa: BLE001
        print(f"  ! request failed: {exc}", flush=True)
        return None


def bake(entry: Dict[str, Any], model: str, token: str) -> bool:
    sfx_id = entry["id"]
    target = ROOT / entry["target_path"]
    if target.exists():
        print(f"  = {target.relative_to(ROOT)} (already present)", flush=True)
        return True
    print(f"  ~ {sfx_id}: '{entry['prompt'][:60]}...'", flush=True)
    audio = call_hf(model, entry["prompt"], float(entry["duration"]), token)
    if audio is None:
        return False
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_bytes(audio)
    print(f"  + {target.relative_to(ROOT)} ({len(audio)} bytes)", flush=True)
    return True


def parse_existing_dict(text: str, key: str) -> Dict[str, str]:
    m = re.search(rf"{key}\s*=\s*\{{([^}}]*)\}}", text, re.DOTALL)
    if not m:
        return {}
    out: Dict[str, str] = {}
    for line in m.group(1).splitlines():
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


def write_config(sfx: Dict[str, str], music: Dict[str, str]) -> None:
    lines: List[str] = []
    existing = CONFIG_PATH.read_text().splitlines()
    for line in existing:
        lines.append(line)
        if line.strip() == "[resource]":
            break
    lines.append('script = ExtResource("1")')
    lines.append("sfx = {")
    for k in sorted(sfx):
        lines.append(f'\t"{k}": "{sfx[k]}",')
    lines.append("}")
    lines.append("music = {")
    for k in sorted(music):
        lines.append(f'\t"{k}": "{music[k]}",')
    lines.append("}")
    CONFIG_PATH.write_text("\n".join(lines) + "\n")
    print(f"  wrote {CONFIG_PATH.relative_to(ROOT)}: {len(sfx)} sfx, {len(music)} music")


def main() -> int:
    token = os.environ.get("HUGGINGFACE_API_KEY", "").strip()
    if not token:
        print("HUGGINGFACE_API_KEY not set — skipping AI generation.", flush=True)
        return 0
    requests = load_requests()
    sfx_entries = parse_existing_dict(CONFIG_PATH.read_text(), "sfx")
    music_entries = parse_existing_dict(CONFIG_PATH.read_text(), "music")

    for entry in requests.get("sfx", []):
        if bake(entry, SFX_MODEL, token):
            sfx_entries[entry["id"]] = "res://" + entry["target_path"]
    for entry in requests.get("music", []):
        if bake(entry, MUSIC_MODEL, token):
            music_entries[entry["id"]] = "res://" + entry["target_path"]

    write_config(sfx_entries, music_entries)
    return 0


if __name__ == "__main__":
    sys.exit(main())
