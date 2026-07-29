# `ideas.json` schema

`pitch` consumes this file, and `slides.html` is drawn entirely from it. Keep it valid and stable.

```json
{
  "field": "cyber-security / DFIR",
  "generated": "2026-07-28",
  "axes": { "x": "Market ceiling", "y": "Underserved-ness" },

  "ideas": [
    {
      "slug": "resumable-evidence-processing",
      "name": "Checkpoint",
      "gap": "Forensic processing is a multi-day batch job with no save point. A crash on day three costs you all three days.",
      "today": [
        "Examiner loads a 4 TB disk image for processing",
        "Tool grinds for three days behind a progress bar that lies",
        "Hour 68 — out of memory, process dies",
        "Nothing was written. Start again from zero."
      ],
      "after": [
        "Same image, same parsers",
        "A checkpoint is written every few minutes",
        "Hour 68 — out of memory, process dies",
        "Restart picks up at hour 67, not zero."
      ],
      "goal": "What you sell, and for what outcome.",
      "who": "Who signs the cheque, and on what basis they are billed.",
      "catch": "The strongest honest objection to this idea.",
      "vendors": ["plaso", "armourop"],
      "signals": { "pain": 5, "market": 2, "underserved": 4, "feasibility": 3, "speed": 2 },
      "profile": "loudest pain in the field, no evidenced buyer",
      "evidence": {
        "pain": ["https://…"],
        "market": ["https://…"],
        "competitors": ["https://…"]
      }
    }
  ],

  "cut": [
    {
      "slug": "m365-log-completeness",
      "title": "Prove which Microsoft 365 logs you didn't get",
      "verdict": "KILLED",
      "was": "What the idea was, in plain words — enough that the reader can want it back.",
      "killed": "The single fact that ended it.",
      "facts": ["Dated, specific evidence, one line each"],
      "revive": "What would have to be true to bring it back, and how expensive that is to check.",
      "strength": 4,
      "vendors": ["pax"],
      "evidence": ["https://…"]
    }
  ],

  "vendors": {
    "armourop": {
      "name": "Exterro ARMOURop",
      "what": "AI evidence-review add-on for Exterro's FTK suite, announced 16 July 2026.",
      "does": "Claims to cut evidence review time by up to 95%.",
      "doesnt": "Tied to the Exterro stack, and no independent evaluation exists yet.",
      "price": "Not public"
    }
  }
}
```

## Writing the fields

**Plain register.** `gap`, `today`, `after`, `catch`, `was` and `revive` are read by someone outside the field. Concrete nouns, real numbers, ordinary words. "Processing large evidence runs with no honest progress signal" is vendor register and says nothing; "a crash on day three costs you all three days" is the same fact in plain register.

- `gap` — one sentence naming what is broken. This is the line the reader judges the idea on.
- `today` — 3–5 beats of what actually happens now, ending on the failure. Concrete enough that a practitioner would recognise their own week.
- `after` — the *same run* replayed with the thing built. Same opening beats, different ending. If `after` doesn't mirror `today`, the idea isn't a gap-closer and probably isn't real.
- `catch` — the strongest honest objection. An idea whose `catch` is weak was not attacked hard enough.
- `vendors` — keys into the top-level `vendors` map, listing who is already in this space.

## `cut`

Cut ideas ship in the file. The reader is entitled to overturn a verdict, and cannot do it from a slug and a sentence.

- `revive` — **what would have to be true** for the idea to come back, plus what checking it costs. This is the field that makes a graveyard useful; an idea killed on one vendor's own claim is one experiment away from alive.
- `strength` — 1–5, how revivable. Orders the graveyard.

## `vendors`

A glossary of every product named anywhere in the run, so no reader meets a name they cannot look up. Built during the competitor pass, not reconstructed afterwards.

`doesnt` is the load-bearing field — it is where the opening would be, if there is one. Never leave it empty.

## Constants

- `axes` — the two signals that best separate *this* batch; the landscape slide plots ideas on them.
- `evidence` — live URLs actually fetched. An idea with an empty evidence bucket does not belong in the file.
- `slug` — kebab-case, stable; this is what the user passes to `/pitch`.
