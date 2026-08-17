# Visual Patterns

The drawn form of each pattern from Step 4, plus the shapes and sizes to build them with.

## Fan-Out (one-to-many)

A central element with arrows radiating out. For sources, root causes, hubs.

```
        ○
       ↗
  □ → ○
       ↘
        ○
```

## Convergence (many-to-one)

Multiple inputs merging into a single output. For aggregation, funnels, synthesis.

```
  ○ ↘
  ○ → □
  ○ ↗
```

## Tree (hierarchy)

Parent-child branching built from `line` elements and free-floating text — no boxes. For file systems, org charts, taxonomies.

```
  label
  ├── label
  │   ├── label
  │   └── label
  └── label
```

## Cycle (continuous loop)

A sequence whose last arrow returns to the start. For feedback loops, iteration, evolution.

```
  □ → □
  ↑     ↓
  □ ← □
```

## Assembly Line (transformation)

Input, process, output with a visible before and after.

```
  ○○○ → [PROCESS] → □□□
  chaos              order
```

## Cloud (abstract state)

Overlapping ellipses at varied sizes. For context, memory, conversations, mental states.

## Side-by-Side (comparison)

Two parallel structures with visual contrast. For before/after, options, trade-offs.

## Gap (separation)

Whitespace or a barrier between regions. For phase changes, context resets, boundaries.

## Lines as structure

`line` elements (not arrows) carry structure more cleanly than boxes do:

- **Timelines** — one long line with 10–20px ellipse dots at intervals, free-floating labels beside each dot.
- **Trees** — a vertical trunk plus horizontal branches, labels as bare text.
- **Dividers** — thin dashed lines between sections.
- **Flow spines** — a central line that elements relate to, instead of boxes chained together.

```
Timeline:           Tree:
  ●─── Label 1        │
  │                   ├── item
  ●─── Label 2        │   ├── sub
  │                   │   └── sub
  ●─── Label 3        └── item
```

## Shape → meaning

| Concept | Shape | Why |
|---|---|---|
| Labels, descriptions, details | **none** — free-floating text | Typography is the hierarchy |
| Section titles, annotations | **none** — free-floating text | Font size and weight suffice |
| Markers on a timeline | small `ellipse`, 10–20px | An anchor, not a container |
| Start, trigger, input | `ellipse` | Soft, origin-like |
| End, output, result | `ellipse` | Completion, destination |
| Decision, condition | `diamond` | The classic decision symbol |
| Process, action, step | `rectangle` | A contained action |
| Abstract state, context | overlapping `ellipse` | Fuzzy, cloud-like |
| Hierarchy node | lines + text | Structure through lines |

Small dots (10–20px ellipses) also serve as bullet points, connection nodes, and anchors for free-floating text.

## Size scale

Hierarchy comes from scale, and the most important element carries the most empty space around it (200px+).

| Role | Size |
|---|---|
| Hero — the visual anchor | 300×150 |
| Primary | 180×90 |
| Secondary | 120×60 |
| Small | 60×40 |
