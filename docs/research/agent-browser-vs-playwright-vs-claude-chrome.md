# Browser automation for AI agents: agent-browser vs Playwright(-MCP) vs Claude-in-Chrome

One-line summary: three ways to drive a browser from an LLM — a headless token-lean Rust CLI (agent-browser), a full scriptable engine with an optional MCP server (Playwright), and an extension that drives your real logged-in Chrome (Claude-in-Chrome) — compared on speed, token/context cost, headless-vs-desktop fit, and auth, with a recommendation for a Hermes-on-server + Claude-Code-on-desktop split.

- Date: 2026-05-10
- Versions examined: agent-browser **v0.31.1** (pinned in this repo; README/SKILL.md read from `main`), Playwright MCP `@playwright/mcp` (README on `main`, docs current), Claude-in-Chrome via Claude Code (docs current; extension ≥1.0.36, Claude Code ≥2.0.73).
- Method: primary sources only — GitHub READMEs/SKILL.md, playwright.dev docs, Anthropic docs, and the Claude-in-Chrome MCP tool schemas themselves (the tool definitions are authoritative for what each tool returns). Claims are labelled **[measured]** (verifiable fact from source), **[vendor]** (author's own claim/marketing), or **[inference]** (mine). No first-party token benchmarks exist for any of the three — where numbers are absent this report says so rather than inventing them.

---

## TL;DR — decision matrix

| Dimension | agent-browser (Vercel Labs) | Playwright + Playwright MCP (Microsoft) | Claude-in-Chrome (Anthropic) |
|---|---|---|---|
| Primary form | Native Rust CLI + Rust daemon (direct CDP) | Library/CLI; MCP server wraps it | Chrome extension + native-messaging host, driven from Claude Code |
| Designed for | Headless server / CI, any agent | Both; scripting + agent loops | Interactive desktop, real user browser |
| Default page observation | Accessibility-tree **snapshot** with `@eN` refs (text) | MCP: aria **snapshot** (YAML a11y tree); `--vision` = screenshots | `read_page` (a11y tree) / `get_page_text` (raw text) / `computer` (screenshot) |
| Token posture | Lean by design; `snapshot -i` + `--json` to trim | Snapshot mode is a11y-text (not screenshots); CLI more token-lean than MCP per MS | Text tools are lean; `computer` screenshots cost image tokens; tools always-loaded adds context |
| Startup cost | Daemon starts on first cmd, persists → fast subsequent cmds | Node/browser launch per session; MCP process | Extension already running; near-zero launch, but needs live desktop Chrome |
| Headless | Yes (default) | Yes | No — visible window, real desktop required |
| Reuse real logged-in session | Import from your Chrome (`--auto-connect state save`); own persistent profiles | Extension connects to existing tabs; `--storage-state`; own profiles | Yes, natively — drives your real profile, shares login state |
| Auth isolation | Isolated sessions/profiles/vault | Isolated (`--isolated`) or persistent | No isolation — it *is* your real browser |
| Right when | Server automation, agent runs, CI, scraping at scale | You need scripting + assertions, or a self-healing agent loop with persistent state | You need to act inside your own logged-in apps on the desktop |

Bottom line for this setup: the server-vs-desktop split (agent-browser headless on the NixOS server via Hermes; Claude-in-Chrome interactive on the laptop) is the **right architecture** — the two tools occupy non-overlapping niches. Playwright-MCP is not needed unless a workload wants scripted assertions or persistent introspective loops. The one concrete fix: the bundled `SKILL.md` is not wired into Hermes, so the driving model rediscovers the CLI each run.

---

## 1. Performance, speed, and connection model

**agent-browser.** Architecture is a Rust CLI that talks to a **pure-Rust daemon using direct CDP, no Node.js**; "The daemon starts automatically on first command and persists between commands for fast subsequent operations," with optional `AGENT_BROWSER_IDLE_TIMEOUT_MS` auto-shutdown **[measured]** (README, "Rust CLI / Rust Daemon" and Requirements sections). Browser engine is Chrome from Chrome for Testing by default; `--engine` selects `chrome` or `lightpanda` **[measured]**. So per-command latency is: one-time daemon+browser warmup, then cheap CDP round-trips. Vendor framing is "Fast native Rust CLI" **[vendor]** (README title). No first-party latency numbers are published **[measured: absence]**.

**Playwright / Playwright MCP.** Connection model is flexible: launch its own browser binaries, or connect to an existing Chromium over a **CDP endpoint** (`cdpEndpoint`, `cdpHeaders`, `connectTimeout` in the MCP config) **[measured]** (playwright-mcp README config block). Playwright manages versioned browser binaries installed via its CLI **[measured]** (playwright.dev/docs/browsers). Startup is a Node process + browser launch per session; the MCP server is a long-lived process the client spawns. Docker image is **headless chromium only** **[measured]** (playwright-mcp README, Docker note). No first-party latency numbers **[measured: absence]**.

**Claude-in-Chrome.** Connection is a Chrome/Edge **extension** plus a **native-messaging host** config file (`com.anthropic.claude_code_browser_extension.json`) that Chrome reads at startup **[measured]** (Anthropic Chrome docs, Troubleshooting). There is no browser to launch — it attaches to an already-running Chrome and "opens new tabs for browser tasks"; "Browser actions run in a visible Chrome window in real time" **[measured]** (Chrome docs, intro). So launch cost is effectively zero, but it *requires a live desktop Chrome session*; the extension's service worker can go idle and drop the connection on long runs **[measured]** (Troubleshooting, "Connection drops"). Not supported on Brave/Arc or in WSL **[measured]**.

Net: for unattended throughput, agent-browser's persistent daemon and Playwright's headless server are both suited; Claude-in-Chrome trades headless capability for zero-launch access to a real desktop browser.

---

## 2. Token optimization / context efficiency (the important axis)

All three converge on the same core idea — feed the model a **text accessibility tree, not pixels** — but they differ in defaults and in how much tool/schema overhead they add.

### agent-browser — accessibility snapshot + compact refs
- `snapshot` returns "the accessibility tree with refs"; the model then acts by ref: `click @e2`, `fill @e3 …`, `get text @e1` **[measured]** (README Quick Start).
- The stated rationale for the ref workflow is explicitly token/agent-shaped: refs are "Deterministic … Fast … AI-friendly — Snapshot + ref workflow is optimal for LLMs" **[vendor]** (README, "Why use refs?").
- Output can be trimmed: `snapshot -i` returns "Interactive elements only (buttons, inputs, links)"; `snapshot --json` returns a structured `{snapshot, refs:{e1:{role,name}…}}` payload; the "Optimal AI Workflow" prescribes `snapshot -i --json` then act by ref **[measured]** (README, Snapshot Options + Optimal AI Workflow).
- Screenshots exist (`screenshot page.png`) and are framed as a **fallback for multimodal reasoning** about "visual layout, unlabeled icon buttons, canvas elements … that the text accessibility tree cannot capture" **[measured]** — i.e. text-first, pixels only when needed.
- The SKILL.md is itself a **progressive-disclosure loader**: it is tiny and its prescribed first step is `agent-browser skills get core` (append `--full` for the full command reference) rather than dumping everything into context **[measured]** (SKILL.md, "Core Workflow"). This is the token-efficiency story applied to the skill itself.
- No first-party token counts published **[measured: absence]**.

### Playwright MCP — snapshot mode vs vision mode
- The server "enables LLMs to interact with web pages through **structured accessibility snapshots, bypassing the need for screenshots or visually-tuned models**" **[vendor]** (playwright-mcp README, intro) — the default `browser_snapshot` is a11y text, not an image.
- Interaction tools take an "Exact target element reference from the page snapshot, or a unique element selector" (e.g. `browser_drag`, `browser_drop`) — same ref-from-snapshot pattern as agent-browser **[measured]** (README tool list).
- The snapshot shape is Playwright's aria snapshot: a **YAML accessibility tree**, `- role "name" [attribute=value]`, indentation = nesting **[measured]** (playwright.dev/docs/aria-snapshots). Compact, human/LLM-legible, far cheaper than a screenshot.
- **Vision mode** is an opt-in alternative that drives by pixel coordinates (`browser_mouse_click_xy` with `x`/`y`, screenshots) **[measured]** (README tool list) — the screenshot-based, image-token-heavy path, for visually-tuned models.
- Microsoft's own README states MCP is *less* token-efficient than their CLI+SKILLS: "CLI invocations are more token-efficient: they avoid loading large tool schemas and verbose accessibility trees into the model context … better suited for high-throughput coding agents." MCP is positioned for "specialized agentic loops that benefit from persistent state, rich introspection … where maintaining continuous browser context outweighs token cost concerns" **[vendor]** (playwright-mcp README, "Playwright MCP vs Playwright CLI"). This is a direct first-party admission that the CLI+skill shape (which is exactly agent-browser's shape) is the token-lean one.

