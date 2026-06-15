---
name: removal-audit
description: Audit a codebase, branch, PR, package, or module for leftover artefacts, dead code, unused exports/files/dependencies, orphaned routes, stale config/env/feature flags, unused tests/fixtures/mocks, dead docs/i18n/assets, generated-artefact drift, committed build output, and stale public API entries. Use whenever the user says "is X really gone?", "find dead code", "what's unused/orphaned?", "any loose dependencies?", "audit this branch for leftovers", "clean up the codebase", or wants an independent, adversarial second opinion that a removal is complete. Two modes: targeted (prove a named feature/route/package has zero residual artefacts) and general hygiene (rank dead-code/dependency findings, no target). Default is read-only and evidence-based: findings carry confidence levels, and dynamic frameworks, public APIs, and generated files are respected, not called dead. If it becomes an active named removal, switch to feature-removal. Works for JS/TS, Python, monorepos, and API/frontend/library projects.
---

# Removal Audit

This skill proves (or disproves) **absence**. Whether you're confirming a feature was fully removed or hunting general rot, the job is the same: gather evidence, classify it honestly, and report — not delete. Two biases make audits go wrong, and the whole design fights them:

- **Confirmation bias** — wanting the removal to be "done", so ambiguous evidence gets read as clean. Counter it by classifying every finding with explicit confidence and by treating "no local import" as a *clue*, not a verdict.
- **Over-eager deletion** — calling something dead because *you* can't see its caller. Public package APIs, framework entrypoints (routes, CLI commands, migrations, event handlers), reflection/dynamic-import targets, plugin registrations, and generated files routinely have **no visible local reference** and are still very much alive. Treat these as alive-by-default unless proven otherwise.

So the default posture is **read-only**: produce an evidence-backed report with confidence levels. Mutate only when the user explicitly asks for cleanup — and even then, in small verified batches.

## When to use

- "Is the X feature/route/package really gone?" (targeted residue audit)
- "Find dead code / unused exports / orphaned files."
- "Any unused or loose dependencies?" / "dependency hygiene."
- "Audit this PR/branch/module/package for leftovers."
- "Clean up the codebase" (audit first, then optional cleanup).
- As the **independent absence auditor** after a `feature-removal` (especially high-risk).

## When not to use

- **You're actively removing a named feature and will mutate code** → use `feature-removal`. Come back here for the independent absence check.
- The request is a pure code review for bugs/quality, not deadness/leftovers → ordinary review.

## Context & safety

Gather a bounded, relevant slice — repo docs, build/test config, package manifests, the source tree, tests/fixtures/mocks, CI config, generated specs/clients if safe, and tool output. Don't dump the whole repo into context; scope to the audit's roots and target.

**Never read, print, store, or include secrets** — `.env` files, tokens, API keys, credentials, cookies, auth/session files, OAuth callbacks carrying secrets, secret-bearing logs. If a finding sits in a secret-bearing file, reference it by path and line without echoing the secret.

## Workflow

### Phase 1 — Determine audit mode

Infer or ask:

- Targeted removal-residue audit, or general dead-code/dependency audit?
- Scope: whole codebase, a PR/branch, a single package/module, one language?
- Output: read-only report (default) or a cleanup PR?

If unclear, **default to a read-only report.** A report is cheap to act on; an unwanted deletion is not.

### Phase 2 — Build the audit manifest

**Targeted mode** — mirror the term-discipline of `feature-removal` so the two skills line up:

```yaml
audit:
  mode: targeted
  target: old-feature
  terms: []              # every spelling/casing
  paths: []
  routes: []
  packages: []
  flags_env_config: []
  events_permissions: []
  expected_absent: true
```

**General mode**:

```yaml
audit:
  mode: general
  roots: [src, app, packages, tests]
  exclude: [node_modules, .git, dist, build, .next, coverage]
  categories:
    - unused_files
    - unused_exports
    - unused_dependencies
    - orphan_routes
    - stale_flags_env_config
    - stale_tests_fixtures_mocks
    - stale_docs_assets_i18n_storybook
    - generated_artifact_drift
```

### Phase 3 — Run the tooling matrix

**Adapt to the repo's real stack and package manager** — never blindly run `npm`/`pip`; detect the lockfile and scripts first. No single tool is authoritative; cross-check static search, dead-code analysis, and dependency graph. If a tool isn't present, run it via the package runner only when safe, or record it as unavailable. Full matrix in `references/tooling.md`; essentials:

```bash
# Universal
rg -n "<target terms>"            # targeted mode
rg --files                        # inventory for general mode

# JS/TS
npx knip                          # the workhorse: files, exports, deps in one pass
npx knip --production
npx ts-prune ; npx depcheck
npx madge src --extensions ts,tsx --orphans
npx madge src --extensions ts,tsx --circular
npx dependency-cruiser src
npx tsc --noEmit ; npm run lint ; npm test ; npm run build

# Python
ruff check . ; vulture src tests --min-confidence 80
python -m compileall . ; pytest ; mypy . ; pyright

# Build / generated artefacts
rg -n "<target terms>" dist build .next out coverage

# Dependency tree (confirm orphan before recommending removal)
pnpm why <pkg> | npm ls <pkg> | yarn why <pkg>
uv pip tree | pipdeptree | poetry show --tree
```

