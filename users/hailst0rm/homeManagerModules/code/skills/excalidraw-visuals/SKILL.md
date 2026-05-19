---
name: visualizations
description: Use when someone asks for a hand-drawn visual, PNG image, rendered diagram, visual explanation, visualization, or says "make a visual" or "draw a visual". This generates PNG images, not editable files.
argument-hint: "[concept to visualize]"
---

Read the full visual specification before building any prompt:
- [style-guide.md](style-guide.md) -- color system, font spec, shape rules, icon vocabulary, layout templates, text minimization rules

---

## Style Prefixes (LOCKED)

Two variants exist: **Light** (default) and **Dark**. Use Dark when the user asks for "dark mode", "dark background", or "dark theme". Never modify these per-request.

### Light Mode (default)

```
Excalidraw-style sketch on a completely plain white background -- pure #ffffff, no texture, no paper grain, no off-white, no noise. The background must be perfectly clean and flat white.

Text and linework are the hand-drawn elements: all text is messy but legible hand-scrawled handwriting with uneven letter sizes and slight tilts -- like someone wrote it fast with a thick felt-tip marker. Lines and shape outlines are VERY wobbly and imperfect -- visibly shaky, not smooth at all. Corners of rectangles don't quite meet. This should look like a real person drew the outlines and wrote the text by hand, NOT like a computer generated it.

Shape fills are SOLID and FLAT -- exactly like Excalidraw's default fill. Clean, even, uniform pastel color inside each shape. No hatching, no cross-hatching, no pencil shading, no marker texture, no highlighter streaks, no uneven coverage. Just a flat solid color fill, the way Excalidraw renders it. Each shape's border color is a darker version of its fill -- soft blue fill (#a5d8ff) with medium blue border (#1971c2), warm yellow fill (#ffec99) with amber border (#f59f00), soft green fill (#b2f2bb) with medium green border (#2f9e44), coral fill (#ffa8a8) with red-orange border (#e03131), light purple fill (#d0bfff) with medium purple border (#7048e8). Borders are 2-3px thick with wobbly hand-drawn outlines. Do NOT use dark gray borders -- every shape's border matches its fill color family.

Arrows are hand-drawn with visible wobble and curve, like someone drew them freehand. Arrowheads are rough triangles, slightly lopsided. Arrows match the color of shapes they connect, or dark gray (#495057) for neutral flows.

Color palette: soft blue (#a5d8ff), warm yellow (#ffec99), soft green (#b2f2bb), coral (#ffa8a8), light purple (#d0bfff). All text is dark charcoal (#343a40). Background is always pure flat white (#ffffff).

People are very simple stick figures -- just a circle head and stick body, drawn with wobbly lines. AI robots have a wobbly round head with two uneven dot eyes and a crooked little antenna. Documents have a folded corner. Gears represent automation. All icons are simple wobbly line drawings, not detailed or cartoonish.

Layout is clean and spacious with generous whitespace. Visual hierarchy is clear -- title is largest, labels are short (max 3 words each). The overall feel is like authentic Excalidraw -- messy hand-drawn text and wobbly outlines, but with clean solid flat color fills inside shapes. Like a whiteboard sketch, not a polished diagram.

Do NOT include: realistic photos, gradients, drop shadows, 3D effects, corporate clip art, stock imagery, dark backgrounds, dark gray borders on colored shapes, textured backgrounds, hatching, cross-hatching, pencil shading, marker texture on fills.
```

### Dark Mode

Use this prefix when the user requests dark mode, dark background, or dark theme.

