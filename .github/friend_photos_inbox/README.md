# Friend Photos Inbox — the ONLY reliable way to add friend icons

**If you want a friend icon, use this folder.** The issue-template flow
(`friend-photo`) is unreliable — GitHub's user-attachment URLs return
404 to workflow clients even with auth, so the trigger-file pipeline
can't download the photo bytes.

## 📱 Upload from your phone (30 sec)

1. Open this repo in GitHub mobile web:
   https://github.com/jgschobel/Tower-Defense-Game/tree/main/.github/friend_photos_inbox
2. Tap **"Add file"** → **"Upload files"**
3. Select the photo from your camera roll. Name it like `cordula.jpg`
   (lowercase slug, matches the intended friend character ID).
4. Commit message: leave default. Commit directly to `main`.
5. The `photo-inbox.yml` workflow fires automatically, generates the
   chibi icon via Stability img2img, opens a PR, and the autonomous
   loop auto-merges it. Icon appears at
   `assets/textures/towers/friend_<slug>.png` within ~3 minutes.

## ⚠️ Hard rule: image-to-image only

Friend character icons must always be generated from a real photo via
Stability AI image-to-image. Text-only sidecars are **rejected**.
Likeness matters too much to let text-to-image guess faces.

## Optional sidecar metadata

Upload a `<slug>.yml` alongside the photo to set extra metadata:

```yaml
name: "Baschi"
description: "Gmüetlich, Kaffi-Liebhaber, Brüle."
style: "scholar"   # default, warrior, scholar, pirate, pixie, punk
```

## How it works

On push to `main` touching this folder, the workflow:

1. Runs `.github/scripts/process_photo_inbox.py`
2. For each photo, calls Stability AI img2img with a chibi cartoon
   prompt tuned to the style
3. Saves the generated icon to
   `assets/textures/towers/friend_<slug>.png`
4. Deletes the inbox file
5. Opens a PR adding the new asset (auto-merged by the loop)

## Why the issue-template path fails

GitHub user-attachment URLs (`github.com/user-attachments/assets/<uuid>`)
require the viewer's browser session cookies to redirect to the signed
CDN URL. The GITHUB_TOKEN that workflows get doesn't carry that scope,
so the redirect returns 404 and we never get the photo bytes. This is
a GitHub-side auth quirk — not fixable from the repo.
