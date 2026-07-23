# `ideas.json` schema

`pitch` consumes this file. Keep it valid and stable.

```json
{
  "field": "cyber-security",
  "generated": "2026-05-10",
  "axes": {
    "x": "Market ceiling",
    "y": "Underserved-ness"
  },
  "ideas": [
    {
      "slug": "phishing-drill-for-smb",
      "name": "PhishDrill",
      "problem": "One-line statement of the painful problem it kills.",
      "goal": "The business goal — who pays, for what outcome.",
      "signals": {
        "pain": 5,
        "market": 3,
        "underserved": 4,
        "feasibility": 4,
        "speed": 5
      },
      "profile": "underserved sweet spot",
      "evidence": {
        "pain": ["https://…", "https://…"],
        "market": ["https://…"],
        "competitors": ["https://…"]
      }
    }
  ]
}
```

- `axes` — the two signals that best separate *this* batch; the overview slide plots ideas on them.
- `evidence` — live URLs actually fetched. An idea with an empty evidence bucket does not belong in the file.
- `slug` — kebab-case, stable; this is what the user passes to `/pitch`.
