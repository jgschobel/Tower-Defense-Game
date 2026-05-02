#!/usr/bin/env python3
"""
Generate damage-state art variants for enemy characters via Gemini img2img
anchored to the enemy's clean base texture. Replaces simple red-tint
placeholders with real per-enemy thematic injury art.

Output path (mirrors dev_menu's variant lookup):
    res://assets/textures/variants/enemies/{enemy_id}/{enemy_id}_state{N}_{name}.png

States generated (state 0 = healthy = the clean base, no generation needed):
    1 = hurt    (>33% and <66% HP) — light damage
    2 = injured (>10% and <33% HP) — moderate wounds
    3 = dying   (<10% HP)          — critical / dramatic

Each enemy has a unique thematic injury style — NOT all the same generic
"add bandages" prompt. Crumbling bread, split sausage, shattering bottle, etc.

Inputs (env):
    ENEMY_ID        e.g. "basic", "cervelat" (or "all" to run all)
    GEMINI_API_KEY  required (primary provider)
    STABILITY_API_KEY  optional fallback
"""
from __future__ import annotations

import os
import pathlib
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from generators import call_gemini_img2img, call_stability_img2img  # noqa: E402


# enemy_id → path to clean base PNG (relative to repo root)
ENEMY_BASES: dict[str, str] = {
    "basic":    "assets/textures/enemies/brotli_clean.png",
    "fast":     "assets/textures/enemies/toblerone_clean.png",
    "tank":     "assets/textures/enemies/cervelat_clean.png",
    "healer":   "assets/textures/enemies/rivella_clean.png",
    "flying":   "assets/textures/enemies/fondue_clean.png",
    "boss":     "assets/textures/enemies/mteufel_clean.png",
}

# Per-enemy chibi style base (prepended to every prompt)
ENEMY_BASE_PERSONA: dict[str, str] = {
    "basic": (
        "cute chibi cartoon bread roll character (Wüetende Tofu-Würschtli), "
        "Pixar-style, 1:1 square, transparent background, centered"
    ),
    "fast": (
        "cute chibi cartoon Toblerone chocolate bar character (Turbo Hafer-Riegel), "
        "Pixar-style, 1:1 square, transparent background, centered"
    ),
    "tank": (
        "cute chibi cartoon Swiss sausage (Cervelat) character, tough and armored, "
        "Pixar-style, 1:1 square, transparent background, centered"
    ),
    "healer": (
        "cute chibi cartoon Rivella drink bottle character with a friendly nurse aura, "
        "Pixar-style, 1:1 square, transparent background, centered"
    ),
    "flying": (
        "cute chibi cartoon fondue pot character with stubby wings, "
        "Pixar-style, 1:1 square, transparent background, centered"
    ),
    "boss": (
        "cute chibi cartoon vegan devil (M-Tüüfel) with horns and torn cape, "
        "Pixar-style, 1:1 square, transparent background, centered"
    ),
}

# Per-enemy damage state prompts — creative, thematic, NOT all the same
DAMAGE_PROMPTS: dict[str, dict[str, str]] = {
    "basic": {
        "hurt":    "light hurt state: a small bite taken out of the top, crumbs scattered around feet, slightly surprised expression, warm bread interior visible at the bite",
        "injured": "injured state: big chunk bitten off the side, jam or cream filling oozing out, squashed a little flat, crumbs everywhere, worried expression, small bandage sticker on the bite",
        "dying":   "critical dying state: barely a quarter of the bread roll remains, burnt blackened crust edges, crumbling in real time with crumb particles flying off, desperate wide eyes, the remaining bit trembling",
    },
    "fast": {
        "hurt":    "light hurt state: wrapper slightly torn at corner, one chocolate triangle chipped off, a smear of melted chocolate on the edge, still smirking but nervous",
        "injured": "injured state: half the wrapper ripped off and melting, multiple triangles broken, liquid chocolate dripping down sides, melting expression, one eye squinting in pain",
        "dying":   "critical dying state: nearly fully melted into a glossy puddle, wrapper in shreds, desperately holding its face shape above a molten chocolate base, horrified eyes, last few solid pieces crumbling",
    },
    "tank": {
        "hurt":    "light hurt state: a small split seam on one side with sausage skin curling outward, tiny grease bead forming, still stoic but flinching",
        "injured": "injured state: big X-shaped crack split across the belly with filling oozing out in two streams, skin peeling back, grimacing hard, internal stuffing visible and steaming",
        "dying":   "critical dying state: completely burst open from both ends, filling erupting outward like a disaster, skin hanging off in strips, held together by sheer stubbornness, smoke rising from the cracks",
    },
    "healer": {
        "hurt":    "light hurt state: small dent in the bottle, label edge peeling up, a thin trickle of liquid running down from a hairline crack, still smiling but visibly stressed",
        "injured": "injured state: bottle cracked in two places with liquid spraying sideways, label torn and hanging, the cap askew and leaking, desperate expression, liquid forming a puddle at base",
        "dying":   "critical dying state: bottle shattering — held together only by surface tension and willpower, glass cracks radiating everywhere, liquid erupting outward in a spray, eyes wide in panic, barely intact",
    },
    "flying": {
        "hurt":    "light hurt state: cheese has cooled and hardened along the rim, a small crack in the ceramic pot, stubby wings drooping a little, slightly cold expression",
        "injured": "injured state: pot cracked across the side with cheese erupting like a mini-volcano, steam billowing, one wing singed and bent, grimacing, cheese dripping off the edges in long strings",
        "dying":   "critical dying state: pot tipped at a 45-degree angle, half the fondue spilled and solidifying in a lava flow, one wing completely gone, pot rim shattered, one desperate eye looking up from the wreckage",
    },
    "boss": {
        "hurt":    "light hurt state: a crack running up one horn, small tear in the cape, eye twitching with barely-contained rage, knuckles clenched",
        "injured": "injured state: both horns chipped and cracked, face marked with glowing wounds, wings damaged with holes, cape tattered, radiating dark energy but visibly weakened, snarling through gritted teeth",
        "dying":   "critical dying state: full demonic desperation — horns shattered to stumps, face split with magical wounds glowing red, wings disintegrating, dark energy explosions all around, screaming in fury and fear, last-stand aura",
    },
}