### Claude-in-Chrome — three observation tools with very different costs
The tool schemas are authoritative here:
- `read_page` returns an **accessibility-tree representation**; default output cap **50000 characters**, default `depth` 15, optional `filter:"interactive"`, and `ref_id`/`max_chars` to scope large pages **[measured]** (read_page schema). This is the token-lean primary observer, and the 50k-char cap is the one concrete size bound any of the three publishes.
- `get_page_text` returns "raw text content … prioritizing article content … plain text without HTML" — lean, for reading text-heavy pages **[measured]** (get_page_text schema).
- `find` does natural-language element lookup, returning "up to 20 matching elements with references" — cheap, ref-producing **[measured]** (find schema).
- `computer` is the pixel path: `screenshot`, coordinate clicks, `zoom` — image tokens, and the schema tells the model to "consult a screenshot to determine the coordinates" before clicking icons **[measured]** (computer schema). So screenshots are the *fallback*, mirroring the other two.
- Anthropic flags the always-on cost explicitly: enabling Chrome by default "increases context usage since browser tools are always loaded … If you notice increased context consumption, disable this setting and use `--chrome` only when needed" **[measured]** (Chrome docs, "Enable Chrome by default"). This is tool-schema overhead, the same cost Microsoft names for MCP.

**Screenshot token cost (general, not tool-specific).** None of the three publishes a per-screenshot token number. As general Anthropic vision guidance (not re-verified this session, not specific to these tools), an image costs roughly `(width × height) / 750` tokens — e.g. a 1280×800 screenshot ≈ ~1,365 tokens — which is why all three default to a11y-text and treat screenshots as a fallback **[inference, general]**. Treat this as an order-of-magnitude anchor, not a measured figure for any tool here.

