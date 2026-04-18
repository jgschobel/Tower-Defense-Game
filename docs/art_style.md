# Art Style Sheet — Affoltern Banani Raubzug

**Single source of truth** for AI image generation. Every prompt sent to
Gemini Nano Banana (img2img, friend icons) or Imagen 4 (text2img,
backgrounds/enemies/UI) prepends this style sheet so all assets stay
visually consistent.

## Universal Style Tokens

Always include in every prompt:

- **Style**: chibi cartoon, hand-painted look, thick black outline, bright
  saturated colors, slight depth via soft shading
- **Composition**: subject centered, 1:1 square (or 16:9 for backgrounds),
  full bleed
- **Background**: transparent for characters/enemies/props/UI;
  cinematic painterly for level backgrounds
- **Avoid**: photorealistic, realistic skin, text, watermarks, logos,
  blurry, multiple subjects, deformed hands

## Per-Character Style Pins

These keep characters recognizable across upgrade tiers and animation states.

### Lemurius (Tower id: `basic`)
- **Species**: ring-tailed lemur / human hybrid
- **Vibe**: cheeky, banana-throwing, alpine vibe
- **Signature**: fluffy striped tail, big round ears, chubby cheeks,
  always holding a banana
- **Colors**: warm cream + brown + soft yellow
- **Tier 3 (Explosivi Khaki)**: glowing red-orange aura, banana wreathed in flames

### Amösius (Tower id: `slow`)
- **Species**: tokay gecko / human hybrid
- **Vibe**: mischievous, sticky-tongued, lottery-loving
- **Signature**: bright green skin with electric blue spots, long pink
  tongue extended, smug grin
- **Colors**: emerald green + hot pink + cyan accents
- **Tier 3 (Insta-Reel Attacke)**: tongue glows magenta, eyes shine

### Kühne (Tower id: `sniper`)
- **Species**: flower-pixie human, nature mage
- **Vibe**: thoughtful, wildflower magic, gentle but deadly
- **Signature**: long wavy chestnut hair, flower crown of wild Alpine
  blossoms, vines woven into hair, magical wand or staff
- **Colors**: soft greens + violet + warm amber
- **Tier 3 paths**:
  - Füür-Lilie: red/orange fire-flower aura
  - Gletscher-Magier: ice-blue frost-flower aura

### JoJo (Tower id: `splash`)
- **Species**: human chaos chemist
- **Vibe**: vintage-nerd, mad scientist, lovable eccentric
- **Signature**: short curly brown hair, well-groomed handlebar moustache,
  yellow-tinted round wire glasses, white lab coat OVER colorful 90s shirt
- **Colors**: brown + bright chemical green/pink + yellow lens flash
- **Tier 3 (Lotter JoJo)**: rainbow chemical bubbles, glowing flask

### Cordula (Tower id: `cordula`)
- **Species**: human, carnival pirate
- **Vibe**: confident, playful, ready to throw
- **Signature**: brown hair in tight low ponytail, soft blue-grey eyes,
  black top with colorful sash, tricorn hat with feather, gold hoop earrings
- **Colors**: black + carnival rainbow accents + gold
- **Tier 3 (Party-Kanone)**: confetti cannon, gold sparkle aura

## Per-Enemy Style Pins (Vegan-Tüüfel's cursed products)

- **Tofu-Würschtli**: angry beige sausage with cartoon eyes/teeth, walking
- **Hafer-Riegel**: Toblerone-shaped chocolate bar, racing
- **Soja-Steak**: 3-meter cervelat sausage, armored/segmented, slow
- **Hafer-Milch (Dr.)**: white-and-green oat milk carton, magic healing aura
- **Avocado**: flying green pit-monster with wings
- **Vegan-Tüüfel**: dark dapper devil, Migros-orange horns, M-shaped trident,
  carries expired Cumulus-Punkte cards

## Level Backgrounds (16:9, painterly)

- **Level 1 — Migros Affoltern Eingang**: bright fluorescent supermarket
  entrance, sliding doors, shopping carts, Migros orange accent, midday
- **Level 2 — D'Tiefchüel-Abteilig**: frozen aisle, dripping icicles, vertical
  freezer doors, blue cold lighting, breath-fog
- **Level 3 — D'Bäckerei vom Gruse**: warm bakery, oven glow, flour drift,
  bread racks, amber lighting

## Negative Prompt Library

Always pass these as negatives to suppress common AI failures:

```
photorealistic, realistic skin, photograph, nsfw, nude, text, words,
watermark, logo, signature, multiple characters, extra limbs, deformed
hands, blurry, low quality, jpeg artifacts, oversaturated, neon colors
```

## How to update

When you add a new character/enemy/level, append a new pin section
above. Generators will pick it up on the next run automatically.
Keep entries TIGHT — too much detail confuses the model.