Use **Semgrep / ast-grep** for structural patterns a term sweep misses: removed imports, route decorators, feature-flag calls, analytics events, config lookups, permission constants, public-API entries. For cross-repo / high-risk, reach for GitHub code search, Sourcegraph, or CodeQL where available.

### Phase 4 — Classify every finding

Each finding gets one classification and a confidence level. The classification *is* the bias control — it forces you to name when something only *looks* dead.

```
confirmed-dead              # no references anywhere; tools + search agree
likely-dead                 # strong evidence, minor uncertainty
suspicious-needs-human-review
intentional-public-api      # exported for consumers; absence of local refs is expected
framework-dynamic-entrypoint# route/CLI/migration/handler/DI — invoked by framework
generated-do-not-edit       # codegen output; fix the source/generator, not the file
false-positive
```

Record per finding:

```
- item: <file path / symbol / package / route / config key>
  evidence: <tool output, search result, graph fact>
  why_it_appears_dead: <reasoning>
  confidence: high | medium | low
  classification: <one of the above>
  recommended_action: <delete | keep | investigate | regenerate>
  risk_of_removal: <what breaks if wrong>
  validation_needed: <what would raise confidence>
```

### Phase 5 — Bias controls

- **Don't call a public API dead** just because local imports are absent — that's the whole point of a public API. Check package `exports`/`__all__`/`index` barrels and the consumer surface.
- **Don't assume framework entrypoints are unused** — routes, CLI commands, migrations, scheduled jobs, event/message handlers, and DI-registered classes are invoked by the framework, not by a visible import.
- **Treat dynamic imports, reflection, and string-keyed lookups as lower confidence.** A symbol referenced via `import(name)` or `getattr` won't show in a static graph.
- **Check the full surface**, not just source: tests, generated clients, docs, config, CI, routes, env vars, package exports.
- **Compare against a baseline** when the repo has known existing noise — report only the *delta* the change introduced, so pre-existing dead code doesn't drown the signal.
- **Use independent review for high-confidence deletion batches.** The finder and the prover shouldn't be the same pass for anything risky.
- **Report first, clean up second.**

### Phase 6 — Output report

```markdown
# Removal / dead-code audit report

## Scope
- Mode: targeted | general
- Target:
- Roots scanned:
- Exclusions:
- Tools run:

## Executive summary
- Confirmed dead: N
- Likely dead: N
- Suspicious: N
- Intentional / public API: N
- False positives: N

## Findings

### Confirmed dead
| Item | Evidence | Recommended action | Risk |
|---|---|---|---|

### Likely dead
...

### Suspicious / needs human review
...

### Dependency findings
...

### Route / API / config findings
...

### Build / generated artefact findings
...

## Suggested cleanup plan
1. Safe mechanical removals
2. Test updates (pivot, don't just delete)
3. Dependency / lockfile cleanup
4. Generated artefact regeneration
5. QA / build verification

## Commands / evidence
```text
...
```

## Caveats
- Dynamic / plugin / framework / public-API entries excluded from "dead".
- Unverified external/cross-repo references.
```

### Phase 7 — If cleanup is requested

- For a **targeted removal**, hand off to `feature-removal` — it owns the manifest-driven mutation, test-pivoting, and absence-proof gates.
- For **general hygiene cleanup**, build a conservative plan and remove in **small batches**, running tests between batches.
- Keep public-API and dynamic-framework entries unless removal is explicitly approved.
- Produce PR evidence (same spirit as the `feature-removal` evidence template).

## Common pitfalls

- Treating every unused export as safe to delete (ignores public package API).
- Ignoring dynamic / framework registration (routes, CLI, migrations, handlers).
- Deleting generated files by hand instead of fixing the generator/source.
- Deleting tests that encode intended behaviour instead of pivoting them.
- Ignoring dependency lockfiles.
- Not searching committed build output.
- Failing to separate report mode from cleanup mode (mutating when asked to audit).
- Overloading one agent/session with both finding and proving — the deleter is biased.

## Verification checklist

- [ ] Mode and scope established; defaulted to read-only report when unclear.
- [ ] No secrets read, printed, stored, or included.
- [ ] Manifest built (targeted terms or general categories).
- [ ] Tooling adapted to the repo's real stack; multiple cross-checks, not one tool.
- [ ] Every finding classified with confidence and recommended action.
- [ ] Public APIs, framework entrypoints, dynamic/reflection, and generated files protected from false "dead" verdicts.
- [ ] Baseline/delta considered where the repo has existing noise.
- [ ] Report produced before any cleanup; cleanup (if any) done in verified batches.

## Related

- **`feature-removal`** — use it whenever the audit becomes an active, named removal that mutates code. It owns the removal manifest, surgical deletion, test pivoting, schema/dependency handling, and the absence-proof gates. This skill is the read-only, adversarial counterpart that proves the removal landed.
