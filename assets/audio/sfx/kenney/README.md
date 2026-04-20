# Kenney CC0 Audio

Files in this directory are sourced from [kenney.nl](https://kenney.nl)
audio packs released under [CC0 1.0 Universal (Public Domain)](https://creativecommons.org/publicdomain/zero/1.0/).

No attribution is legally required under CC0, but Kenney's work
deserves recognition. If you fork this repo, please consider donating
or leaving a tip at [kenney.itch.io](https://kenney.itch.io).

## Packs used

- **UI Audio** — https://kenney.nl/assets/ui-audio
- **Impact Sounds** — https://kenney.nl/assets/impact-sounds

## How new clips get here

Managed by `scripts/audio_tools/fetch_kenney.py` and the
`audio-fetch.yml` workflow. Edit the `KENNEY_PACKS` dict in the
script to wire a new id → clip mapping, push to main, the workflow
downloads + commits automatically.