```
CRITICAL: The background color MUST be EXACTLY #121212 -- not black (#000000), not near-black, not dark gray, not #1a1a1a, not #0d0d0d. The EXACT hex value #121212. This is non-negotiable.

Excalidraw-style sketch on a completely plain dark background -- EXACTLY #121212, no texture, no paper grain, no noise. The background must be perfectly clean, flat, and uniform #121212 everywhere. Not darker, not lighter -- exactly #121212 like Excalidraw's dark mode.

Text and linework are the hand-drawn elements: all text is messy but legible hand-scrawled handwriting in white (#f8f9fa) with uneven letter sizes and slight tilts -- like someone wrote it fast with a thick white felt-tip marker on a dark surface. Lines and shape outlines are VERY wobbly and imperfect -- visibly shaky, not smooth at all. Corners of rectangles don't quite meet. This should look like a real person drew the outlines and wrote the text by hand, NOT like a computer generated it.

Shape fills are SOLID and FLAT -- exactly like Excalidraw's default fill in dark mode. Clean, even, uniform muted color inside each shape. No hatching, no cross-hatching, no pencil shading, no marker texture, no highlighter streaks, no uneven coverage. Just a flat solid color fill, the way Excalidraw renders it. Each shape's border color is a lighter version of its fill -- muted blue fill (#1e3a5f) with light blue border (#74b9ff), muted amber fill (#5c4813) with warm yellow border (#ffec99), muted green fill (#1e4d2b) with light green border (#8ce99a), muted red fill (#5c1a1a) with coral border (#ff8787), muted purple fill (#3b2d6b) with light purple border (#b197fc). Borders are 2-3px thick with wobbly hand-drawn outlines.

Arrows are hand-drawn with visible wobble and curve, like someone drew them freehand. Arrowheads are rough triangles, slightly lopsided. Arrows are light gray (#dee2e6) or match the border color of shapes they connect.

Color palette (dark mode fills): muted blue (#1e3a5f), muted amber (#5c4813), muted green (#1e4d2b), muted red (#5c1a1a), muted purple (#3b2d6b). Color palette (dark mode borders/labels): light blue (#74b9ff), warm yellow (#ffec99), light green (#8ce99a), coral (#ff8787), light purple (#b197fc). All text is white (#f8f9fa). Background is ALWAYS exactly #121212 -- this exact hex value, no variation.

People are very simple stick figures -- just a circle head and stick body, drawn with wobbly white lines. AI robots have a wobbly round head with two uneven dot eyes and a crooked little antenna, drawn in white. Documents have a folded corner. Gears represent automation. All icons are simple wobbly white line drawings, not detailed or cartoonish.

Layout is clean and spacious with generous dark space. Visual hierarchy is clear -- title is largest, labels are short (max 3 words each). The overall feel is like authentic Excalidraw in dark mode -- messy hand-drawn white text and wobbly outlines, but with clean solid flat muted color fills inside shapes. Like a dark whiteboard sketch.

Do NOT include: realistic photos, gradients, drop shadows, 3D effects, corporate clip art, stock imagery, white or light backgrounds, textured backgrounds, hatching, cross-hatching, pencil shading, marker texture on fills. REMINDER: background must be EXACTLY #121212.
```

---

## Step 1: Gather Input

If `$ARGUMENTS` was provided, use it as the concept to visualize.

Otherwise, get from the user:
- What concept or process to visualize
- Any specific elements, steps, or labels to include
- Aspect ratio preference (default: 16:9 for YouTube)

If the request is vague, ask one clarifying question about what specific angle or flow to show.

## Step 2: Choose a Layout Template

Pick the best layout from the style guide:

| Template | Best For |
|----------|----------|
| Left-to-Right Flow | Processes, sequences, transformations |
| Hub and Spoke | Capabilities, features around a central concept |
| Top-to-Bottom Hierarchy | Levels, layers, progressive depth |
| Side-by-Side Comparison | Before/after, old vs new, option A vs B |
| Numbered Steps List | Frameworks, checklists, ordered instructions |
| Cycle / Loop | Feedback loops, iterative processes |

## Step 3: Plan the Text (Minimize It)

Plan every piece of text that will appear in the image before writing the prompt:

1. **Title:** Max 5 words. Prefer 3.
2. **Box labels:** Max 3 words each. Prefer 1-2.
3. **Annotations:** Max 4 words each.
4. **Total word count:** Target under 30 words. Absolute max 50.

**Spelling protection:**
- Flag any word over 8 characters and shorten it
- Use icons instead of words where possible
- Use abbreviations (API, AI, DB, CLI)
- Remove articles and prepositions

## Step 4: Build the Prompt

Construct the prompt in this exact structure:

```
[STYLE PREFIX]

STYLE REFERENCE: Match the hand-drawn Excalidraw aesthetic of the reference image but make it EVEN MORE rough and sketchy. More wobble on outlines and text, more imperfection. But keep shape fills SOLID and FLAT like Excalidraw -- no hatching, no shading, no texture on fills.

Diagram concept: [TITLE -- max 5 words]

Layout: [TEMPLATE NAME] -- [brief spatial description]

Elements (left to right / top to bottom):
1. [Element name] -- [color] (#hex) rough rounded rectangle with solid flat [color] fill and [border color] (#hex) wobbly border. Inside: [icon description], label: "[EXACT TEXT]"
2. ...

Connections:
- Arrow from [1] to [2], label: "[TEXT or none]"
...

Title at top center, bold and large scrawled text: "[EXACT TITLE TEXT]"
```

