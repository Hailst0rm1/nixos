---
name: excalidraw-diagram
description: Build a diagram as editable Excalidraw JSON, rendered to PNG. Use for architecture diagrams, flowcharts, sequence diagrams, state machines, protocol or system walkthroughs, and data-flow or pipeline visuals. Also triggers on /excalidraw.
---

# Excalidraw Diagram Creator

Write `.excalidraw` JSON that **argues visually**, render it to PNG, and fix what you see — looping until the render matches the design.

Every color comes from `references/color-palette.md`. Read it before generating any element: it is the single source of truth for shape fills, strokes, text hierarchy and evidence-artifact schemes, and the one file to edit to restyle this skill for another brand. Invent no colors — a concept that fits no semantic category uses Primary/Neutral or Secondary.

## Diagrams argue, they don't display

A diagram is not formatted text. It is a visual argument, and the shape **is** the meaning. Two tests apply at every step:

- **Isomorphism** — strip every label out. Does the remaining structure still communicate the concept? If not, redesign the structure.
- **Education** — could someone learn something concrete from this, or does it only label boxes? Good diagrams show real formats, real event names, real examples.

| Displaying | Arguing |
|---|---|
| Five equal boxes with labels | Each concept shaped to mirror its behaviour |
| Card grid layout | Visual structure matching conceptual structure |
| Icons decorating text | Shapes that carry the meaning |
| One container for everything | A distinct visual vocabulary per concept |
| Everything boxed | Free-floating text with selective containers |

## Step 1 — Choose the depth

This single choice drives every step after it.

| | **Simple / conceptual** | **Comprehensive / technical** |
|---|---|---|
| Use for | Mental models, philosophies, quick overviews, an audience that already knows the details | Real systems, protocols, architectures, tutorials, teaching material |
| Labels | Generic: `Input → Process → Output` | Specific: what the input and output actually look like |
| Sequences | A "Events" label | A timeline carrying real event names from the spec |
| Teaches | The structure | The structure and the details |
| Explaining time | ~30 seconds | 2–3 minutes |

Comprehensive diagrams additionally require Step 2, evidence artifacts (Step 4), and all three zoom levels (Step 5).

## Step 2 — Research the specifics (comprehensive only)

Look up the real specification before drawing anything: the actual JSON and data formats, the real event names, method names and endpoints, and how the pieces genuinely connect. Use that terminology verbatim.

- Weak: `Protocol` → `Frontend`
- Strong: `AG-UI streams events (RUN_STARTED, STATE_DELTA, A2UI_UPDATE)` → `CopilotKit renders via createA2UIMessageRenderer()`

Done when every box and label you plan to draw traces to a name you have actually read, not one you assumed.

## Step 3 — Understand the concepts

For each concept, answer what it **does** rather than what it is: the relationships between concepts, the core transformation or flow, and — critically — what someone would need to **see** to understand it.

## Step 4 — Map each concept to a pattern

Choose the visual form that mirrors the concept's behaviour:

| The concept… | Pattern |
|---|---|
| Spawns multiple outputs | **Fan-out** — radial arrows from a centre |
| Combines inputs into one | **Convergence** — funnel, arrows merging |
| Has hierarchy or nesting | **Tree** — lines plus free-floating text |
| Is a sequence of steps | **Timeline** — line, dots, free-floating labels |
| Loops or improves continuously | **Cycle** — arrow returning to the start |
| Is an abstract state or context | **Cloud** — overlapping ellipses |
| Transforms input to output | **Assembly line** — before → process → after |
| Compares two things | **Side-by-side** — parallel with contrast |
| Separates into phases | **Gap** — visual break between sections |

`references/visual-patterns.md` draws each of these, and carries the shape→meaning table and the size scale to build them with.

**Each major concept gets a different pattern.** Two concepts sharing a pattern is the card-grid failure wearing a disguise.

**Comprehensive diagrams: add evidence artifacts.** These are the concrete examples that prove the diagram is accurate and give the viewer something to learn. Pick what fits:

| Artifact | Use for | Rendered as |
|---|---|---|
| Code snippet | APIs, integrations, implementation detail | Dark rectangle + syntax-colored text |
| Data/JSON example | Formats, schemas, payloads | Dark rectangle + colored text |
| Event or step sequence | Protocols, workflows, lifecycles | Timeline: line + dots + labels |
| UI mockup | Actual output or result | Nested rectangles mimicking the real UI |
| Real input content | What goes into a system | Rectangle with sample content visible |
| API/method name | Real calls, real endpoints | The actual name from the docs |