**Verdict on the axis.** agent-browser and Playwright-MCP snapshot mode and Claude-in-Chrome `read_page` are all the same *kind* of thing: a compact accessibility tree with element refs. There is no published benchmark separating them. The real token differentiator is **overhead, not the snapshot**: an MCP server (Playwright-MCP, or Claude-in-Chrome loaded by default) pays for large tool schemas held in context; a CLI+skill (agent-browser, Playwright-CLI) pays only for the concise commands it emits — a point Microsoft concedes in its own README **[vendor]**. So agent-browser's token/context story is *materially better than an MCP* only to the extent of that schema-overhead difference; against Playwright-MCP's or Claude-in-Chrome's snapshot output itself, it is comparable, not categorically better. Anyone claiming a large snapshot-level win should be asked for numbers that do not currently exist.

---

## 3. Headless server vs interactive desktop

- **agent-browser** is headless by default; `--headed` "opens a visible browser window instead of running headless," and extensions work in both modes via Chrome's `--headless=new` **[measured]** (README, Headed Mode). It also has a cloud provider path (Kernel, `KERNEL_HEADLESS` default `true`) for serverless sessions **[measured]**. This is a server/CI-first tool that can be made visible for debugging.
- **Playwright** does both headless and headed and is fully scriptable with its own profiles; the MCP Docker image is headless-only **[measured]**.
- **Claude-in-Chrome** is interactive-only by construction: it drives a **visible** real Chrome and "pauses and asks you to handle it manually" on login pages or CAPTCHAs **[measured]** (Chrome docs, intro). It needs a desktop session and an installed extension; no headless mode exists.