**Critical rules for element descriptions:**
- Every element MUST say "solid flat [color] fill" -- this is the #1 lever for clean Excalidraw-style shapes
- Every element MUST specify both the fill hex AND the border hex
- Say "wobbly border" on every element to keep outlines sketchy
- Say "rough rounded rectangle" not just "rectangle"
- Describe icons as scene elements ("a stick figure at a wobbly-drawn laptop") not abstractions
- Describe the emotional feel of each section ("feels chaotic", "feels organized")
- Be explicit about spatial positions ("on the left", "top center", "bottom right")

## Golden Example (produces the target style)

This prompt produced a perfect result. Study its patterns and replicate them:

```
[STYLE PREFIX]

STYLE REFERENCE: Match the hand-drawn Excalidraw aesthetic of the reference image but make it EVEN MORE rough and sketchy. More wobble, more imperfection. But keep shape fills solid and flat like Excalidraw.

Diagram concept: AI Chat vs AI Assistant

Layout: Side-by-Side Comparison -- split into two halves with a thin hand-drawn vertical dashed line down the center.

LEFT SIDE (the old frustrating way):
- Rough hand-scrawled title at top-left: 'Every New Chat'
- A large coral (#ffa8a8) rough rounded rectangle with solid flat coral fill and red-orange (#e03131) wobbly border fills the left area
- Inside: a simple stick figure at a wobbly-drawn laptop, slumped posture
- Three small speech bubble shapes (rough coral ovals with solid flat fill) from the figure:
  1. 'I'm Nate...'
  2. 'My biz...'
  3. 'I need...'
- Below: a rough coral circle with solid flat fill and a hand-drawn circular arrow (repeat symbol)
- Scrawled label: 'Repeat'
- Feels chaotic and repetitive

RIGHT SIDE (the AI assistant way):
- Rough hand-scrawled title at top-right: 'AI Assistant'
- Upper section scrawled label: 'Knows You'
- A soft blue (#a5d8ff) rough rectangle with solid flat blue fill and blue (#1971c2) wobbly border, containing a simple robot sketch
- Five small rough blue rectangles with solid flat fills radiating around the robot, connected by wobbly blue arrows:
  1. 'Name'  2. 'Business'  3. 'Team'  4. 'Priorities'  5. 'Style'
- Below, scrawled label: 'Does Things'
- Four rough soft green (#b2f2bb) rectangles with solid flat green fills and green (#2f9e44) wobbly borders in a 2x2 grid:
  1. 'Research' with a rough magnifying glass sketch
  2. 'Check Team' with rough stick figures
  3. 'Plan Day' with a rough calendar sketch
  4. 'Create' with a rough document sketch
- Feels organized and capable

Title at very top center, large scrawled text: 'AI Chat vs AI Assistant'
Left side should feel chaotic and repetitive. Right side feels organized and capable.
```

**Key patterns from this example that MUST be replicated:**
- "solid flat [color] fill" on EVERY shape -- never skip this
- "wobbly border" on EVERY shape
- "rough rounded rectangle" not just "rectangle"
- Icons described as physical scenes ("stick figure at a wobbly-drawn laptop")
- Emotional feel described per section ("Feels chaotic", "Feels organized")
- Sub-text written as scrawled labels, not typed text

## Step 5: Assign Colors by Meaning

- **Flows:** Blue (input) -> Yellow (process) -> Green (output)
- **Comparisons:** Coral (old/bad/slow) vs Green (new/good/fast)
- **Hub and spoke:** Blue center, mixed colors for spokes
- **Hierarchies:** Blue (top) -> Yellow (middle) -> Green (bottom)
- **Lists/grids:** Alternate colors row by row

Never leave color choice to the model. Always specify.

**Dark mode color mapping:** Use the muted fill variants from the Dark Mode style prefix. Borders and labels use the lighter/brighter variants. Same semantic color assignments, just shifted for dark backgrounds.

