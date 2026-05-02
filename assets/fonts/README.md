# Fonts

`NotoEmoji.ttf` is downloaded at build time by `.github/workflows/deploy-web.yml`
(and other CI workflows that run Godot import). It's not committed to the repo
because it's a binary asset that updates upstream and we always want the latest.

The font is referenced by `assets/fonts/main_theme.tres` as a fallback for the
default Godot font, so emoji glyphs (★ ✨ 🔒 🪙 etc) render properly in the web
build instead of as missing-glyph "tofu" boxes.

## Local dev
If running the project in Godot Editor locally, run:

```bash
curl -fsSL -o assets/fonts/NotoEmoji.ttf \
  "https://github.com/googlefonts/noto-emoji/raw/main/fonts/NotoEmoji-Regular.ttf"
```

(Or just push to a branch and let the autonomous loop validate it — the font
will be present during CI.)
