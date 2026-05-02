#!/usr/bin/env python3
# v2 — push to this file auto-triggers the mass-art workflow on feature branches.
"""
Mass art variant generator — creates 12 portrait styles per tower and
8 alt design variants per enemy. All outputs land in:
    assets/textures/variants/towers/{tower_id}/{style_name}.png
    assets/textures/variants/enemies/{enemy_id}/design_{style_name}.png

Tower variants: ALL use img2img from the existing photo — face likeness
is preserved across every style. Never text-to-image for friend chars.

Enemy variants: img2img from the clean base sprite — keeps the
food character recognizable but in a different mood/power level.

Inputs (env):
    TARGET      "all" | "towers" | "enemies" | specific id like "cordula"
    GEMINI_API_KEY
    STABILITY_API_KEY  (optional fallback)
"""
from __future__ import annotations

import os
import pathlib
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from generators import call_gemini_img2img, call_stability_img2img  # noqa: E402


# ─── Tower configuration ────────────────────────────────────────────────────
# tower_id (matches dev_menu TOWER_IDS) → photo path + persona
TOWERS: dict[str, dict] = {
    "basic": {
        "photo": "assets/textures/towers/lemurius_photo.jpg",
        "persona": (
            "the man in this photo as a chibi cartoon tower defense character "
            "called Lemurius. Cute Pixar-style, 1:1 square, transparent/white "
            "background, centered. Same face, hair, and smile as the photo."
        ),
        "name": "Lemurius",
    },
    "sniper": {
        "photo": "assets/textures/towers/kuhne_photo.jpg",
        "persona": (
            "the woman in this photo as a chibi cartoon sniper tower defense "
            "character called Kühne. Cute Pixar-style, 1:1 square, transparent/white "
            "background, centered. Same hair, eyes, and soft smile as the photo."
        ),
        "name": "Kühne",
    },
    "splash": {
        "photo": "assets/textures/towers/jojo_photo.jpg",
        "persona": (
            "the person in this photo as a chibi cartoon splash-attack tower "
            "defense character called JoJo. Cute Pixar-style, 1:1 square, "
            "transparent/white background, centered. Same face and energy as the photo."
        ),
        "name": "JoJo",
    },
    "cordula": {
        "photo": "assets/textures/towers/cordula_photo.jpg",
        "persona": (
            "the woman in this photo as a chibi cartoon volleyball-spike tower "
            "defense character called Cordula. Cute Pixar-style, 1:1 square, "
            "transparent/white background, centered. Same hair, eyes, and confident "
            "smile as the photo."
        ),
        "name": "Cordula",
    },
    "slow": {
        "photo": "assets/textures/towers/amosius_photo.png",
        "persona": (
            "the man in this photo as a chibi cartoon slow/support tower defense "
            "character called Amösius. Cute Pixar-style, 1:1 square, transparent/white "
            "background, centered. Same face and gentle expression as the photo."
        ),
        "name": "Amösius",
    },
}

# 10 style variants for every tower — each a different artistic treatment.
# The persona ensures face likeness; the style suffix defines the visual mood.
TOWER_STYLES: list[dict] = [
    {
        "id": "chibi_classic",
        "prompt": "Classic chibi style: cute oversized head, tiny body, expressive eyes, bright saturated colors, playful confident pose, soft cell shading.",
    },
    {
        "id": "anime_heroine",
        "prompt": "Shojo anime portrait: large sparkling expressive eyes, soft gradient shading, pastel pinks and lavenders, elegant hair detail, warm gentle lighting.",
    },
    {
        "id": "dark_hero",
        "prompt": "Dark hero portrait: intense dramatic expression, deeper shadows, cool desaturated palette with vivid accent color, battle-hardened look, slightly edgy.",
    },
    {
        "id": "pastel_kawaii",
        "prompt": "Hyper-kawaii pastel: extra large round head, tiny features, candy-soft pinks blues and mints, rosy cheeks, sparkles, fluffy accessories, maximum cuteness.",
    },
    {
        "id": "comic_pop",
        "prompt": "Pop-art comic book style: bold thick black outlines, flat halftone dot shading, primary colors red yellow blue, speech-bubble energy, retro graphic flair.",
    },
    {
        "id": "watercolor",
        "prompt": "Watercolor illustration: loose wet-on-wet brushwork, soft color bleeds, visible paper texture, delicate linework, warm artistic feeling, impressionistic edges.",
    },
    {
        "id": "neon_cyber",
        "prompt": "Cyberpunk neon: electric neon glow outlines in cyan and magenta, dark atmospheric background hints, glowing eyes, futuristic energy, sleek and electric.",
    },
    {
        "id": "fantasy_hero",
        "prompt": "Epic fantasy portrait: light armor or magical robe accessories, glowing power aura, dramatic hero lighting, warm golden accents, legendary adventurer feel.",
    },
    {
        "id": "chibi_summer",
        "prompt": "Summer holiday chibi: casual beach or outdoor outfit, sunhat or sunglasses, bright tropical palette, sunny warm lighting, relaxed happy energy, vacation vibe.",
    },
    {
        "id": "chibi_winter",
        "prompt": "Winter cozy chibi: fluffy scarf and beanie accessories, rosy cold-flushed cheeks, snow-white and ice-blue palette, warm glowing lantern or mug, snuggly festive feel.",
    },
    {
        "id": "retro_rpg",
        "prompt": "Retro RPG sprite-portrait: 90s JRPG character card style, clean digital shading, bold outlines, limited warm palette, game menu portrait framing.",
    },
    {
        "id": "sticker_bold",
        "prompt": "Bold sticker design: thick white drop-shadow outline, vivid saturated colors, simplified chunky shapes, high contrast, feels like a premium collectible sticker.",
    },
]

