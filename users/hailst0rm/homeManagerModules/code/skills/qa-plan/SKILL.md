---
name: qa-plan
description: Produce a manual QA plan for freshly-built work by cross-referencing a GitHub issue against its diff, smoke the running app in a browser, and commit the plan with its screenshots to the branch as the evidence artifact. Use as the runtime gate before work is handed back to a human or a PR opens — when the user says "qa this" or asks how to test something by hand, when new UI needs a screenshot or a responsive pass, or when an implementation just landed and wants checking in the running app.
---

# QA Plan

Produce a manual QA plan a human can follow to verify, in the running app, that freshly-built work actually does what its issue promised — then commit it, with its screenshots, to `qa/issue-<N>/` on the branch. The commit is where this skill ends; publishing it is someone else's step.

## Lane

This is the **runtime** gate, and it owns exactly one question: *does the thing work when a person uses it?*

Static review reads the diff and can tell you the code is correct. It cannot tell you the page renders, the link is clickable, or the flow completes. That gap is where regressions like "the signin page was built but never linked from the menu" survive. Everything here exists to close it — so stay on behaviour a human can observe, and leave code quality, style, and spec-vs-diff analysis to the passes that already ran.

## Process

### 1. Resolve the target

Take the issue number from the argument (e.g. `/qa-plan 4`). If none was given, infer it from the branch name or recent commit messages (`#N`, `Closes #N`); if still ambiguous, ask. If the project has no issue tracker at all, run the whole skill anyway — step 6 commits the plan as a file either way.

Two facts decide step 6, so gather them now: whether the branch already has a PR (`gh pr view --json number,url` succeeds), and whether the repo documents a workflow that claims delivery — an `AGENTS.md` naming a `qa` stage, or a wiki it points at.

Gather the two inputs:

- **The promise** — `gh issue view <N> --comments` (body, **acceptance criteria**, discussion). This is what the work was *supposed* to do.
- **The change** — the diff of what was actually built:
  ```sh
  BASE=$(git symbolic-ref --quiet --short refs/remotes/origin/HEAD | cut -d/ -f2)
  git diff "$BASE...HEAD"         # committed work on this branch (merge-base, three-dot)
  git diff                        # + uncommitted working-tree changes
  git status --porcelain          # new files not yet staged
  ```
  Use the detected base unless the user names another. Include uncommitted changes — work is often QA'd before it is committed.

### 2. Enumerate the changed surfaces

Read the issue ⨯ the diff together and list every **user-facing surface** the change introduces or touches. This is the raw material for the checklist — be concrete, name real routes/components/fields:

- New or changed **routes / pages** (e.g. `/signin`, `/auth/verify`, `/welcome`)
- **Wiring** — every place that *should* link to a new screen. Cross-check the issue's promise against the diff: if the issue says "reachable from the menu" but the diff never touches the menu component, that is a prime wiring check (and likely a bug).
- **Forms / inputs** and their states: empty, loading, success, error, validation failure
- **Server endpoints / actions** and their failure modes
- **Auth / session boundaries** the change exposes

**Done when** every acceptance criterion on the issue maps to a named surface, or is explicitly recorded as non-user-facing.

### 3. Boot and smoke

Before writing a manual checklist, catch gross breakage automatically.

1. Start the app the way this repo documents it. Check the README, `CLAUDE.md`, and the `scripts` / `Makefile` / `justfile` / compose file for the run command. Note the URL and port, plus any first-run setup it calls out — migrations, seed data, required env vars, and how it delivers emails or other side effects you'll need to observe.
2. **Drive every changed route in a real browser.** Work down this ladder and stop at the first rung that holds:
   1. A browser-automation CLI — every command below is written for `agent-browser`; adapt if yours differs.
   2. An MCP browser tool (the Claude Chrome extension, Playwright MCP, or equivalent).
   3. Neither drives a page → **say so and stop.** A QA plan built without ever rendering the app is worse than no plan, because it reads like evidence.

   No login is needed anywhere in this skill — the browser only has to reach the app under test.
   ```sh
   agent-browser open "$BASE_URL/<route>"
   agent-browser console        # console output
   agent-browser errors         # uncaught page exceptions — separate stream
   agent-browser a11y           # axe audit: WCAG violations with selectors
   ```
