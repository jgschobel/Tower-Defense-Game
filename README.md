# Affoltern Banani Raubzug

A mobile tower defense game built in Godot 4.6 set in Migros Affoltern, Zürich. All text in Swiss German (Züridütsch).

## The Story
Lemurius (lemur, throws bananas), Amösius (gecko, stuns with tongue), Kühne (flower girl, pollen attacks), JoJo (mad chemist, splash chemicals), and Cordula (pirate carnival girl, volleyballs) fight cursed vegan supermarket products controlled by De Vegan-Tüüfel.

## Features
- **5 playable tower characters** with unique attacks and upgrade paths
- **6 enemy types**: Tofu-Würschtli, Hafer-Riegel, Soja-Steak, Dr. Hafer-Milch, Fliegendi Avocado, De Vegan-Tüüfel
- **3 themed levels** (Migros aisle, frozen section, bakery) with unique paths and AI-generated backgrounds
- **10 waves per level** with escalating difficulty
- **Landscape orientation** (1280x720) optimized for handheld play
- **Story cutscenes** with typewriter text and character portraits in Swiss German
- **Procedural chiptune music** and sound effects (no audio files needed)
- **Tower animations**: attack bounce, upgrade celebration, sell shrink, selected glow
- **Enemy animations**: damage numbers, gold floats, death spin, slow tint, hit reactions
- **Wave announcements** with late-wave warnings
- **Auto-wave mode** and speed toggle (1x/2x/3x)
- **Save/load** with star ratings (1-3 stars per level)

## Development
- Built with AI-assisted workflow: Opus (architecture/code) + Sonnet sub-agents (art, validation)
- Art generated via Stability AI API (~877 credits remaining)
- Backgrounds removed with rembg (isnet-general-use model)
- See `AGENTS.md` for multi-agent architecture
- See `PLAN.md` for the 80-point development roadmap
- See `CLAUDE.md` for coding conventions

## Characters
| Tower | Cost | Attack | Special |
|-------|------|--------|---------|
| Lemurius | 80 | Banane | All-rounder, spinning projectile |
| Kühne | 200 | Blütestaub | Long range, targets strongest |
| JoJo | 175 | Chemikalie | Splash AoE damage |
| Cordula | 150 | Volleyball | Fast, good range |
| Amösius | 120 | Pink Zunge | 50% slow for 2.5s, stun reactions |

## Quick Start
1. Open in Godot 4.6+
2. Run the project (F5)
3. "RAUBZUG STARTE" → pick a level → "LOS GAHT'S!" → place towers → send waves
