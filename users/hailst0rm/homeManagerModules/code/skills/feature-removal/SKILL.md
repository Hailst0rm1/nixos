---
name: feature-removal
description: Surgically remove a named feature, route, flag, endpoint, or product surface from a codebase, branch, or open PR — and prove nothing is left behind. Use when the user says "remove/delete/rip out X", "deprecate/disable/sunset X", "roll back X", "drop support for X", "take X out of this PR", or "we're not shipping X anymore". Builds a removal manifest, discovers every surface (UI, routes, API, jobs, flags, analytics, schema, deps, docs, generated artefacts, build output), removes only what's listed while preserving adjacent behaviour, and gathers independent evidence of absence. For audit-only requests, or a second adversarial opinion that a feature is truly gone, use removal-audit. Works for JS/TS, Python, monorepos, API services, frontends, and package libraries.
---

# Feature Removal

Removing a feature is fundamentally an **absence-proof** problem. A passing test suite tells you what still works; it does not tell you that the thing you deleted is truly gone. Features leak across many surfaces — UI, routes, API handlers, background jobs, feature flags, analytics events, permissions, DB schema, dependencies, lockfiles, docs, i18n, fixtures, generated clients, and committed build output. Deleting the visible UI and stopping there is the single most common failure. So the discipline here is: **enumerate every surface up front, remove only what you listed, and let evidence — not your own narrative — decide whether it's gone.**

Two more principles shape the work:

- **Evidence beats narrative.** "I removed it" is a claim. A clean `rg` sweep, a green dead-code tool, and a 404 on the old route are evidence. Produce the evidence.
- **The deleter shouldn't be the sole judge.** For anything non-trivial, the same context that performed the deletion is biased toward believing it's complete. Get an independent absence check (see Session/Role guidance, and `removal-audit`).

A companion principle pulls the other way and matters just as much: **don't over-delete.** Adjacent, accepted behaviour often shares files, modules, and tests with the feature. Preserve it deliberately. Over-deletion is how a "clean removal" silently breaks a neighbouring flow.

## When to use

- "Remove / delete / rip out / excise the X feature."
- "Deprecate / disable / roll back / sunset X."
- "Drop support for X", "we're not shipping X anymore."
- "Take X out of this PR" (revision, not rewrite — see Phase 0).
- Simplifying a surface by removing a sub-feature, route, endpoint, flag, or experiment.

## When not to use

- **Audit only, no mutation** ("is X really gone?", "find dead code", "what's orphaned?") → use `removal-audit`.
- **Pure refactor / rename** with no feature being removed → ordinary refactoring workflow.
- **The removal semantics are a product decision** you can't answer (data retention, backwards compatibility, migration) → stop and get the decision first (Phase 0, route 3).

## Context & safety

Gather a **bounded, relevant** slice of context — not the whole repo. Large context dumps bury the signal and slow everything down.

**Gather:** the issue/PR title, body, and comments; branch/base/head metadata; repo docs if present (`README`, `AGENTS.md`, `CLAUDE.md`, `PRODUCT.md`, `DESIGN.md`, ADRs); the source files relevant to the feature; package scripts and check commands; the existing diff if revising an open PR; existing tests and fixtures; and safe search/tool output.

**Never read, print, store, or include secrets.** This is non-negotiable and applies to every phase: `.env` files, tokens, API keys, credentials, cookies, auth/session files, OAuth callbacks carrying secrets, and secret-bearing logs. If a file you need to edit also contains secrets, edit by line/anchor without echoing the secret-bearing lines into your output. Do not paste raw agent transcripts; if you must reference one, redact it first.

## Workflow

### Phase 0 — Intake and route

Decide which situation you're in before touching anything:

1. **Existing PR revision.** Keep the existing PR branch/worktree where safe. Preserve accepted adjacent fixes already on that branch. Do **not** hard-reset or rebuild the PR from base — that throws away reviewed work. Treat this as editing a diff, not writing a new one.
2. **New implementation task.** Work on an isolated branch/worktree. Scope the removal from the issue/acceptance criteria.
3. **Underspecified product decision.** If the removal affects user-visible behaviour, compatibility, data retention, or migration strategy and the intended semantics aren't stated, **stop and ask/record the decision.** Don't guess whether an old endpoint should 404, 410, redirect, or keep a compatibility shim — that's a product call (see Phase 5).
4. **Audit-only / no mutation requested.** Route to `removal-audit`.

### Phase 1 — Context boundaries

Pull exactly the allowed context listed under **Context & safety** above, and nothing forbidden. Stop when you have enough to write the manifest — you'll discover the rest during the scout pass, not by reading everything now.

