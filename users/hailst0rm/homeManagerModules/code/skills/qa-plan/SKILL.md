---
name: qa-plan
description: Generate a step-by-step manual QA plan for freshly-built work by cross-referencing a GitHub issue against its diff, run a quick browser smoke first, and post the plan as a comment on the issue. Use this as the final runtime gate after the static review skills (/tdd, /review, /codex:review) and before marking an issue ready-for-human or opening a PR — whenever the user says "qa this", "qa plan", "how do I test this", "make a test plan", "verify the new feature", "what should I click", or has just finished implementing something and wants to check it by hand. This is the dynamic, human-in-the-browser layer: use it even when code review already passed, because review reads code and this exercises the running app.
---

# QA Plan

Produce a manual QA plan a human can follow to verify, in the running app, that freshly-built work actually does what its issue promised — then post it as a comment on that issue.

This is the **runtime** gate. The static review skills (`/review`, `/codex:review`) read the code; they cannot tell you whether the page renders, the link is clickable, or the flow completes. That gap is where regressions like "the signin page was built but never linked from the menu" survive. This skill closes it by making a human exercise the change end-to-end.

## Where this sits

`/tdd → /review → /codex:review → **/qa-plan** → ready-for-human / PR`

Run it **last**, on already-reviewed code. By then the static axes are covered, so this skill deliberately does **not** re-do them:

- It does **not** re-check "does the diff implement the spec" — `/review`'s Spec axis owns that statically. Here a human *confirms it dynamically* (actually clicks the thing).
- It does **not** review code quality — `/review` and `/codex:review` own that.
- It does **not** file bug issues — failures flow into your existing `/triage`. This skill stops at producing the plan.

Staying in this lane is what keeps it from overlapping the rest of the workflow.

## Process

### 1. Resolve the target

Take the issue number from the argument (e.g. `/qa-plan 4`). If none was given, infer it from the branch name or recent commit messages (`#N`, `Closes #N`); if still ambiguous, ask which issue.

Gather the two inputs:

- **The promise** — `gh issue view <N>` (body, **acceptance criteria**, comments). This is what the work was *supposed* to do.
- **The change** — the diff of what was actually built:
  ```sh
  git diff master...HEAD          # committed work on this branch (merge-base, three-dot)
  git diff                        # + uncommitted working-tree changes
  git status --porcelain          # new files not yet staged
  ```
  Use `master` as the base unless the user names another. Include uncommitted changes — work is often QA'd before it is committed (this project does exactly that).

### 2. Enumerate the changed surfaces

Read the issue ⨯ the diff together and list every **user-facing surface** the change introduces or touches. This is the raw material for the checklist — be concrete, name real routes/components/fields:

- New or changed **routes / pages** (e.g. `/signin`, `/auth/verify`, `/welcome`)
- **Navigation & wiring** — every place that *should* link to a new screen. Cross-check the issue's promise against the diff: if the issue says "reachable from the menu" but the diff never touches the menu component, that is a prime wiring check (and likely a bug).
- **Forms / inputs** and their states: empty, loading, success, error, validation failure
- **Server endpoints / actions** and their failure modes
- **Auth / session boundaries** the change exposes

### 3. Browser smoke first (fail fast)

Before writing a manual checklist, catch gross breakage automatically. Prefer a **real browser** so you see what the user sees.

1. Start the app the way this repo documents it. Check the README, `CLAUDE.md`, and the `scripts` / `Makefile` / `justfile` / compose file for the run command (e.g. `npm run dev`, `make serve`, `docker compose up`). Note the URL and port it serves on, plus any first-run setup it calls out — migrations, seed data, required env vars, and how it delivers emails or other side effects you'll need to observe.
2. **Drive it in a real browser if browser-control tools are connected.** Open each new route, confirm it renders, and watch the devtools console for errors. Attach to an already-open browser instance if there is one; otherwise launch a Chromium-based browser with remote debugging:
   ```sh
   <browser> --remote-debugging-port=9222 <app-url> &
   # <browser> = whatever is installed: brave / chromium / google-chrome
   ```
3. **Headless fallback** — if no browser control is available, smoke the routes with curl and assert no 5xx:
   ```sh
   BASE=<app-url>            # e.g. http://localhost:3000
   for r in <routes the change touches>; do   # e.g. / /signin /auth/verify
     printf '%s -> ' "$r"; curl -s -o /dev/null -w '%{http_code}\n' "$BASE$r";
   done
   ```

Report what the smoke found (booted clean / a route 500'd / a console error). A failed smoke is worth surfacing immediately — don't bury it in the checklist.

### 4. Write the manual QA plan

Turn the surfaces from step 2 into a checklist a human runs by hand. Organize into these four sections (drop a section only if the change genuinely has nothing in it). Every item is a **GitHub task-list checkbox** written as *precondition → steps → expected result*, concrete enough to follow without reading code.

```markdown
> *Generated by AI — manual QA plan for #<N>. Run it, tick what passes, file failures via /triage.*

## QA Plan — #<N> <feature name>

**Smoke:** <one line: app boots / routes render / any 500s or console errors>

### Integration & wiring
- [ ] **<reachability>** — From <where the issue says>, do <action>. Expect: <new screen> opens. *(catches: built-but-unlinked)*

### UI & visual flows
- [ ] **<screen> renders** — Load <route>. Expect: <key elements present>; check empty / loading / error states.

### Logic & edge cases
- [ ] **<behavior> rejects bad input** — Do <invalid action>. Expect: <validation / graceful failure>, no crash.

### Security & auth boundaries
- [ ] **<protected route> blocks unauth** — While signed out, visit <route>. Expect: redirected / denied, not exposed.
```

Guidance for good items:
- **Lead with wiring.** The integration section is the highest-value one — it is the class of bug static review and unit tests both miss. For each new screen, ask "what did the issue say should reach this, and does it?"
- **Test behaviors, not code.** "Submitting an expired magic link shows an error" — never "verifyToken() throws".
- **Cover the states a real user hits**: the empty form, the slow network, the wrong input, the expired session — not just the happy path TDD already proved.
- **Tie back to acceptance criteria.** Every acceptance criterion on the issue should map to at least one check.

### 5. Post the plan and hand it to the human

Post the checklist as a **comment on issue #N** (`gh issue comment <N> --body-file <file>`), so QA lives with the feature in one thread. Keep the AI-disclaimer first line (mirrors the `/triage` convention).

Then **move the issue to `ready-for-human`** — generating the QA plan is exactly the moment the work crosses from agent-driven to human-verified, so flip its triage state to match:

```sh
gh issue edit <N> --add-label ready-for-human --remove-label ready-for-agent
```

Use the labels this tracker actually has — `ready-for-human` is the canonical "a human should take it from here" state in `/triage`. Drop the `--remove-label` if the issue was never `ready-for-agent`.

Do **not** open any bug issues yourself. When the user runs the plan and a check fails, that becomes a `needs-triage` issue through `/triage` — point them there in your closing message.

If the user asked for a dry run, or you are running inside a test, write the plan to a file and print the path instead of posting — and **do not relabel** — never touch a live tracker during evaluation.

## Output contract

Always: a four-section, checkbox-based, issue-referenced plan whose items are runnable by hand, preceded by a one-line smoke result, posted as a comment on the originating issue and the issue relabeled `ready-for-human` (or, on dry-run, written to a file with no posting and no relabel). No code-quality findings, no new issues filed.
