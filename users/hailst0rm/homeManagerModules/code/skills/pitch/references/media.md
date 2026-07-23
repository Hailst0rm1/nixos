# Adaptive media

There is no fixed media stack — use what is present in this environment and **degrade gracefully**. Log which path you took and why in `build-log.md`.

## Capability check

Detect what is available before generating:

- **Images** — Codex `image_gen` via `/imagegen` (ChatGPT sub, usually present); Higgsfield CLI (`higgs`/`hf`) if the `higgsfield` option is enabled (interactive auth — run `higgsfield auth login` once).
- **Video** — Higgsfield CLI if enabled; NotebookLM (`notebooklm` skill) for audio+visual overviews.
- **Slides / motion-lite** — `visual-explainer:generate-slides` (self-contained animated HTML deck).
- **UI / site** — `impeccable`, `21st-ai`.
- **Not available here** — ElevenLabs voiceover, HeyGen avatar video. Do not depend on them; never fabricate an avatar.

## Launch asset — pick the first path that works

1. **Higgsfield video** (if enabled) — a short launch clip.
2. **`generate-slides` launch deck** — an animated self-contained HTML launch sequence.
3. **NotebookLM overview** — an audio+visual walkthrough.

Whichever you pick, watch/open the result and confirm it actually renders before counting it done.

## Founder script

Written artifact, brand voice (or `~/.claude/voice.md` if present). If a talking clip is wanted and Higgsfield is enabled, use it; otherwise leave it as a storyboarded script. No fake avatars.