# ─── Enemy configuration ────────────────────────────────────────────────────
ENEMIES: dict[str, dict] = {
    "basic": {
        "base": "assets/textures/enemies/brotli_clean.png",
        "persona": "cute chibi cartoon angry bread roll character (Brötli), Pixar-style, 1:1 square, transparent background, centered",
    },
    "fast": {
        "base": "assets/textures/enemies/toblerone_clean.png",
        "persona": "cute chibi cartoon speedy Toblerone chocolate bar character, Pixar-style, 1:1 square, transparent background, centered",
    },
    "tank": {
        "base": "assets/textures/enemies/cervelat_clean.png",
        "persona": "cute chibi cartoon armored Swiss sausage (Cervelat) character, Pixar-style, 1:1 square, transparent background, centered",
    },
    "healer": {
        "base": "assets/textures/enemies/rivella_clean.png",
        "persona": "cute chibi cartoon Rivella drink bottle healer character, Pixar-style, 1:1 square, transparent background, centered",
    },
    "flying": {
        "base": "assets/textures/enemies/fondue_clean.png",
        "persona": "cute chibi cartoon fondue pot character with stubby wings for flying, Pixar-style, 1:1 square, transparent background, centered",
    },
    "boss": {
        "base": "assets/textures/enemies/mteufel_clean.png",
        "persona": "cute chibi cartoon vegan devil boss (M-Tüüfel) with horns and cape, Pixar-style, 1:1 square, transparent background, centered",
    },
}

# 5 alternative design variants per enemy — same character, different feel.
ENEMY_DESIGNS: list[dict] = [
    {
        "id": "design_enraged",
        "prompt": "Same character but visibly ENRAGED: furious furrowed brows, steam from ears, angry veins on forehead, clenched fists, fiery red aura, menacing energy.",
    },
    {
        "id": "design_elite",
        "prompt": "Elite golden version: same character but gold-chrome plated, shiny metallic surfaces, glowing amber eyes, polished regal energy, clearly a stronger version.",
    },
    {
        "id": "design_shadow",
        "prompt": "Shadow cursed version: same character but wrapped in dark purple-black aura, glowing violet eyes, shadow tendrils, mysterious evil energy, cool villain aesthetic.",
    },
    {
        "id": "design_corrupted",
        "prompt": "Corrupted mutant version: same character but visibly warped — extra limbs, glowing cracks, chaotic spikes or blobs, alien/demonic feel, still recognizable but wrong.",
    },
    {
        "id": "design_cute",
        "prompt": "Extra-cute innocent version: same character but maximum kawaii — huge round eyes, tiny blush marks, soft pastel tones, looks harmless and adorable (deceptively!)",
    },
    {
        "id": "design_chrome",
        "prompt": "Chrome metallic robot version: same character shape but rendered in brushed chrome silver, mechanical joints visible, LED strip eyes, sci-fi robot aesthetic.",
    },
    {
        "id": "design_fire",
        "prompt": "Fire-infused version: same character engulfed in cartoon flames, red-orange-yellow fire halo, glowing ember eyes, heat distortion shimmer, fiery aggressive energy.",
    },
    {
        "id": "design_ice",
        "prompt": "Frozen ice version: same character encased in glittering ice crystals, frosty blue-white palette, icicle spikes, cold mist breath, chilling calm demeanor.",
    },
]


