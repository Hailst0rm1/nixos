---
name: qa-plan
description: Run or plan runtime QA for freshly built work. Use when an implementation needs browser or service evidence, responsive screenshots, or a manual verification checklist before delivery.
---

# QA Plan

Verify the current build as a person uses it and leave durable evidence. The
repository's workflow owns the scope, bounds, report shape and delivery rules.

## 1. Resolve the contract and target

Read the repository instructions first. If they name a QA stage or workflow,
load its QA contract and follow it; it wins over this skill. Resolve the issue,
base branch, current revision and whether a PR already exists. Read the issue's
acceptance criteria, the committed and uncommitted diff, and the project's run
instructions.

If no workflow exists, use the acceptance criteria and changed runtime risk as
the boundary. Choose the smallest scenario set that can disprove the change's
claims.

**Done when** every acceptance criterion maps to a runtime scenario or is
recorded as having no runtime surface.

## 2. Fix the scenario set

Before starting a browser, list the selected user actions, expected results and
evidence type. Cover wiring, relevant states, rendered layout, service behaviour
and trust boundaries only where the change or its acceptance criteria reach
them. Apply any scale, time, scenario, frame and retry bounds from the governing
workflow.

**Done when** the set has a stated boundary and no two scenarios prove the same
claim.

## 3. Run the current build

Start the app as the project documents. Use the highest available browser or
service capability that produces the required evidence, with synthetic data for
anything committed. Keep one runtime and browser session unless a diagnosed
failure requires replacement. Capture and inspect only frames that prove a
selected scenario.

If a required capability is unavailable, preserve completed evidence and mark
the affected scenarios `not-run` with the reason. A service response does not
stand in for rendered evidence.

**Done when** every scenario has observed evidence, a failure, or an explicit
`not-run` reason at the current revision.

## 4. Leave the artifact

Use the workflow's report path, format, validation, commit and publishing rules.
Without a documented workflow, write one report under `qa/issue-<N>/` with the
scenario results and captioned relative frame links, then commit that directory;
leave tracker and PR publication to the user unless they asked for it.

For a dry run, leave the report uncommitted and return its path.

## 5. Route the result

Report in-scope failures separately from pre-existing findings. Follow the
workflow's reroute on failure and next-stage handoff on success. Where no
workflow exists, offer to fix in-scope failures and recommend separate work for
larger pre-existing findings.