STATE_NAMES = ["hurt", "injured", "dying"]
STATE_NUMBERS = [1, 2, 3]


def log(msg: str) -> None:
    print(f"[enemy_damage_variants] {msg}", flush=True)


def generate_for_enemy(enemy_id: str) -> list[str]:
    base_path_str = ENEMY_BASES.get(enemy_id)
    if not base_path_str:
        log(f"no base texture registered for '{enemy_id}' — skipping")
        return []

    base_photo = pathlib.Path(base_path_str)
    if not base_photo.exists():
        log(f"base texture not found: {base_photo} — skipping {enemy_id}")
        return []

    persona = ENEMY_BASE_PERSONA.get(enemy_id, "cute chibi cartoon character, Pixar-style, 1:1 square, transparent background")
    state_prompts = DAMAGE_PROMPTS.get(enemy_id, {})

    out_dir = pathlib.Path(f"assets/textures/variants/enemies/{enemy_id}")
    out_dir.mkdir(parents=True, exist_ok=True)

    written: list[str] = []
    for state_num, state_name in zip(STATE_NUMBERS, STATE_NAMES):
        state_prompt = state_prompts.get(state_name)
        if not state_prompt:
            log(f"no prompt for {enemy_id}/{state_name} — skipping")
            continue

        out_path = out_dir / f"{enemy_id}_state{state_num}_{state_name}.png"
        full_prompt = f"{persona}. Damage state: {state_prompt}"

        log(f"=== {enemy_id} state{state_num}_{state_name} ===")
        log(f"prompt: {full_prompt[:140]}...")

        if call_gemini_img2img(base_photo, full_prompt, out_path):
            written.append(str(out_path))
            log(f"wrote {out_path}")
        elif call_stability_img2img(base_photo, full_prompt, out_path):
            written.append(str(out_path))
            log(f"wrote {out_path} (stability fallback)")
        else:
            log(f"both providers failed for {out_path} — skipping")

    return written


def main() -> int:
    target = os.environ.get("ENEMY_ID", "").strip().lower()

    if target == "all" or target == "":
        enemies_to_run = list(ENEMY_BASES.keys())
    elif target in ENEMY_BASES:
        enemies_to_run = [target]
    else:
        log(f"unknown ENEMY_ID '{target}'. Known: {sorted(ENEMY_BASES)}")
        return 1

    all_written: list[str] = []
    for enemy_id in enemies_to_run:
        written = generate_for_enemy(enemy_id)
        all_written.extend(written)

    if not all_written:
        log("nothing generated — both providers failed for all enemies/states")
        return 1

    out_file = os.environ.get("GITHUB_OUTPUT")
    if out_file:
        with open(out_file, "a") as f:
            f.write(f"asset_paths={','.join(all_written)}\n")
            f.write(f"count={len(all_written)}\n")
            f.write(f"enemy_ids={','.join(enemies_to_run)}\n")

    log(f"total: {len(all_written)} variant(s) written: {all_written}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
