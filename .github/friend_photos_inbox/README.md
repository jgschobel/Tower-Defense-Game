# Friend Photos Inbox

This directory is watched by `.github/workflows/photo-inbox.yml`.

## ⚠️ Hard rule: image-to-image only

Friend character icons must always be generated from a real photo via
Stability AI image-to-image. Text-only sidecars are **rejected** — the
processor will log a warning and skip them. Likeness matters too much
to let text-to-image guess faces.

## How it works

When a chat-session Claude receives a photo from the user, it commits
the photo here (as `<slug>.jpg` or `<slug>.png`) along with an
optional sidecar `<slug>.yml` holding metadata:

```yaml
name: "Baschi"
description: "Gmüetlich, Kaffi-Liebhaber, Brüle."
style: "scholar"   # one of: default, warrior, scholar, pirate, pixie, punk
```

On push to `main` with anything changed in this folder, the workflow:

1. Runs `.github/scripts/process_photo_inbox.py`
2. For each photo, calls Stability AI image-to-image with a chibi
   cartoon prompt tuned to the style
3. Saves the generated icon to
   `assets/textures/towers/friend_<slug>.png`
4. Deletes the inbox file
5. Opens a PR adding the new asset

## Manual use

If you want to trigger a batch yourself, drop any .jpg/.png in here and
run the workflow from the Actions tab (`workflow_dispatch`).
