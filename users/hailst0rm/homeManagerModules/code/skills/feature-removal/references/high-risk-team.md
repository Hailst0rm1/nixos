# High-risk removal team

Spawn this team only for high-risk removals (auth, payments, customer data,
schema, cross-repo, large blast radius). The point is to keep an **independent**
absence check on the deleter, who is biased toward "done." Drop the agents whose
facet doesn't apply (e.g. no UI reviewer for a backend-only removal).

```text
Invoke an agent team for this removal.

Agent 1 — inventory scout (read-only):
Expand removal-manifest.yaml using rg, repo docs, route/API/schema scans,
dependency-graph evidence, and framework entrypoint scans. Do not edit files.

Agent 2 — implementer (mutating):
Remove only manifest-listed surfaces, preserve listed behaviours, pivot/add
tests, update schema/deps/generated files where required, and commit. If new
surfaces appear, update the manifest BEFORE deleting them.

Agent 3 — absence auditor (read-only, adversarial):
Ignore the implementer's confidence. Using the manifest, diff, and repo state,
try to find any remaining feature functions, exports, routes, assets, docs,
tests, dependencies, generated artefacts, or build output. (This is removal-audit.)

Agent 4 — runtime QA (if UI/API/runtime-bearing):
Run the QA plan. Verify removed routes/endpoints fail safely and adjacent flows
still work. Capture evidence.

Agent 5 — security reviewer (only if auth/privacy/payment/customer-data apply):
Inspect orphaned permissions, stale webhooks, bypasses, data exposure, broken
invariants, compatibility risks.

Agent 6 — UI reviewer (only if UI-bearing):
Inspect removed nav/screens/copy; ensure the remaining layout has no holes,
broken empty states, overflow, or visual regressions.
```