3. **Capture a screenshot matrix.** Whatever width the browser happened to open at hides the most common layout bugs: an element that collides at 800px looks fine at 1440px, and a banner that's correct on desktop clips on a phone. Set a real desktop size *and* sample the widths where this app's own CSS changes — read the `@media` breakpoints in the touched components and shoot just above and just below each (defects cluster at those boundaries), plus one phone width (~360px). If the app themes, shoot the desktop width in both.
   Shoot into `qa/issue-<N>/` — step 6 commits that directory, so the frames land where they will be read from:
   ```sh
   mkdir -p qa/issue-<N>
   agent-browser set viewport 1440 900 && agent-browser screenshot qa/issue-<N>/qa-1440.png
   agent-browser set viewport 360 800  && agent-browser screenshot qa/issue-<N>/qa-360.png
   agent-browser set media dark        && agent-browser screenshot qa/issue-<N>/qa-1440-dark.png
   ```

**Done when** every changed route has been opened, both log streams read, and a frame saved at every width in the matrix. Report what the smoke found (booted clean / a route 500'd / a console error) immediately — don't bury a failure in the checklist.

If the app genuinely cannot serve a browser (headless CI, no display, backend-only change), fall back to asserting no 5xx — and say plainly that layout went unverified:
```sh
for r in <routes the change touches>; do
  printf '%s -> ' "$r"; curl -s -o /dev/null -w '%{http_code}\n' "$BASE_URL$r";
done
```

### 4. Measure the layout

**Crowding** — two things competing for one pixel band — is the defect class static review cannot see and a text assertion cannot catch. It is also the reason this skill takes screenshots at all, so treat this step as the point of step 3, not its epilogue.

Prove the geometric claims with **numbers**, not impressions. Bounding boxes make overlap arithmetic:

```sh
agent-browser get box '<selector>'         # {x, y, width, height}
agent-browser hover '<selector>'           # then re-measure — hover states move things
agent-browser eval 'Array.from(document.querySelectorAll("<sel>")).map(e=>({s:e.className,...e.getBoundingClientRect().toJSON()}))'
agent-browser eval 'document.documentElement.scrollWidth > window.innerWidth'   # horizontal overflow
```

Two rectangles overlap when their x-ranges and y-ranges both intersect. Compute that for every element the diff touched against its neighbours, at each captured width, **with realistic non-empty data and in hover and active states** — empty data and resting state are where crowding hides, because a table with two rows and no hover has room the real screen does not.

**Make that data synthetic.** The frames get committed in step 6 and git history has no undo, so real client names, hostnames, identities and case material stay out of a frame. Realistic *shape*, invented *content*.

Then `Read` the saved frames for the claims no number proves:

- Stacking reads correctly — a banner sits above the content it introduces, not behind it.
- Truncation lands on a character boundary, not mid-glyph.
- Hover-only controls and absolutely-positioned overlays have space **reserved for them in the layout** rather than floating over flowed content. These are the usual offenders — start there.
- The screen is balanced enough to ship: nothing visually orphaned, nothing colliding that the boxes technically cleared by two pixels.

**Done when** every touched element is accounted for at every captured width, in both resting and hover state, by a measurement or by a frame you actually opened — not when the frames were captured.

### 5. Write the manual QA plan

Turn the surfaces from step 2 into a checklist a human runs by hand. Organize into these four sections (drop one only if the change genuinely has nothing in it). Every item is a **GitHub task-list checkbox** written as *precondition → steps → expected result*, concrete enough to follow without reading code.

```markdown
> *Generated by AI — manual QA plan for #<N>. Run it and tick what passes.*

## QA Plan — #<N> <feature name>

**Smoke:** <one line: app boots / routes render / any 500s or console errors>

### Integration & wiring
- [ ] **<reachability>** — From <where the issue says>, do <action>. Expect: <new screen> opens. *(catches: built-but-unlinked)*

### UI & visual flows
- [ ] **<screen> renders** — Load <route>. Expect: <key elements present>; check empty / loading / error states.
- [ ] **<screen> layout holds across widths** — View at desktop and at the narrow widths from the matrix. Expect: no crowding at any width, in resting and hover state. *(catches: breakpoint dead-zones, negative-margin / z-index stacking bugs)*

### Logic & edge cases
- [ ] **<behavior> rejects bad input** — Do <invalid action>. Expect: <validation / graceful failure>, no crash.

### Security & auth boundaries
- [ ] **<protected route> blocks unauth** — While signed out, visit <route>. Expect: redirected / denied, not exposed.

## Frames

![1440px](qa-1440.png)
![360px](qa-360.png)
```

Everything above `## Frames` is what gets posted as the PR comment, so keep the frames below that line and nothing else there.

Guidance for good items:
- **Lead with wiring.** The integration section is the highest-value one — it is the class of bug static review and unit tests both miss. For each new screen, ask "what did the issue say should reach this, and does it?"
- **Test behaviors, not code.** "Submitting an expired magic link shows an error" — never "verifyToken() throws".
- **Cover the states a real user hits**: the empty form, the slow network, the wrong input, the expired session — not just the happy path the tests already proved.
- **Write visual expectations a screenshot can prove.** "The banner says 'scheduled for deletion'" passes even when that banner renders *underneath* the hero. Name the matrix frame that demonstrates each visual item (`qa-360.png`), so a reader knows which one to scroll to.
- **Tie back to acceptance criteria.** Every acceptance criterion should map to at least one check.

### 6. Commit the report

**For UI changes someone has to *see* the layout to catch a layout bug** — a list of filenames is not evidence. Frames live in the file, checkboxes in the comment; each surface renders one of them.

Write the whole plan — AI-disclaimer first line, smoke line, the four checklist sections, then a `## Frames` heading carrying the frames — to **`qa/issue-<N>/qa-report.md`**, beside the PNGs from step 3. Reference each frame by its bare filename so the path stays relative:

```markdown
## Frames

![1440px](qa-1440.png)
![360px](qa-360.png)
```

Commit the directory to the branch, and stop there:

```sh
git add qa/issue-<N> && git commit -m "qa: report and frames for #<N>"
```

The commit is the deliverable. Everything past it — pushing, PR comments, tracker labels — belongs to whoever publishes:

- **The repo documents a workflow** — an `AGENTS.md` naming a `qa` stage, or a wiki it points at — → follow what it says about delivery, and do nothing it does not ask for.
- **No documented workflow, and the branch has a PR** → post everything **above** `## Frames` as a comment on that PR, updating your own earlier QA comment rather than stacking a new one, and link the report at `blob/$(git rev-parse HEAD)/` so the SHA holds the review to the frames it was given. Then open that link and confirm the frames appear — a broken image is not evidence.
- **No PR** → say in your closing message that the report awaits posting, and leave the tracker alone.

If the user asked for a dry run, or you are running inside a test, leave the report uncommitted and print its path instead. Never touch a live tracker during evaluation.

### 7. Report what you found, and offer the fix

The plan is for the human. What *you* found in steps 3 and 4 is for now — close by listing it and sorting each finding by whether it belongs to this task:

- **In scope** (a defect in what this issue built, or small enough to land here) — list it, then offer to fix it. Point at whichever skill this setup has for the job — a diagnosis skill when the cause is unclear, a test-first skill when the gap is a missing case, a direct edit when it is obvious.
- **Out of scope** (pre-existing, or a larger problem the diff merely revealed) — recommend a separate issue and offer to write it, rather than smuggling it into this one.

When fixes land, **offer a fresh QA pass** scoped to what changed — a fix is unverified until something re-runs the check that caught it.

If nothing failed, say that in one line and stop.
