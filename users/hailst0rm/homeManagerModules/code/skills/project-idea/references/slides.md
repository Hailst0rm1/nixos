# Slideshow spec

One self-contained `slides.html`, built with `visual-explainer:generate-slides` and drawn entirely from `ideas.json`. The reader is deciding what to build, so every screen has to survive *"what is this, concretely?"*.

## The before-and-after is the visual

Each idea's centrepiece is its `today` chain beside its `after` chain: two columns, one beat per line, the break in `today` marked where it fails.

`visual-explainer:generate-slides` will push for generated hero imagery; this deck declines it. A picture that cannot move with the content cannot be wrong about it, and so cannot inform. The before-and-after is drawn from the data, so a wrongly-described idea fails visibly.

## Landscape slide

Plot every shipped idea on the two axes in `ideas.json.axes`. Each is a labelled point, marked by profile tag. An empty quadrant is a finding — label it as one.

## One slide per shipped idea

- **Name**, with `gap` as the line beneath it
- **before-and-after** — the two chains
- **`goal` and `who`** — what you sell, who pays
- **`catch`** — set in the same weight as the rest of the slide, not a footnote
- **Signal scorecard** — five small bars or a radar, never a table of numbers
- **Profile tag**
- **`vendors`** — who is already in this space, as chips

## One slide per cut idea

Cut ideas get slides, not table rows. A table summarises a verdict; only a slide lets the reader overturn one.

Each carries `title`, `was`, `killed`, its `facts`, its vendor chips, and — given equal weight to the kill — `revive`. Order the graveyard by `strength`, so the most revivable idea is the first one read.

## Every product named is explained

No reader knows what Exterro ARMOURop is. Every vendor name on the deck is a chip that opens its `vendors` entry: what it is, what it does, **what it does not do**, and price.

## Order

Landscape → shipped ideas grouped by profile tag → cut ideas by `strength` → the closing read.

Evidence URLs stay in `ideas.json`; a "sources in ideas.json" footnote is enough.