def log(msg: str) -> None:
    print(f"[mass_variants] {msg}", flush=True)


def safe_generate(photo_path: pathlib.Path, prompt: str, out_path: pathlib.Path) -> bool:
    """Try Gemini then Stability. Tiny backoff between attempts."""
    if call_gemini_img2img(photo_path, prompt, out_path):
        return True
    time.sleep(3)
    if call_stability_img2img(photo_path, prompt, out_path):
        return True
    return False


def generate_tower_variants(tower_ids: list[str]) -> list[str]:
    written: list[str] = []
    for tid in tower_ids:
        cfg = TOWERS.get(tid)
        if not cfg:
            log(f"unknown tower id '{tid}' — skipping")
            continue
        photo = pathlib.Path(cfg["photo"])
        if not photo.exists():
            log(f"photo not found: {photo} — skipping {tid}")
            continue
        out_dir = pathlib.Path(f"assets/textures/variants/towers/{tid}")
        out_dir.mkdir(parents=True, exist_ok=True)
        log(f"=== TOWER: {cfg['name']} ({len(TOWER_STYLES)} styles) ===")
        for style in TOWER_STYLES:
            out_path = out_dir / f"{style['id']}.png"
            if out_path.exists():
                log(f"  {style['id']}: exists — skipping")
                written.append(str(out_path))
                continue
            full_prompt = f"{cfg['persona']} Style: {style['prompt']}"
            log(f"  {style['id']}: generating...")
            if safe_generate(photo, full_prompt, out_path):
                written.append(str(out_path))
                log(f"  {style['id']}: OK")
            else:
                log(f"  {style['id']}: FAILED — both providers gave up")
            time.sleep(2)  # courtesy pause between API calls
    return written


def generate_enemy_variants(enemy_ids: list[str]) -> list[str]:
    written: list[str] = []
    for eid in enemy_ids:
        cfg = ENEMIES.get(eid)
        if not cfg:
            log(f"unknown enemy id '{eid}' — skipping")
            continue
        base_img = pathlib.Path(cfg["base"])
        if not base_img.exists():
            log(f"base sprite not found: {base_img} — skipping {eid}")
            continue
        out_dir = pathlib.Path(f"assets/textures/variants/enemies/{eid}")
        out_dir.mkdir(parents=True, exist_ok=True)
        log(f"=== ENEMY: {eid} ({len(ENEMY_DESIGNS)} designs) ===")
        for design in ENEMY_DESIGNS:
            out_path = out_dir / f"{design['id']}.png"
            if out_path.exists():
                log(f"  {design['id']}: exists — skipping")
                written.append(str(out_path))
                continue
            full_prompt = f"{cfg['persona']}. Alt design: {design['prompt']}"
            log(f"  {design['id']}: generating...")
            if safe_generate(base_img, full_prompt, out_path):
                written.append(str(out_path))
                log(f"  {design['id']}: OK")
            else:
                log(f"  {design['id']}: FAILED")
            time.sleep(2)
    return written


def main() -> int:
    target = os.environ.get("TARGET", "all").strip().lower()

    if target in ("all", "towers"):
        tower_ids = list(TOWERS.keys())
    elif target.startswith("tower_"):
        tower_ids = [target[len("tower_"):]]
    elif target in TOWERS:
        tower_ids = [target]
    else:
        tower_ids = []

    if target in ("all", "enemies"):
        enemy_ids = list(ENEMIES.keys())
    elif target.startswith("enemy_"):
        enemy_ids = [target[len("enemy_"):]]
    elif target in ENEMIES:
        enemy_ids = [target]
    else:
        enemy_ids = []

    all_written: list[str] = []

    if tower_ids:
        all_written.extend(generate_tower_variants(tower_ids))

    if enemy_ids:
        all_written.extend(generate_enemy_variants(enemy_ids))

    if not all_written:
        log("nothing generated")
        return 1

    out_file = os.environ.get("GITHUB_OUTPUT")
    if out_file:
        with open(out_file, "a") as f:
            f.write(f"asset_paths={','.join(all_written)}\n")
            f.write(f"count={len(all_written)}\n")
            f.write(f"target={target}\n")

    log(f"done — {len(all_written)} file(s): {all_written[:8]}{'...' if len(all_written) > 8 else ''}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