### Phase 2 — Removal manifest (before any mutation)

Write a manifest before editing. It is simultaneously your **implementation map** and your **final audit checklist** — the same list you delete from is the list you later prove empty. Save it as `removal-manifest.yaml` (or inline if small).

```yaml
feature:
  id: old-feature
  human_name: Old Feature
  reason_for_removal: product simplification / bug / deprecation / scope change
  linked_issue_or_pr: null
  risk_tier: standard | high-risk | cross-repo
  removal_mode: delete | disable | deprecate | replace | existing-pr-revision

terms:                      # every spelling/casing the feature appears under
  names: [oldFeature, OldFeature, old-feature, OLD_FEATURE]
  route_slugs: []
  api_paths: []
  config_keys: []
  env_vars: []
  feature_flags: []
  analytics_events: []
  permission_keys: []
  package_names: []
  db_terms: []
  copy_strings: []

surfaces_to_remove:
  ui: []
  routes: []
  api: []
  schema_migrations: []
  jobs_cron_queues: []
  exports_modules_barrels: []
  flags_env_config: []
  analytics_permissions: []
  tests_fixtures_mocks: []
  docs_storybook_i18n_assets: []
  generated_clients_artifacts: []
  dependencies_lockfiles: []

preserve:                   # adjacent accepted behaviour you must NOT break
  behaviours: []
  files_or_modules: []
  tests_or_flows: []
  product_invariants: []

absence_proofs:             # how you'll prove each surface is gone
  static_searches: []
  static_tools: []
  route_api_checks: []
  ui_checks: []
  dependency_checks: []
  build_artifact_checks: []
  cross_repo_checks: []

open_questions: []
```

### Phase 3 — Inventory / scout pass (non-mutating)

Before deleting, discover every surface. **Adapt commands to the repo's actual stack and package manager** (detect from the lockfile and scripts — `references/tooling.md` owns the detection rules and full command matrix). The essentials:

```bash
# Universal term sweep (use every spelling from the manifest)
rg -n "oldFeature|OldFeature|old-feature|OLD_FEATURE"
rg -n "/old-feature|/api/old-feature"

# Route / API surface (pick the ones matching the stack)
rg -n "router\.(get|post|put|patch|delete)\(|app\.(get|post|put|patch|delete)\("
rg -n "@(Get|Post|Put|Patch|Delete)\(|export async function (GET|POST|PUT|PATCH|DELETE)"
rg -n "@app\.route|@router\.(get|post|put|patch|delete)"          # Python (Flask/FastAPI)
rg -n "Route path=|createBrowserRouter|href=.*feature|to=.*feature" # frontend routing

# Dead-code / dependency graph (JS/TS)
npx knip --include files,exports,dependencies,devDependencies,unlisted
npx ts-prune ; npx depcheck ; npx madge src --extensions ts,tsx --orphans

# Dead-code (Python)
ruff check . ; vulture src tests --min-confidence 80

# Committed build output / generated artefacts
rg -n "oldFeature|OldFeature|old-feature|OLD_FEATURE" dist build .next out coverage
```

As you discover surfaces, **fill the manifest** — don't delete yet. The scout pass exists to make the manifest complete so the implementer deletes from a known, bounded list.

### Phase 4 — Session / role model

Match rigour to risk. The point is to keep an **independent** check on absence for anything non-trivial — the deleter is biased toward "done."