This maps cleanly onto the user's deployment: agent-browser belongs on the headless server, Claude-in-Chrome belongs on the desktop. They are not substitutes.

---

## 4. Auth / logged-in sessions

- **agent-browser** offers the widest menu: persistent profile (`--profile`, full cookies/IndexedDB/SW/cache across restarts), session persistence (`--session … --restore`), **import auth from a Chrome you already logged into** (`--auto-connect` + `state save` to a JSON, reused later), a state file (`--state`), and an encrypted local **auth vault** (`auth save`/`auth login`) **[measured]** (README, Authenticated Sessions table). So it can *reuse* a real login by exporting it, but it runs in its own automation profile.
- **Playwright** uses isolated (`--isolated`, `--storage-state=…json`) or persistent profiles, and its browser extension "allows you to connect to existing browser tabs and leverage your logged-in sessions and browser state" **[measured]** (playwright-mcp README, Browser Extension + storage-state).
- **Claude-in-Chrome** is the only one that natively *is* the real session: "Claude opens new tabs for browser tasks and shares your browser's login state, so it can access any site you're already signed into" — Gmail, Google Docs, Notion, etc., "without API connectors" **[measured]** (Chrome docs, intro + Capabilities). The flip side: no isolation — it acts as you, in your profile, with your cookies, so it is unsuitable for untrusted automation and site permissions are governed by the extension's per-site settings **[measured]** (Chrome docs, "Manage site permissions").

---

## 5. This repo's wiring (verified in-tree)

- Package: `pkgs/agent-browser/package.nix` pins **v0.31.1**, installs the upstream prebuilt Linux binary, and **copies `${src}/skills` → `$out/skills` and `${src}/skill-data` → `$out/skill-data`** into the store **[measured]** (`pkgs/agent-browser/package.nix`).
- Service: `nixosModules/services/hermes-agent.nix` adds `pkgs.agent-browser` to `systemPackages` when `services.hermes-agent.browser.enable`, writes `/etc/agent-browser/config.json` with `{ headed = services.vncDisplay.enable; profile = "/var/lib/agent-browser/profile"; }`, sets `AGENT_BROWSER_CONFIG` for the gateway, and one-shots `agent-browser install` (Chrome-for-Testing) before the gateway starts **[measured]** (`nixosModules/services/hermes-agent.nix`, lines 86–151).
- **The gap:** nothing references `$out/skills` or `SKILL.md`. `grep` for `skill|SKILL|SOUL|prompt` in the module returns only `systemPackages` and `config.json` lines **[measured]**. So Hermes gets the `agent-browser` binary on `PATH` and a config file, but the bundled SKILL.md never enters the driving model's context. The Hermes LLM must therefore rediscover the CLI (or know to run `agent-browser skills get core --full`) on each run — exactly the user's stated concern, confirmed **[measured]**.
- Config is sensible: `headed` tracks `vncDisplay.enable` (headless unless the VNC display is up), and a persistent `profile` dir gives it cross-run cookies/logins on the server **[measured]**.

---

## Recommendation for this setup

1. **Keep the server-vs-desktop split — it is correct.** agent-browser (headless, Rust daemon, own persistent profile, driven by Hermes) and Claude-in-Chrome (interactive, real logged-in Chrome, driven by Claude Code on the laptop) are non-overlapping. Claude-in-Chrome literally cannot run on a headless server (no visible desktop Chrome, no extension host, WSL unsupported) **[measured]**; agent-browser is purpose-built for the server. Do not try to unify them.

