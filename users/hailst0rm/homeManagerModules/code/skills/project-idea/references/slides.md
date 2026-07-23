# Slideshow spec

Built with `visual-explainer:generate-slides` into one self-contained `slides.html`. Visual-first: big type, one idea per screen, the scorecard as a small viz — not walls of bullets. Evidence URLs live in `ideas.json`; keep them off the slides (a tiny "sources in ideas.json" footnote is fine).

## Slide 1 — the opportunity landscape

Plot all ideas on the two axes named in `ideas.json.axes` (the pair that best separates this batch). Each idea is a labelled point; color or marker by profile tag. This is the map the user reads first.

## One slide per idea

Each carries, laid out visually:

- **Name + tagline**
- **The one-line problem it kills**
- **Business goal** — who pays, for what outcome
- **Signal scorecard** — the five signals as a compact viz (radar or five small bars), not a table of numbers
- **Profile tag** — one line
- **Hero image** — one generated visual via `/imagegen` (or Higgsfield if enabled) so each idea is glanceable and distinct

## Order

Overview first, then ideas grouped by profile tag so the spread reads as a deliberate landscape rather than a ranked list.
