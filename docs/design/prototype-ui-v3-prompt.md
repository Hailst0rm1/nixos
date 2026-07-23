# UI-prototype session prompt (v6)

Session-1 prompt of the dev-orchestrator `ui_bearing` lane. After auditing
against `/impeccable` (shape/critique references, DESIGN.md contract) and
`/prototype`, exactly one addition to the existing prompt survived:
**component mining**, plus carrying the ingredient list in the `/handoff`.
Everything else proposed earlier already exists in the stack:

- DESIGN.md is `/impeccable`'s artifact — frontmatter tokens + named rules +
  do's/don'ts + absolute bans. It already is the project-specific gradable
  contract; a generic rubric would flatten it.
- Scored evaluation is `/impeccable critique` (Nielsen heuristics 0–40,
  P0–P3, browser evidence), owned by the session-3 review gate; QA owns
  runtime evidence. Session 1 adds no review layer.

---

## The prompt

Prototype the requested UI. Use `/impeccable shape` for the DESIGN.md-faithful
baseline, then `/prototype` for structurally distinct alternatives under the
same visual language. Use `/imagegen` when the prototypes need original
imagery or visual assets.

Between shape and prototype, mine real component source as ingredients for
the variants:

- `shadcn search` scoped to `@shadcn @magicui @aceternity @cult-ui
  @react-bits @kokonutui @animate-ui @motion-primitives @shadcnblocks`;
  widen only if the shortlist fails.
- Search shortlists, reading decides: `shadcn view @ns/item` on every
  candidate before using it.
- Same stack: `shadcn add -y` and leave the installed source untouched —
  the project's tokens brand it. Other stacks: install from the target
  framework's registry (shadcn-svelte, shadcn-vue, …); if none fits, treat
  the React source as a structure reference and write idiomatic
  target-framework code from scratch.
- From the 21st CLI use only `21st logo`; install 21st items through shadcn.
- Done when each variant's ingredient list of `@ns/item` sources is written
  down.

Run the variants, capture labelled screenshots, and present trade-offs and
a recommendation for approval. The `/handoff` carries the approved variant
and its `@ns/item` ingredient list for the build session.

## Provide with this prompt

- Issue URL and acceptance criteria
- Repo path and base branch
- Task artefact mirror path

---

## Traceability (doc-only, not part of the prompt)

| Element | Source |
|---|---|
| Trust-list scoping; `shadcn view` read-before-write | shadcn Skills/CLI v4 docs; LogRocket hallucinated-props failure; in-repo `docs/research/shadcn-cli-vs-21st-cli.md` |
| Install untouched, tokens brand it | freedesignmd "on-brand by construction"; v0 design-systems docs |
| Regenerate idiomatically cross-stack | shadcn-svelte-mcp React-leak evidence; Sveno transpiler limits |
| `21st logo` only; installs via shadcn | measured CLI source: `21st add` puts the API key in npx argv; free-tier search returns upsell payloads |
| Ingredient list in the handoff | build session (`/tdd + /impeccable craft`) consumes real sources instead of re-searching |
| Rubric/evaluator additions dropped | `/impeccable critique` + DESIGN.md named rules already embody the generator/evaluator pattern; review/QA gates own it |
