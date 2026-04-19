# Voice Cloning — Friend Voices as Tower Taunts

Plan: each friend's real voice voices their tower's taunts, upgrade
confirmations, and death lines. Uses **Coqui XTTS-v2** (open-source,
runs locally, no external service stores the clones).

Deferred — set up but not yet populated with reference recordings. Pick
up when friends send voice samples.

## Setup (already done on dev machine)

Location: `C:\voice_clone\` (outside repo — model cache + venv are large).

```
C:\voice_clone\
├── env\                     # Python 3.9 venv with coqui-tts + torch
├── clone.py                 # Single-line wrapper
├── batch_clone.py           # Batch from JSON config
├── config.example.json      # Template with 8 friends + sample taunts
├── refs\                    # Drop friend_voice.wav files here
└── out\                     # Generated WAVs land here (char_id/NN_text.wav)
```

Install command used (for reproducibility):
```bash
py -m venv C:/voice_clone/env
/c/voice_clone/env/Scripts/python.exe -m pip install --upgrade pip
/c/voice_clone/env/Scripts/python.exe -m pip install coqui-tts
```

First synthesis downloads the ~2GB XTTS-v2 model into
`C:\Users\<user>\AppData\Local\tts\`.

## Reference audio requirements

- **Length**: 6–30 seconds
- **Content**: natural speech, not singing, not shouting
- **Quality**: clean — no background music, ideally no room echo
- **Format**: WAV preferred (MP3/FLAC also accepted)
- **Language**: German recommended (Swiss German works; XTTS-v2 uses `de`
  — Züridütsch accent carries through reasonably but isn't native)

## Single-line test

```bash
/c/voice_clone/env/Scripts/python.exe /c/voice_clone/clone.py \
  --ref /c/voice_clone/refs/lemurius.wav \
  --text "Banane inbound!" \
  --out /c/voice_clone/out/test.wav \
  --lang de
```

## Batch generation

1. Copy `config.example.json` → `config.json`
2. Edit the `lines` arrays per character
3. Place reference WAVs at the `ref` paths
4. Run:

```bash
/c/voice_clone/env/Scripts/python.exe /c/voice_clone/batch_clone.py \
  --config /c/voice_clone/config.json --lang de
```

Output goes to `C:/voice_clone/out/<char_id>/NN_slug.wav`. CPU inference
takes ~20–40s per short line.

## Legal / ethical notes

- XTTS-v2 license is **CPML (Coqui Public Model License)** —
  non-commercial / research / personal. Fine for this hobby project.
- **Consent**: get each friend's explicit OK before cloning. Best practice:
  record a short consent statement alongside the reference audio
  ("[Name] gibt Bewilligung, dass mini Stimm für das Tower Defense Spiel
  gclont wird"). Keep that WAV next to the reference.
- No data leaves the machine — XTTS runs fully local.

## Godot integration (TODO when voices land)

1. Drop generated WAVs under `res://assets/audio/voice/<char_id>/`
2. Extend `sfx_manager.gd` with `play_voice(character_id: String, line_id: String)`
3. Replace existing `_float_taunt` text-only taunts in `base_tower.gd`
   with a call that plays the voice clip + shows the subtitle text
4. Respect `GameManager.sfx_volume` (voice lines pipe through same bus)

## Files in this repo related to voices

- `docs/voice_cloning.md` (this file) — setup + usage reference
- `scripts/towers/base_tower.gd` — has `TAUNTS` dict + `_float_taunt()`
  which is where voice playback will hook in
- `scripts/systems/sfx_manager.gd` — extend with `play_voice()`

## When to re-open this doc

- When any friend sends their first reference WAV
- When picking up the "Voice lines" roadmap item
- If Coqui/XTTS licensing changes or the maintained `coqui-tts` fork
  gets superseded
