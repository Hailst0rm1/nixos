# How pros produce GREAT AI-assisted UI (2025–2026), and a critique of the proposed `/prototype` workflow

One-line summary: the practitioner consensus is a three-layer loop — **read real component source before writing (kills hallucinated props) → constrain generation with a token contract (on-brand *by construction*, not by rewriting components) → generate N variants and pick VISUALLY from screenshots (because quality is visual and no description conveys it)**. The proposed workflow nails layers 1 and 3 but inverts the theming layer (it *adapts/translates and stores* source per-component, where pros *retheme tokens once and keep upstream*) and — the load-bearing miss — it selects its *source ingredients* by grepping text descriptions, the one selection that pros never do blind.

- Date: 2026-07-14
- Method: primary sources fetched and indexed this session (shadcn/v0 official docs; Vercel; practitioner writeups by Anna Arteeva/Design Systems Collective, Colin Matthews/Tech For Product, Addy Osmani, LogRocket, freedesignmd, shadcndesign). Every fetched claim is **[measured]** (I read the source say it this session), tool docs are **[vendor]**, my synthesis is **[inference]**, gaps are **[UNVERIFIED]**. Practitioner *opinions* are attributed inline — [measured] there means "I verified the author asserts this", not that it is a law of nature.
- Companion doc: `docs/research/shadcn-cli-vs-21st-cli.md` (CLI mechanics, 205-registry census, no-global-search finding, hallucination-proof `shadcn view`). This doc is the *workflow* layer on top of that CLI layer.

---

## TL;DR — decision matrix

