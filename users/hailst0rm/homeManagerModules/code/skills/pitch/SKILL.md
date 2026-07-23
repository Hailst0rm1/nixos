---
name: pitch
description: Build the full marketing / demand-test package for a product idea — brand, landing page, launch asset, red-team, recap. User-invoked — run `/pitch <idea-slug | free-text idea | existing project>`.
disable-model-invocation: true
---

# Pitch

Produce everything needed to take a product **to market and measure demand** — the **marketing package** — for one idea. Brand, a landing page that runs as a **demand test** (a fake-door signup), a launch asset, an adversarial red-team, and a `recap.html` that ties it together.

`pitch` never builds the real product. In flow 3 the landing page *is* the MVP — a fake door that measures demand before anyone builds. The real thing is built by the user's separate workflow, or already exists.

Run start-to-finish without asking the user anything. Every question you would ask, answer it yourself and log question → answer → why in `build-log.md`. Blocked is not an option: if a tool fails, find another route; if a stage stalls, ship the strong 80%, note what got cut, keep moving.

## Guardrails (hard)

1. **Publish nothing.** Everything stays local. No deploying, posting, emailing, or messaging any real person.
2. **No new spend.** Use only tools already available (see [`references/media.md`](references/media.md)). No purchases, no paid signups, no domain registration — check availability, don't buy.
3. **Invent nothing.** Every quote, stat, complaint, competitor fact, and market claim traces to a live URL you actually fetched. Label inferences as inferences. Say so when something is unverifiable.

## Input & output

Resolve the input first:

- **idea-slug** → read the matching idea from a `./project-ideas/**/ideas.json`; its evidence URLs are your starting facts.
- **free-text idea** → establish the business yourself with research (same evidence rule).
- **existing project** → read the repo/product; market what is already there.

Write everything to `./pitch/<idea-slug>/`: `build-log.md`, `DESIGN.md`, the landing page, media, red-team notes, and `recap.html`. Print the output path when done.

## Steps

1. **Establish the business one-pager.** From the input, pin down: the buyer (ICP), the painful problem, the offer, and the value proposition — each backed by evidence. Use `product-marketing` (positioning/ICP), `offers` (offer design), and `customer-research` (audience/VOC). → *criterion: a one-page brief exists in `build-log.md`, every claim carrying a URL.*

2. **Brand → `DESIGN.md`.** Author brand guidelines with the `impeccable` skill: name, positioning, voice, palette (its `palette.mjs` seeds a brand color for greenfield), type, and logo (logo via `/imagegen`). The guide must be complete enough that a stranger could make a new on-brand asset from it alone. → *criterion: `DESIGN.md` covers name, voice, palette, type, and logo, and a stranger could extend it.*

3. **Landing page = the demand test.** Build a production-grade landing page with `impeccable` (brand register): hero, problem/solution, proof, and a **fake-door CTA** (waitlist / signup that captures intent, wired to nothing real). Copy from `copywriting`, conversion structure from `cro`, offer framing from `offers`, launch mechanics from `launch`. Screenshot-verify it on **mobile and desktop**. → *criterion: the page renders, has a fake-door CTA, and screenshots on both viewports are captured.*

4. **Launch asset (adaptive media).** Produce a launch asset using whatever media tools are present — pick the path from [`references/media.md`](references/media.md) and log which you took and why. → *criterion: a launch asset exists and the media path is logged.*

5. **Optional deliverables — 1 or 2 by fit.** Add the highest-leverage extras for *this* business from [`references/deliverables.md`](references/deliverables.md) (ad-creative, onboarding/email sequence, social assets, pricing, marketing-plan). Quality beats quantity — one polished artifact beats three rushed ones. → *criterion: 1–2 optional deliverables shipped, chosen for fit, logged.*

6. **Red-team — try to kill it.** Run the `marketing-council` skill as the adversarial pass: a board of marketers attacks the positioning and offer and surfaces where they disagree. Record the surviving objections. → *criterion: the red-team ran and its surviving objections are captured for the recap.*

7. **`recap.html`.** Build the index (use `visual-explainer` for polish): the business explained in five minutes, the red-team's surviving objections visible, and a deliverables map linking every artifact. Verify every link resolves. → *criterion: `recap.html` opens, explains the business, shows the red-team objections, and every link works.*

8. **Grade against the definition of done.** Run [`references/dod.md`](references/dod.md) as a completeness-critic pass and fix anything failing before you stop. Nothing in the package may be a placeholder pretending to be finished work. → *criterion: every DoD item passes or is logged as a deliberate cut with a reason.*

## Founder script voice

If a founder script is produced, write it in the **brand voice** from `DESIGN.md` by default. If `~/.claude/voice.md` exists, apply those personal voice rules instead. Never fabricate a founder avatar.