| Light Fill | Dark Fill | Dark Border/Label |
|-----------|-----------|-------------------|
| soft blue (#a5d8ff) | muted blue (#1e3a5f) | light blue (#74b9ff) |
| warm yellow (#ffec99) | muted amber (#5c4813) | warm yellow (#ffec99) |
| soft green (#b2f2bb) | muted green (#1e4d2b) | light green (#8ce99a) |
| coral (#ffa8a8) | muted red (#5c1a1a) | coral (#ff8787) |
| light purple (#d0bfff) | muted purple (#3b2d6b) | light purple (#b197fc) |

## Step 6: Generate the Image

**Always include the style reference image.** This is mandatory.

```bash
export KIE_AI_API_KEY="$(cat "$(readlink -f ~/.config/sops-nix/secrets/services/kie/api-key 2>/dev/null || echo /run/user/$(id -u)/secrets/services/kie/api-key)")"
node generate-visual.js "<FULL_PROMPT>" "~/projects/excalidraw-visuals/[YYYY-MM-DD]-[slug].png" "[ASPECT_RATIO]" --input "excalidraw-style-reference.png"
```

With brand assets (when the visual mentions Claude or Claude Code):
```bash
export KIE_AI_API_KEY="$(cat "$(readlink -f ~/.config/sops-nix/secrets/services/kie/api-key 2>/dev/null || echo /run/user/$(id -u)/secrets/services/kie/api-key)")"
node generate-visual.js "<FULL_PROMPT>" "~/projects/excalidraw-visuals/[YYYY-MM-DD]-[slug].png" "[ASPECT_RATIO]" --input "excalidraw-style-reference.png" "brand-assets/Claude.png"
```

**Important:** Run the `node` command from the skill's directory so relative paths resolve correctly. The skill directory is wherever this SKILL.md file lives.

Aspect ratios: `16:9` (default), `1:1`, `4:5`, `9:16`, `3:2`, `2:3`, `3:4`, `4:3`, `5:4`, `21:9`

If `excalidraw-style-reference.png` does not exist, generate without it and tell the user.

## Step 7: Present Result

- Show the file path for preview
- One-line summary of what the visual shows
- Ask if adjustments are needed

If adjustments needed: modify only the diagram-specific portion. Never change the style prefix.

---

## Brand Assets (MANDATORY)

When a visual mentions Claude or Claude Code, pass the brand asset via `--input` in addition to the style reference:

| Topic | Asset | Flag |
|-------|-------|------|
| Claude / Claude Code | `brand-assets/Claude.png` | `--input "brand-assets/Claude.png"` |

The `--input` flag resolves local file paths to URLs via `.env` mappings. For example, `brand-assets/Claude.png` resolves to the `CLAUDE_URL` env var. The naming convention is: strip the extension, uppercase, replace non-alphanumeric with `_`, append `_URL`.

### Claude Logo Prompt Rules

When `brand-assets/Claude.png` is passed as input, add this block to the prompt (after the STYLE REFERENCE block):

```
BRAND LOGO PLACEMENT: The reference image contains the Claude logo (an orange starburst/sparkle shape). This logo MUST appear EXACTLY as it looks in the reference image -- pixel-perfect, clean, not redrawn or sketched. Place it INSIDE a diagram element where it fits naturally -- on a computer screen, in the corner of a shape, or as an icon within a box. It should feel like a subtle branded detail woven into the sketch content itself (like a logo on a laptop sticker or displayed on a monitor). Do NOT place it floating in the corner of the overall image like a watermark. Do NOT redraw, sketch, or modify the logo in any way.
```

**Placement guidelines:**
- **Best:** On a screen/monitor element (like the app is open)
- **Good:** Small and clean in the corner of the central/primary shape
- **Good:** Next to the title text as a small brand mark within a shape
- **Bad:** Floating in the image corner as a watermark
- **Bad:** Redrawn in the sketch style (must stay pixel-perfect)
- **Bad:** As the main focal point or centerpiece of the diagram

Then in the element description where the logo should appear, explicitly call it out. Example:
```
Inside: a wobbly-drawn computer monitor sketch. On the monitor screen, display the Claude logo (the exact orange starburst from the reference image, pixel-perfect and clean) as if it is the app loaded on the screen.
```

## File Locations

| What | Path |
|------|------|
| Style guide | `style-guide.md` (in this skill's directory) |
| Script | `generate-visual.js` (in this skill's directory) |
| Style reference | `excalidraw-style-reference.png` (in this skill's directory) |
| Output | `~/projects/excalidraw-visuals/` |
| API key | sops secret at `services/kie/api-key` |

## Notes

- Uses Nano Banana 2 API via kie.ai (better text generation than original Nano Banana)
- The style prefix is locked. Only the diagram description changes per-request.
- The style reference image is the #1 consistency lever. Always include it.
- If generation fails, check that the sops secret `services/kie/api-key` is populated
- When in doubt, fewer words and more icons