| Practice | What the best practitioners actually do | Proposed workflow | Verdict |
|---|---|---|---|
| **Read-before-write** (avoid hallucinated props) | Pull real source/props via shadcn MCP, `shadcn view`, or skills *before* generating; the canonical failure is `<Button loading>` on a Button with no `loading` prop [measured, LogRocket] | (b) `shadcn view @ns/item` into context before writing | **KEEP — textbook-correct**, this is the single highest-value step |
| **Select source components** | **Visually** — v0 previews, gallery screenshots, marketplace thumbnails. Nobody picks a component from a text blurb | (a) keyword-grep name+title+description across ~205 registries | **CHANGE — this is the core flaw.** Text search finds *a* component, never the *good* one |
| **Constrain with a token contract** | Edit a *small* token set (radius, font, accent/primary, neutral, shadow) in `globals.css`/`tokens.css`; every shadcn component inherits it → "on brand by construction". Ship the tokens to the agent as DESIGN.md up front [measured, freedesignmd; vendor, v0] | (c) "ADAPT/translate the source to match DESIGN.md tokens" | **CHANGE — inverted.** Same-stack: retheme tokens once, don't rewrite each component. Rewriting forks upstream and loses fixes |
| **Multi-variant + pick** | Explorer tools (v0, Magic Patterns) spawn many variants on a canvas; screenshot + side-by-side + stakeholder walkthrough; visual selection because descriptions can't convey quality [measured, Arteeva] | (d) N screenshotted, labelled variants for human approval | **KEEP + ELEVATE — most aligned part**, make it the spine not a side-lane |
| **Framework translation** | For non-React, install from the *target-framework* registry (shadcn-svelte, etc.), same copy-in model. Hand/AI-translating polished React leaks React-isms (`asChild`, wrong composition) [measured, shadcn-svelte-mcp] | (c) "translate that source" to another stack | **CUT for cross-framework.** Translation is closer to an anti-pattern than a technique |
| **Store vs throwaway** | Same-stack install *is* storing (that's the shadcn model). But per-component *adapted forks* for a *prototype* are premature ownership | (c) "STORES the result in the project" | **CHANGE — split it:** store unmodified installs; keep adapted/translated forks throwaway until a variant is chosen |

**Bottom line:** the workflow is ~60% aligned. Its read-before-write (b) and variant-and-approve (d) match how good design engineers work. Its search (a) and its "adapt/translate + store" (c) optimize the wrong layer: component *quality is visual and compositional*, which (1) a description grep cannot surface and (2) token theming preserves but source rewriting destroys. Fix those two and it's genuinely senior-grade.

---

## 1. Component-registry-driven development: install-target vs idea-source

**The registry model, stated by the vendor.** shadcn's registry is "a distribution system for code" — "distribute your custom components, hooks, pages, config, rules and other files to any project," installed with one `npx shadcn add @<registry>/<component>` that auto-resolves cross-registry dependencies [vendor, ui.shadcn.com/docs/registry, /docs/directory]. Crucially: **"The registry works with any project type and any framework, and is not limited to React"** [vendor, ui.shadcn.com/docs/registry] — this reframes framework translation (§5).

**Do pros install as-is or adapt?** Both, but the *adaptation happens at the token layer, not the component layer* — and this is the distinction the proposed workflow blurs.

- **Same stack (React+Tailwind+shadcn) → install as-is, then retheme.** The whole point of the copy-in model is that the source lives in your repo so the agent has real context [measured, zenn/imaimai17468 via search]. You then reskin *via CSS variables*, not by editing each component (§2).
- **Registry components are increasingly *your own*.** The mature 2026 move is to publish an internal registry so v0/agents generate *from your adapted components* — Vercel positions the shadcn registry as the way "v0 generates prototypes that match your design system without manual overrides" [measured, search summary; vendor, v0 docs].
- **Screenshot-to-recreate is the low-fidelity idea-source path.** Colin Matthews (Tech For Product) ranks methods explicitly: pasting a screenshot gets "a visual approximation typically built with shadcn/ui… The AI has no knowledge of your actual components, tokens, or design system… you'll spend more time retrofitting the result to your design system than you saved. Best for: early exploration when you don't care about design system fidelity" [measured, techforproduct]. So screenshots = throwaway inspiration; real registry source = fidelity.

**[inference]** The install-vs-adapt question is a false binary in current practice. The pattern is: *install the primitive as-is, adapt the system via tokens, compose the layout fresh.* "Great" lives in the composition and the tokens, not in hand-edited forks of a Button.

## 2. Design-system-first / token workflows — the strongest signal in the whole corpus

This is the best-evidenced practice and where the proposed workflow most diverges from pros.

**The generic-shadcn problem is real and AI amplifies it.** freedesignmd's "shadcn trap": *"shadcn looks generic by default… the reason your AI app looks like every other AI app is almost certainly that you installed shadcn, accepted the defaults, and asked the agent to build from there… The agent is going to reach for the most common pattern in your code. Make sure the most common pattern is yours, not the default."* The fix is small and token-level: *"Edit five tokens and you keep the library and lose the look"* (radius, font, accent/primary, neutral) [measured, freedesignmd].

**"On brand by construction" — the mechanism that makes rewriting components pointless.** freedesignmd again: *"Once your CSS variables are different, every shadcn component the agent reaches for picks up your values automatically. That is the whole architecture. The agent does not have to know you customized anything. It generates a Button as usual, and the Button reads your radius, your font, your accent, and your neutral. The output is on brand by construction."* [measured, freedesignmd]. This is the direct counter-argument to workflow step (c)'s "adapt the source to match tokens": if the component reads tokens, you don't adapt the component — you set the tokens once.

**Ship the token contract to the agent up front.** The practice is a human-readable `DESIGN.md`/`design.md` declaring tokens "once… so any AI agent working in the project picks them up," plus tools (SeedFlip, tweakcn, shadcndesign generator) that "export your full design system (typography, color, radius, shadows, gradients) as a structured prompt you can paste straight into Cursor, v0, or Claude" [measured, search summaries; shadcndesign]. v0's own docs: overwrite colors in `tokens.css` "ensuring all the variable names remain unchanged," seed from `ui.shadcn.com/themes` or tweakcn [vendor, v0 design-systems].

**Does giving the token contract first measurably improve on-brand output?** The practitioner claim is yes and the *mechanism is deterministic*, not probabilistic: components consume CSS variables at runtime, so a correct token file makes primitives on-brand regardless of what the model "knew" [measured, freedesignmd; vendor, v0]. **[inference]** Caveat the proposed workflow must internalize: tokens fix *skin* (color/radius/type/shadow). They do **not** fix layout, spacing rhythm, hierarchy, density, or motion — which is precisely where "great" separates from "good." Token theming is necessary, not sufficient; the variant-and-pick loop (§4) is what covers composition.

## 3. Prior-art / reference-gathering / read-before-write

**Read-before-write is the documented cure for the #1 AI-UI failure.** LogRocket: *"You ask Claude Code or Cursor about a shadcn/ui component, and it'll confidently spit out props that don't exist… your agent might suggest `<Button loading={true}>` even though shadcn/ui's Button has no `loading` prop… it guesses because it has almost zero library context."* Fix: shadcn MCP / `view` / skills give "real, live access to the component library instead of making it wing it," yielding "no hallucinated prop names, no wrong import paths" [measured, LogRocket; vendor, ui.shadcn.com/docs/mcp, /docs/skills]. **Workflow step (b) is exactly this and is unambiguously correct.**

**Screenshots into the model — yes, but as low-fidelity input.** Every explorer tool accepts screenshot-to-code (v0 "Screenshots and Files", Design Mode; Lovable/Bolt) [measured, v0 docs; search]. Pros use it for *layout intent*, not fidelity (§1).

**Storybook MCP** exposes `list_components`, `get_component_props`, `get_component_source`, plus screenshots — a component-metadata channel for teams already on Storybook, flagged "highly experimental" [measured, techforproduct].

**Trust-lists over blind search.** shadcn deliberately has **no global search** — you must name a namespace [measured, companion doc]. Practitioners treat this as a feature: hard-code a vetted namespace shortlist (`@shadcn`, `@magicui`, `@ai-elements`…) so a blind agent never lands on an unmaintained community upload [inference, companion doc §3]. This is the direct tension with workflow step (a), which greps *all* ~205 registries.

## 4. Multi-variant prototyping — the part the workflow should build *around*

**Explorer vs builder is an explicit industry split.** Anna Arteeva: v0 and Magic Patterns are *explorers*; Bolt is a *builder* ("generates one output per prompt… it is a builder, not an explorer"). Magic Patterns: *"You can spin up lots of variations of the same idea, place them on a canvas and compare them side by side… walk stakeholders through multiple options in one place"* [measured, Arteeva]. Lovable adds click-to-target visual edits [measured, DSC].

**Selection is visual, and that is the whole point.** The reason these tools screenshot and canvas variants is that *you cannot judge UI quality from text*. This validates workflow step (d) and is the strongest argument that step (a)'s text-grep selection is under-powered: the workflow is willing to screenshot its *own outputs* for the human but picks its *inputs* sight-unseen. **[inference]** A senior engineer would make the visual loop symmetric — preview candidate components before adopting them, not only preview the final variants.

**A named 2026 pipeline:** explore directions in a generator (Stitch/v0/Magic Patterns) → refine the winner in Figma → build in Lovable/Bolt/Cursor [measured, search summary]. Note the shape: *diverge visually first, converge to code second.*

## 5. Framework translation — install-target, not idea-source

**Official shadcn is React-only; ports exist but are separate registries, not translations.** "The official project targets React frameworks… You'll find community ports for Vue, Svelte, and Flutter, but those aren't maintained by the core team." shadcn-svelte (7,500+ stars) follows the *same copy-in philosophy with its own CLI/registry* — you install Svelte components, you do not port React ones [measured, search; shadcn-svelte docs]. And because the registry protocol is framework-agnostic (§1), the correct *install-target* for a Svelte project is a Svelte registry item.

**Hand/AI translation of polished React is a documented failure mode.** From the shadcn-svelte-MCP writeup: *"even when given the shadcn-svelte docs, assistants would still respond with React-oriented shadcn/ui patterns, which usually meant wrong props, wrong composition patterns, or React-only concepts sneaking into Svelte code"* — the mitigation is to force "Svelte 5 + shadcn-svelte only (no React patterns)" and, better, use a framework-specific MCP/registry [measured, shadcn-svelte-mcp]. **[inference]** Translating a *polished* React component to another framework is where craft leaks out: you inherit React idioms (`asChild`, render props, RSC assumptions) that have no clean target-framework equivalent, and you lose the port maintainers' idiomatic version. Treat registry components as **install-targets within their stack**, and as **idea-sources** (structure/layout, fed as reference) across stacks — never as source to mechanically translate.

---

## Verdict on the proposed `/prototype` workflow — item by item

**(a) `shadcn-index` global keyword search across ~205 registries — CHANGE (keep the index, fix the selection).**
Filling shadcn's no-global-search gap with a local index is genuinely useful and correct [measured, companion doc]. But keyword-matching name+title+description **cannot surface the *good* component** — registry descriptions are SEO-flat ("A beautiful, accessible button") and quality is visual/compositional. This is the workflow's central naïveté: it selects ingredients by text in a domain where pros select by sight. Two concrete fixes: (1) rank/filter against a **curated trust-list of namespaces** rather than grepping all 205 blind (a blind global pile optimizes for whoever wrote the best description, not the best component); (2) attach a **visual preview** to candidates before adoption — most registries publish demo/preview URLs or Open Graph thumbnails; surface those, or render the item, so the human (or a vision pass) picks visually. Text search narrows to a shortlist; it must not be the final selector.

**(b) `shadcn view @ns/item` to pull real source before writing — KEEP, unchanged.**
This is the textbook read-before-write cure for hallucinated props [measured, LogRocket; vendor, shadcn docs]. Highest-value step in the whole workflow. Works with no project/no components.json [measured, companion doc]. Nothing to change.

**(c) "ADAPT/translate source to DESIGN.md tokens and STORE in project" — CHANGE substantially; this is where the workflow is most wrong.**
Three separate problems folded into one step:
- *Adapt-to-tokens (same stack):* **inverted.** You don't rewrite a shadcn component to "match" tokens — it already reads CSS variables, so you set the token file once and every component is on-brand by construction [measured, freedesignmd]. Per-component adaptation is wasted work that forks you off upstream and forfeits future fixes. Replace with: *ensure DESIGN.md tokens are written to `globals.css`/`tokens.css`; install primitives unmodified.*
- *Translate (cross framework):* **cut.** Mechanical translation leaks React-isms and loses the port's idioms [measured, shadcn-svelte-mcp]. If the target isn't React, pull from the target-framework registry; if none exists, use the React source as a *reference for structure*, generated fresh with the target framework's own MCP/skills — not translated line-by-line.
- *Store in project:* **split.** Unmodified same-stack installs *should* be stored (that is the shadcn model). But an *adapted/translated fork* produced during a prototype is premature ownership — keep it throwaway until a variant is chosen; only promote-to-stored after human approval. Storing every experimental fork turns a prototype into a maintenance liability.

**(d) N screenshotted, labelled variants for human approval alongside `/impeccable` lanes — KEEP and ELEVATE.**
Most aligned with how explorer tools and design engineers actually work [measured, Arteeva]. Visual selection is *necessary*, not decorative, precisely because descriptions can't convey quality — which is also the argument that (a) is under-powered. Make this the spine of the command, not a parallel lane: diverge into visual variants, converge to code after the human picks.

### What a senior AI-design engineer would ADD
1. **A visual preview step on the *input* side** — screenshot/render candidate components before adoption, mirroring the output-side screenshotting the workflow already does. Symmetry is the fix for (a).
2. **Token-contract-first, enforced** — write/verify `globals.css` tokens from DESIGN.md *before* any generation, so primitives are on-brand deterministically; reserve the model's effort for layout/hierarchy/motion where tokens don't reach.
3. **A composition pass separate from the skin pass** — tokens give a branded skin; a `/impeccable`-style critique of spacing rhythm, hierarchy, density, and motion is what turns "good" into "great." Bake it in.
4. **Trust-list + namespace scoping** for search, not a blind 205-registry grep.

### What they would CUT
1. **Cross-framework source translation** (anti-pattern; pull from target-framework registries or regenerate from reference).
2. **Per-component "adapt to tokens" rewriting** (redundant with CSS-variable theming; forks off upstream).
3. **Storing adapted/translated forks during the prototype phase** (premature; keep throwaway until chosen).

---

## Sources

Primary — vendor docs (fetched this session):
- ui.shadcn.com/docs/registry, /docs/directory — "distribution system for code," any-framework, one-command install **[vendor]**
- ui.shadcn.com/docs/theming, /docs/mcp, /docs/skills — CSS-variable tokens; MCP read-before-write; machine-readable skills **[vendor]**
- v0.app/docs/design-systems (+ legacy) — custom registry + `tokens.css` for high-fidelity brand UI; overwrite colors, keep variable names; seed from ui.shadcn.com/themes or tweakcn **[vendor]**

Primary — practitioner writeups (fetched and read this session; assertions are the authors', verified present):
- freedesignmd.com/blog/shadcn-looks-generic — "shadcn looks generic by default," five-token fix, "on brand by construction" **[measured — author asserts]**
- blog.techforproduct.com (Colin Matthews) — ranked import methods; screenshots = low-fidelity idea-source; Storybook MCP metadata channel **[measured]**
- blog.logrocket.com/ai-shadcn-components — `<Button loading>` hallucination; MCP gives "no hallucinated prop names" **[measured]**
- Anna Arteeva (annaarteeva.medium.com; Design Systems Collective) — explorer-vs-builder (v0/Magic Patterns vs Bolt); canvas-of-variants selection; Lovable click-to-target **[measured]**
- dev.to/dev_michael — shadcn-svelte-MCP; assistants leak React patterns into Svelte even with docs **[measured]**
- shadcndesign.com theme generator; SeedFlip/tweakcn (via search) — tokens-as-prompt export **[measured — via search summary]**
- Companion in-repo: `docs/research/shadcn-cli-vs-21st-cli.md` — no global search, 205-registry census, `shadcn view` full-source **[measured, prior session]**

Unverified / not checked:
- v0 "Design Systems 2.0" page rendered identically to the legacy page on fetch (SPA/redirect); the *current* 2.0 specifics beyond "register a custom registry + tokens" **[UNVERIFIED]**
- Whether a vision-model pass on preview thumbnails reliably out-selects text search — asserted by analogy to human practice, not measured here **[UNVERIFIED / inference]**
- Quantified lift from token-contract-first vs no-tokens generation — mechanism is deterministic but no A/B measured this session **[UNVERIFIED]**
