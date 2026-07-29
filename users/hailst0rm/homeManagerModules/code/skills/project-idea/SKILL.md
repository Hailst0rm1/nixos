---
name: project-idea
description: Hunt real, evidence-backed business/project opportunities in a field and present them as a visual slideshow. User-invoked — run `/project-idea [field]`.
disable-model-invocation: true
---

# Project Idea

Map an **opportunity landscape**: find real, currently-painful, underserved problems in a field, score each opportunity on merit, and hand back a visual slideshow the user browses to pick a winner. The winner feeds `pitch`.

Run start-to-finish without asking the user anything. Every question you would ask, answer it yourself with research, and log the question → answer → why in `build-log.md`.

The root virtue is **evidence**: every claim about a pain, a market, or a competitor traces to a live URL you actually fetched. An idea you cannot back with real URLs does not ship — cut it and log why. A smaller slate built on real evidence beats a grand one built on plausible fiction.

## Output location

Write everything to `./project-ideas/<field-or-general>-<YYYY-MM-DD>/` in the current working directory:

- `build-log.md` — every self-answered decision, every cut idea + reason
- `research/` — fetched evidence, one file per angle
- `ideas.json` — the structured slate (schema in [`references/ideas-schema.md`](references/ideas-schema.md)); this is what `pitch` consumes
- `slides.html` — the deck

Print the output path when done.

## Steps

1. **Scope the field.** Take it from the argument. If none was given, pick 2–3 promising fields yourself using quick market-signal scans and log why you chose them over alternatives. → *criterion: the field(s) are named in `build-log.md` with a one-line rationale.*

2. **Hunt for pain.** Fan out parallel research across independent angles — do not do this serially:
   - **Complaint mining** — real user pain: Reddit, forums, G2/Trustpilot/app-store reviews, support-thread digs. Drive this with the `customer-research` marketing skill (VOC, review mining, digital watering holes).
   - **Market / revenue signal** — how much money is realistically on the table; real market-size, pricing, and spend sources.
   - **Competitor landscape** — who already serves this and how badly they fail. Drive this with the `competitor-profiling` marketing skill. Write a glossary entry for every product the moment you meet it — what it is, what it does, what it does not do, price — because reconstructing them at the end costs a whole extra pass.
   Capture every source URL into `research/`, each with the date it was published. A complaint the vendor has since fixed is not a pain: check it still holds today, not merely that it was once made. → *criterion: each angle has a `research/*.md` file where every claim carries a live URL and a date, and every product named has a glossary entry.*

3. **Score each candidate on the signal scorecard.** Rate every surviving candidate on the five **opportunity signals** — Pain, Market ceiling, Underserved-ness, Feasibility, Speed-to-signal — per the rubric in [`references/signals.md`](references/signals.md). Assign each a one-line **profile tag** ("starving niche, low ceiling" / "huge market, crowded, slow" / "underserved sweet spot"). → *criterion: every candidate has all five signals scored with a cited reason and a profile tag.*

4. **Shortlist: merit hard, diversity soft.** Keep only ideas genuinely promising on the evidence — merit is the **hard filter**, no filler. Then apply diversity as a **soft constraint**: cap how many ideas share the same profile so the slate is not monotone. Never invent a weak contrarian idea to manufacture spread; let the real evidence surface the range. Target ~8 ideas; ship fewer if the evidence is thin and log why. → *criterion: the slate is ~8 evidence-backed ideas, no two dominated by an identical profile beyond the cap, and any shortfall from 8 is logged.*

5. **Skeptic pass.** Spawn one sub-agent whose only job is to refute the key claims behind the shortlist. Downgrade or drop any idea whose core pain/market claim does not survive. → *criterion: the skeptic ran; every surviving idea's central claim withstood refutation, logged in `build-log.md`.*

6. **Write `ideas.json`.** Emit the whole slate — shipped ideas, cut ideas, and the vendor glossary — to the schema in [`references/ideas-schema.md`](references/ideas-schema.md). Cut ideas ship with **what would have to be true** to revive them; the reader is entitled to overturn a verdict. Write every prose field in **plain register**: concrete nouns, real numbers, ordinary words, no vendor language. → *criterion: `ideas.json` validates; every shipped idea carries evidence URLs and a mirrored `today`/`after` pair; every cut idea carries a `revive`; every product named anywhere has a glossary entry with its "does not do" line filled.*

7. **Build the slideshow.** Use `visual-explainer:generate-slides` to produce a single self-contained `slides.html` per [`references/slides.md`](references/slides.md), drawn entirely from `ideas.json`. Open it in the browser. → *criterion: `slides.html` opens; every shipped idea slide shows its before-and-after, goal, catch and scorecard; every cut idea has its own slide ending on `revive`; every product named is one click from its glossary entry.*

8. **Grade against the definition of done.** Run the checklist in [`references/dod.md`](references/dod.md) and fix anything failing before you stop. → *criterion: every DoD item passes or is logged as a deliberate cut with a reason.*
