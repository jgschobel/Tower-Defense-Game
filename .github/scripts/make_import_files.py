#!/usr/bin/env python3
"""
Generate Godot 4.6 .import files for every PNG in assets/textures/ that's
missing one. Without .import files, Godot's web export skips the PNG and
the asset is invisible in the deployed build — root cause of the empty
Variante tab in the dev menu.

Idempotent: skips PNGs that already have a .import sibling.

Usage: python3 .github/scripts/make_import_files.py [path...]
       (default: assets/textures)
"""
from __future__ import annotations
import hashlib
import pathlib
import string
import sys

REPO = pathlib.Path(__file__).resolve().parents[2]


def make_uid(file_path: str) -> str:
    """Generate a deterministic 13-char base32 UID from the file path.
    Format matches Godot's `uid://` (lowercase a-z + digits, 13 chars)."""
    h = hashlib.md5(file_path.encode("utf-8")).digest()
    # Godot uses base32 alphabet: a-z (no numbers? actually a-z+2-7 from RFC4648 lower)
    alphabet = string.ascii_lowercase + "234567"  # 32 chars
    n = int.from_bytes(h[:8], "big")
    out = []
    for _ in range(13):
        out.append(alphabet[n & 0x1F])
        n >>= 5
    return "".join(out)


def make_hash(file_path: str) -> str:
    """32-char hex (MD5) used in .ctex destination filename."""
    return hashlib.md5(file_path.encode("utf-8")).hexdigest()


IMPORT_TEMPLATE = '''[remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://{uid}"
path="res://.godot/imported/{filename}-{hash}.ctex"
metadata={{
"vram_texture": false
}}

[deps]

source_file="res://{src}"
dest_files=["res://.godot/imported/{filename}-{hash}.ctex"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
'''


def generate_import_for(png_path: pathlib.Path, repo: pathlib.Path) -> bool:
    """Write a .import file next to the PNG. Returns True if written, False if skipped."""
    import_path = png_path.with_suffix(png_path.suffix + ".import")
    if import_path.exists():
        return False
    src = str(png_path.relative_to(repo)).replace("\\", "/")
    filename = png_path.name
    content = IMPORT_TEMPLATE.format(
        uid=make_uid(src),
        filename=filename,
        hash=make_hash(src),
        src=src,
    )
    import_path.write_text(content)
    return True


def main(argv: list[str]) -> int:
    targets = [pathlib.Path(p) for p in argv[1:]] if len(argv) > 1 else [REPO / "assets/textures"]
    written = 0
    skipped = 0
    for target in targets:
        if not target.exists():
            print(f"[skip] {target} does not exist", file=sys.stderr)
            continue
        for png in sorted(target.rglob("*.png")):
            if generate_import_for(png, REPO):
                written += 1
            else:
                skipped += 1
    print(f"Wrote {written} .import files. Skipped {skipped} (already had one).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main(sys.argv))