Evidence-artifact colors live in `color-palette.md`. The principle throughout: **show what things actually look like**, not just what they are called.

## Step 5 — Sketch the composition

Trace how the eye will move through the diagram; there must be one clear visual story. Guide it left→right or top→bottom for sequences, radially for hub-and-spoke.

**Position never implies a relationship.** If A relates to B, an arrow or line says so.

**Default to free-floating text.** Typography — size, weight, color — creates hierarchy without boxes. For each element you are tempted to box, ask whether it works as bare text; if it does, drop the container. Containers earn their place when the element is a section's focal point, needs visual grouping, has arrows binding to it, represents a distinct thing in the system, or when the shape itself means something (a decision diamond). Labels, descriptions, metadata, section titles and annotations get no container.

**Comprehensive diagrams work at three zoom levels at once**, like a map showing both borders and street names:

1. **Summary flow** — the whole pipeline at a glance (`Client → Server → Database`), usually along the top or bottom.
2. **Section boundaries** — labeled regions grouping related components into visual rooms, by responsibility, phase, or actor.
3. **Detail inside sections** — the evidence artifacts. This is where the teaching happens.

Done when you can name, for every element you intend to draw, which pattern it belongs to and which zoom level it serves.

## Step 6 — Build the JSON, one section per edit

Create the file with the wrapper plus the first section, then **add one section per edit**. Each section gets a dedicated pass: think about its layout, its spacing, and how it joins what already exists. This is what keeps quality up and output within limits — a comprehensive diagram exceeds a single response's output budget, and a truncated file is a broken file.

Hand-write the JSON yourself. A generator script or a delegated subagent adds a layer that has none of this file's design context, and debugging coordinate math through it costs more than writing the coordinates.

While building:

- **Descriptive string IDs** (`trigger_rect`, `arrow_fan_left`) so cross-section references read clearly.
- **Namespace `seed` values by section** (section 1 → `100xxx`, section 2 → `200xxx`) to avoid collisions.
- **Bind across sections as you go.** When a new element binds to an earlier one, edit that earlier element's `boundElements` in the same pass.

Split sections along the natural groupings from Step 5 — typically entry point, first routing decision, the main content (often the largest), then the remaining phases and outputs. Each section should stand on its own: its elements, its internal arrows, its references to neighbours.

`references/element-templates.md` has a copy-paste template per element type; `references/json-schema.md` has the file wrapper, every property, and the house style for `roughness`, `strokeWidth` and `opacity`.

Done when every section from Step 5 exists in the file, every `boundElements` entry and binding names an element that exists, and no section is cramped while another holds empty space.

## Step 7 — Render and validate

JSON cannot be judged as JSON. Render it, look at the PNG, fix what you see, and repeat.

```bash
python3 ~/.claude/skills/excalidraw-diagram/references/render_excalidraw.py <path-to-file.excalidraw>
```

The PNG lands next to the `.excalidraw` file. **Read the PNG with the Read tool** — the render is worthless unless you actually look at it.

Each cycle:

1. **Render, then view.** Run the script, Read the PNG.
2. **Audit against the design.** Before hunting defects, compare the render to Steps 4–5: does the visual structure match the conceptual structure, does each section use its intended pattern, does the eye flow in the designed order, are hero elements dominant, and — comprehensive — are the evidence artifacts readable and well placed?
3. **Hunt visual defects.** Text clipped or overflowing its container; text or shapes overlapping; arrows crossing through elements instead of routing around them; arrows landing on the wrong element or in empty space; labels floating unanchored; uneven spacing among elements that should match; one section cramped beside another that is empty; text too small to read; a lopsided composition.
4. **Fix.** Widen containers around clipped text; adjust `x`/`y` for spacing and alignment; add waypoints to an arrow's `points` to route around elements; move labels nearer what they describe; resize to rebalance weight across sections.
5. **Re-render, re-view, repeat.**

Expect 2–4 cycles. The loop ends when the render matches the conceptual design, no text is clipped or unreadable, every arrow routes cleanly to its intended element, spacing is consistent — and you would show it to someone with no caveats. An absence of critical bugs after one pass is not the end of the loop; a composition that could be better still gets another cycle.