2. **Wire the bundled SKILL.md into Hermes — this is the one clear win.** The store path already contains `${pkgs.agent-browser}/skills/agent-browser/SKILL.md` and `skill-data/`. Surface it to the driving model instead of leaving it inert: append/reference the SKILL.md (or its `skills get core --full` output) in Hermes' `SOUL.md`/system context for the browser-enabled profile, so the model starts each run already knowing the snapshot→ref workflow and the token-trimming flags (`snapshot -i --json`, act-by-ref). Because SKILL.md is a small progressive-disclosure loader, injecting it is cheap and prevents the model from paying rediscovery cost (and from over-fetching full snapshots) every session **[inference, grounded in SKILL.md + the verified wiring gap]**. This is a NixOS-side change to `hermes-agent.nix`, not an upstream one.

3. **Do not add Playwright-MCP by default.** For Hermes' headless automation, agent-browser already gives the token-lean CLI shape that Microsoft itself says beats MCP on token cost **[vendor]**. Reach for Playwright only if a specific workload needs (a) scripted, asserted test flows with `expect`/aria-snapshot matching, or (b) a long-running self-healing agent loop that benefits from MCP's persistent introspective state — the two cases Microsoft names as MCP's niche. Neither is the current "drive a page from Hermes" use case. If such a workload appears, prefer **Playwright CLI+SKILLS over Playwright-MCP** on the server for the same token reason.

4. **Is agent-browser's token story "materially better than the alternatives"?** Partly. Its *snapshot* is comparable to Playwright-MCP snapshot mode and Claude-in-Chrome `read_page` — same accessibility-tree-with-refs idea, and no benchmark separates them. Its real advantage is the **CLI+skill packaging**: no always-loaded MCP tool schema in context (the overhead Anthropic flags for `--chrome` default-on and Microsoft flags for Playwright-MCP). That advantage is only realised if the skill is actually loaded (see #2) and if the model uses the trimming flags. Absent published numbers, avoid claiming more than "comparable snapshot, lower framework overhead."

---

## Sources

Primary:
- agent-browser README (v0.31.1 / `main`) — https://github.com/vercel-labs/agent-browser (raw: https://raw.githubusercontent.com/vercel-labs/agent-browser/main/README.md) **[primary]**
- agent-browser SKILL.md — https://raw.githubusercontent.com/vercel-labs/agent-browser/main/skills/agent-browser/SKILL.md **[primary]**
- Playwright MCP README — https://github.com/microsoft/playwright-mcp (raw: https://raw.githubusercontent.com/microsoft/playwright-mcp/main/README.md) **[primary]**
- Playwright aria snapshots docs — https://playwright.dev/docs/aria-snapshots **[primary]**
- Playwright browsers docs — https://playwright.dev/docs/browsers **[primary]**
- Playwright CLI+SKILLS (referenced by MS as the token-lean alternative) — https://github.com/microsoft/playwright-cli **[primary, not fetched — cited via playwright-mcp README]**
- Claude Code + Chrome docs — https://code.claude.com/docs/en/chrome (redirect from docs.claude.com/en/docs/claude-code/chrome) **[primary]**
- Claude-in-Chrome MCP tool schemas (`read_page`, `get_page_text`, `find`, `computer`, `navigate`, `form_input`) — the live tool definitions in this session **[primary]**
- This repo: `pkgs/agent-browser/package.nix`, `nixosModules/services/hermes-agent.nix` **[primary]**

Secondary / general:
- Anthropic vision image-token heuristic (`~(w×h)/750`) — general Anthropic API guidance, **not re-verified this session**, used only as an order-of-magnitude anchor **[secondary/general]**

Absent: no first-party token-per-action benchmarks or latency numbers were published by any of the three projects as of this date. Claims to the contrary should be treated as marketing until numbers appear.