- **Small / low-risk** (one isolated surface, no schema/auth/runtime impact): a single session is fine, but the manifest and the final absence checklist are still mandatory, and the final self-check must be explicit (don't hand-wave "looks clean").
- **Medium:** split read-only inventory/scout from the mutating implementer.
- **High-risk** (auth, payments, customer data, schema, cross-repo, large blast radius): split into distinct roles — inventory scout (read-only), implementer (mutating), absence auditor (read-only/adversarial — use `removal-audit`), runtime/UX QA, plus security and UI reviewers when those facets apply.

For high-risk removals, spawn a dedicated agent team — inventory scout (read-only) · implementer (mutating) · adversarial absence auditor (`removal-audit`) · runtime QA · security reviewer · UI reviewer. See `references/high-risk-team.md` for the role-by-role spawn prompt.

### Phase 5 — Implementation rules

The implementer:

- Deletes **only** manifest-listed surfaces — or updates the manifest first when a new surface is found. The manifest is the contract.
- **Preserves** everything on the `preserve` list. When a file mixes feature code with adjacent accepted code, edit surgically; don't delete the file.
- **Pivots tests rather than deleting them.** A test that asserted feature behaviour should be rewritten to assert the post-removal behaviour (e.g. the route now 404s, the flag no longer exists). Deleting the test instead silently drops the guarantee.
- Adds **negative tests** for removed routes/API/flags/events where behaviour matters.
- Handles schema by merge status: if a **shipped** migration introduced the schema, add a new migration to remove it per repo policy; if an **unmerged** migration introduced it, prefer editing that migration surgically rather than stacking a follow-up removal migration (unless repo policy forbids editing it).
- **Specifies the endpoint contract explicitly** — 404 (gone, no trace), 410 (gone, intentional), redirect, or compatibility shim. This is a product decision; if unstated, it's an open question, not a guess.
- Prunes unused dependencies **and** lockfile entries.
- Regenerates generated clients/specs/assets rather than hand-editing them.
- Runs the project's checks and produces concise implementation evidence.

### Phase 6 — Absence-proof gates

These are the gates that turn "I think it's removed" into evidence. Run the ones that apply to the stack and surfaces touched (full matrix in `references/tooling.md`).

**Always:** manifest complete · final `rg` sweep over every term comes back empty (or only expected leftovers) · tests/checks pass · diff reviewed for accidental over-deletion · every `preserve` item verified intact.

**JS/TS:** `tsc --noEmit`, lint, test, build · Knip for unused files/exports/deps · Semgrep or ast-grep for feature-specific banned patterns · dependency-cruiser/madge when graph evidence helps.

**Python:** ruff · vulture · compile/type/test checks where present · framework route scans · Semgrep for decorators/routes/imports/config.

**UI:** nav no longer exposes the feature · direct URLs fail safely · adjacent flows still work · layout leaves no holes/blank states · screenshots captured.

**API:** endpoint removed or intentionally returns the chosen status (404/410/redirect/shim) · generated specs/clients updated · negative tests pass.

**Runtime/jobs:** cron/job/queue registration removed · producers/consumers/topics/events removed · workers start cleanly.

**Build artefacts:** production build passes · generated output searched for manifest terms · bundle analyser if the feature carried significant client weight.

**Cross-repo / high-risk:** GitHub code search / Sourcegraph / CodeQL if available · document any external references you could not verify.

### Phase 7 — Evidence output

Produce a PR/comment using this template. The point is that a reviewer can see the *evidence*, not just trust the summary.

```markdown
## Feature removal evidence

### Removed
- ...

### Preserved (adjacent behaviour kept intact)
- ...

### Manifest terms checked
- ...

### Absence proofs
- `rg`: <terms swept, result>
- static tools: <knip/ts-prune/vulture/... output summary>
- dependency graph / dead-code: ...
- route/API checks: <status codes, negative tests>
- build artefact search: ...
- UI/runtime QA: <evidence/screenshots>

### Tests / checks
- ...

### Intentional leftovers / compatibility shims
- <e.g. 410 on /old-feature kept until v3; reason>

### Risks / follow-ups
- ...
```

## Common pitfalls

- Deleting only the visible UI; leaving API/routes/jobs/flags/events behind.
- Leaving fixtures, mocks, Storybook stories, i18n strings, docs, or assets.
- Trusting green tests as proof of absence — they prove presence of what remains, not absence of what you removed.
- Ignoring generated clients/specs and committed build output.
- Treating an existing-PR revision as a fresh branch (losing reviewed adjacent work).
- Stacking a follow-up migration to remove schema an unmerged migration introduced.

## Verification checklist

- [ ] Routed correctly in Phase 0 (PR revision vs new vs product-decision vs audit-only).
- [ ] No secrets read, printed, stored, or included.
- [ ] Manifest written before mutation; covers terms, surfaces, preserve, absence proofs.
- [ ] Scout pass completed; manifest reflects all discovered surfaces.
- [ ] Role/session rigour matches risk tier; independent absence check for non-trivial work.
- [ ] Only manifest-listed surfaces removed; every `preserve` item intact.
- [ ] Tests pivoted (not deleted); negative tests added where behaviour matters.
- [ ] Schema/deps/lockfiles/generated artefacts handled.
- [ ] Endpoint contract (404/410/redirect/shim) explicit.
- [ ] Absence-proof gates for the stack/surfaces all run and clean.
- [ ] Evidence output produced.

## Related

- **`removal-audit`** — the independent, adversarial absence auditor. Run it after implementation (or as Agent 3 above) for any high-risk removal, and for any "is it really gone?" / dead-code / hygiene question that doesn't involve mutation.
