# shadcn CLI vs 21st.dev CLI for an agent-driven `/prototype` skill

One-line summary: they are not competitors — `21st add` literally shells out to `npx shadcn@latest add`, so 21st.dev is a *paywalled shadcn registry with a marketplace UX bolted on*; shadcn's CLI reads 33k+ components from 204 public registries for free and is the only one of the two that hands the agent full component source before it writes code, so shadcn is the first reach and 21st is a narrow, metered second.

- Date: 2026-07-13
- Versions examined: **shadcn 4.13.0** (`npx shadcn@latest --version`, run this session), **`@21st-dev/cli` 1.6.0** (built from `pkgs/21st-cli/package.nix` → `/nix/store/hph1acv2jf4qb63fqhzp8njyz1mikr4g-21st-cli-1.6.0`).
- Method: primary sources only. Both CLIs were **actually executed** (`--help` for every subcommand); the 21st bundle `dist/index.js` (68 KB, unminified esbuild output with upstream comments intact) was read for endpoints/auth/metering; `ui.shadcn.com/r/registries.json` and all 237 registry indexes were probed over HTTP; 21st's `/api/search-mcp` and `/r/<user>/<slug>` were probed unauthenticated. No `21st login` was run, nothing published, no project mutated. Claims are labelled **[measured]** (I produced it this session), **[vendor]** (their own claim), **[inference]** (mine), **[UNVERIFIED]** (auth-blocked or not checked).
- Auth blocker, stated up front: this host has **no 21st API key deployed** (`/run/secrets` has no `21st` entry; `services/21st/api-key` is declared in the *uncommitted* working tree of `claude-code.nix`). Every authenticated 21st path below is therefore read from the CLI's own source, not from a live response. Those lines are marked **[UNVERIFIED]**.

---

## TL;DR — decision matrix

| Dimension | shadcn CLI 4.13.0 | 21st CLI 1.6.0 |
|---|---|---|
| What it is | Registry client + project scaffolder + registry *builder* | Marketplace client for one registry (21st.dev) + AI sketch tool + publishing |
| Auth to search | **None** [measured] | **API key required — even to search** [measured] |
| Auth to read source | **None** [measured] | API key, and **metered** [measured] |
| Free quota | Unlimited | **2 component copies/installs per day; 2 MCP/CLI searches per day** [vendor: 21st.dev/pricing] |
| Catalogue | 237 registries in the built-in directory; **33,006 items across the 204 with public indexes** [measured] | Single community catalogue; size **[UNVERIFIED]** (search is 401 without a key) |
| Returns full source before install? | **Yes — `shadcn view` prints the registry item JSON with the entire `files[].content`** [measured] | `search` returns metadata only; `get <id>` prints code but is metered and can return `locked` (paid) [measured, from `dist/index.js`] |
| Install engine | Itself | **`npx shadcn@latest add <21st url>?api_key=…` — it spawns shadcn** [measured, `dist/index.js` `addCmd`] |
| Offline / no key | Init/build/migrate work; registry reads need network | **Everything except `21st logo` dies at the auth check** [measured] |
| Telemetry | Not audited [UNVERIFIED] | **None found** — no posthog/segment/sentry/analytics strings in the bundle [measured] |
| Unique surface | registry directory, `view`, `docs`, `build`, `registry validate`, `mcp init`, `migrate`, `init --template/--monorepo`, `preset`, `eject` | `generate`/`generation`/`iterate`/`take` (AI sketching), `themes`, `logo` (free), bookmarks, lists, teams, `publish*` |

Bottom line for this repo: **keep both, but demote 21st.** shadcn is the agent's default lookup-and-install path (free, unauthenticated, full source in context, 33k items). 21st earns its place for exactly three things a shadcn registry cannot do: `21st logo` (free, unmetered, svgl.app), `21st generate/iterate/take` (AI sketching when nothing in any catalogue fits), and publishing/team libraries. Its `search`/`get`/`add` are strictly worse than shadcn's for an agent — 2/day free quota makes them unusable in an autonomous loop.

---

## 1. Command surface

### shadcn 4.13.0 — full surface [measured, `npx shadcn@latest <cmd> --help`]

| Command | What it does | Notable flags |
|---|---|---|
| `init\|create [components...]` | scaffold project + install deps | `-t/--template next\|start\|vite\|react-router\|laravel\|astro`, `-b/--base base\|radix`, `--monorepo`/`--no-monorepo`, `-p/--preset`, `-d/--defaults` (= `--template=next --preset=base-nova`), `--css-variables`/`--no-css-variables`, `--rtl`, `--pointer`, `--reinstall`, `-f/--force` |
| `add [components...]` | install registry items into the project | `-y`, `-o/--overwrite`, `-a/--all`, `-p/--path`, `--dry-run`, `--diff [path]`, `--view [path]`, `-s/--silent` |
| `view <items...>` | **print registry items as JSON, incl. full file contents** | `-c/--cwd` |
| `search\|list [registries...]` | search items in named registries | `-q/--query`, `-t/--type`, `-l/--limit` (default 100), `-o/--offset`, `--json` |
| `docs <components...>` | doc + example URLs for a component | `-b/--base base\|radix`, `--json` |
| `registry add / validate` | add `@namespace` (or `@ns=url`) to `components.json`; validate a `registry.json` | |
| `build [registry]` | compile a `registry.json` into `public/r/*.json` | `-o/--output` |
| `mcp init --client <claude\|cursor\|vscode\|codex\|opencode>` | write MCP config | |
| `migrate [migration] [path]` | `icons`, `radix`, `rtl` [measured, `--list`] | `-l/--list`, `-y` |
| `preset decode/resolve/url/open`, `apply [preset]` | theme/font presets | `apply --only theme,font` |
| `info` | project introspection (`--json`) | |
| `eject` | inline shadcn/tailwind.css, drop the dep | |
| `diff` | **DEPRECATED** → `add [component] --diff` | |

### 21st CLI 1.6.0 — full surface [measured, `21st help`]

Auth line printed by the CLI itself: *"Run `21st login`, or set TWENTYFIRST_TOKEN (or API_KEY_21ST), or pass --api-key <key>."*

| Group | Commands |
|---|---|
| Account | `login` (browser → `~/.config/21st/auth.json`), `logout`, `whoami`, `usage` (tier + remaining free quota) |
| Find | `search <query> [--type c\|theme\|template] [--limit] [--tag] [--color] [--sort] [--free\|--paid] [--author] [--mine] [--liked] [--json]`, `logo <query>` (**free, no login**), `get <id>` (code + demo), `theme <id>` (CSS) |
| AI sketch | `generate <prompt>` (opens browser), `generation <projectId>` (list takes), `iterate <projectId> "<change>" [--take N]`, `take <projectId> [--take N] [--code]` |
| Curation | `bookmarks`, `bookmark <id> --type`, `lists`, `list <listId>`, `list-new`, `list-add` |
| Teams | `teams`, `team <teamId>`, `team-lists`, `team-components <teamId> [--library]` |
| Install | `add <user>/<slug> [--print]` |
| Publish | `publish <file>`, `publish-theme`, `publish-template`, `publish-gradient`, `publish-ascii`, `edit`, `delete` |
| Profile | `profile get/set/upload` (bento board) |
| Setup | `init --client <cursor\|claude\|codex\|vscode\|windsurf> [--write]` (writes 21st **MCP** config), `install-skill` |

All the exotica the brief asked me to verify **exists**: `generate`/`iterate`/`take` are real (they JSON-RPC `generate`, `iterate_generation`, `get_generation` against `POST https://21st.dev/api/mcp` [measured]); `themes` is `search --type theme` + `theme <id>`; `logo` is real and hits `https://api.svgl.app?search=…` directly, no 21st auth [measured, `logoCmd`]; bookmarks/lists/teams are real MCP tool calls (`bookmark`, `list_bookmarks`, `list_teams`, `list_team_components`, …) [measured, grep of `dist/index.js`].

**The load-bearing finding — `21st add` is a shadcn wrapper.** Verbatim from `dist/index.js` (`addCmd`):

```js
const path = `/r/${encodeURIComponent(user)}/${encodeURIComponent(slug)}`;
const key = getToken(args.flags);
if (args.flags.print || !key) {
  console.log(`npx shadcn@latest add "${BASE_URL}${path}?api_key=$API_KEY_21ST"`);
  ...
}
const url = `${BASE_URL}${path}?api_key=${encodeURIComponent(key)}`;
const child = spawn2("npx", ["shadcn@latest", "add", url], { stdio: "inherit" });
```

So 21st.dev **is a shadcn registry** (`https://21st.dev/r/<user>/<slug>`), and `21st add` is a thin shim that requires `npx` + Node on `PATH` at runtime. Every install-semantics question about 21st collapses into "what does shadcn do", and the Nix package's `21st` binary silently depends on network `npx` for its only mutating command [measured].

### What each has that the other does not

**shadcn only:** the 237-registry **directory** (no key, no config), `view` (full source), `docs`, `build`/`registry validate` (author a registry), `mcp init`, `migrate`, monorepo/framework detection (`init --template`, `--monorepo`), `preset`/`apply`/`eject`, `--dry-run`/`--diff`/`--view` on `add`.

**21st only:** AI sketch loop (`generate`→`generation`→`iterate`→`take`), a global cross-author **search** (shadcn has none — see §2), themes as first-class searchable items, free SVG logo search, bookmarks/lists, team libraries, and publishing (component/theme/template/gradient/ASCII).

---

## 2. Catalogue

**shadcn — measured census.** `https://ui.shadcn.com/r/registries.json` is a plain JSON **array of 237 entries**, each `{name, homepage, url, description}` with a `{name}` (sometimes `{style}`) URL template; **zero entries carry `headers` or `params`**, i.e. the whole directory is unauthenticated by construction [measured]. I fetched every registry's index (`…/r/registry.json`) with 8-way concurrency:

```
registries probed:                 237
with a public registry.json index: 204
TOTAL items across those:       33,006
largest: @shadcn-ui-blocks=3566 @shadcnblocks=3441 @reui=1534 @beste-ui=1516
         @soundcn=816 @shadcnuikit=759 @shadcn-space=736 @svgl=665
         @animate-ui=580 @intentui=569 @coss=564 @uiable=550
no index (count unknown):           33   (includes @shadcn itself — /r/registry.json 404s,
                                          yet `shadcn search @shadcn` works)
network/DNS dead:                    4   (@arc @moleculeui @heatmap @pureui)
```
[measured, this session]

Caveats on that 33,006: it counts every `registry:*` item, including `registry:example` demos and `registry:block` compositions, so it overstates *distinct components*; and the 33 index-less registries (incl. `@shadcn`) are excluded, so it also understates. Order of magnitude — tens of thousands, free, no key — is the real number.

**21st — [UNVERIFIED].** `POST https://21st.dev/api/search-mcp` returns `401 {"error":"API key is required"}` and `GET https://21st.dev/r/shadcn/button` returns `403 {"error":"Authentication required"}` [measured]. Neither the homepage nor `/mcp` exposes a component count in server-rendered HTML. I will not guess. What *is* certain: it is a **single** community catalogue of individually-published components, and it is **not in shadcn's directory** — `registries.json` has no `@21st` entry [measured].

**Superset, subset, or distinct?** Overlapping-but-distinct, tilted heavily toward shadcn:
- 21st.dev republishes shadcn's own components under `shadcn/<slug>` (the CLI's own usage example is `21st add shadcn/button`) [measured], so shadcn core is *inside* 21st.
- MagicUI publishes to both (established).
- But the 237-registry union contains hundreds of first-party vendor registries (`@clerk`, `@auth0`, `@algolia`, `@ai-elements`, `@better-upload`, …) and 1000+-item libraries (`@reui`, `@shadcnblocks`) that have no 21st presence, and 21st contains community one-offs that were never published as a shadcn registry.
- **Neither strictly contains the other**, but the shadcn side is ~an order of magnitude larger and costs nothing to read. [inference, from measured data]

**A real shadcn gap:** there is **no global search**. Bare `shadcn search -q button` errors: *"Provide a registry or namespace to search, e.g. `shadcn search @shadcn`. If you have a components.json with registries configured, run shadcn search with no arguments to search all of them."* [measured]. You must either name the namespace or pre-list registries in `components.json`. This is the one place 21st's single-index search is genuinely more ergonomic for an agent — and it is exactly the capability 21st rate-limits to **2/day**.

---

## 3. Curation model

- **21st**: community publishing, vote/heart-driven (`bookmark`/`--liked`), sortable (`--sort`), filterable by tag/color/author/free-vs-paid; results render as `[type $price] name — author [id: N]` [measured, `printMetaResults`]. Ranking is global and social, and there is a **price** on items, which means the ranking surface is also a sales surface.
- **shadcn**: per-registry curation. Each registry is one team's opinionated set; there is no global rank, no votes, no popularity signal. Selection quality is the *registry author's* problem, and the agent picks a namespace, not a component from a global pile.

**For an agent picking blind (no human eyeballing screenshots), shadcn's model is safer** [inference]. A vote-ranked global marketplace optimises for screenshot appeal — precisely the signal the agent cannot consume. shadcn's namespace model lets the skill hard-code a *trust list* (`@shadcn`, `@magicui`, `@ai-elements`, …) so the agent chooses within a vetted set and never lands on an unmaintained community upload. Global ranking without vision is worse than a curated shortlist.

---

## 4. Auth / pricing / quota / offline / telemetry

### 21st
- **Auth is mandatory for almost everything.** Run this session with no key:
  ```
  $ 21st search button --limit 2 --json   → Not signed in. Run `21st login` or set TWENTYFIRST_TOKEN.
  $ 21st whoami                            → Not logged in.
  $ 21st usage                             → Not signed in.
  $ 21st logo stripe --limit 2 --json      → [{"id":649,"title":"Stripe", … "route":"https://svgl.app/library/stripe.svg" …}]
  ```
  [measured]. `logo` is the **only** command that works keyless — it bypasses 21st entirely and calls `api.svgl.app`.
- **Token**: `x-api-key` header; from `~/.config/21st/auth.json` (via `login`), `TWENTYFIRST_TOKEN`, `API_KEY_21ST`, or `--api-key`. Base URL overridable via `TWENTYFIRST_BASE_URL` [measured]. Publish/edit/delete accept a `21st_sk_…` **API key only, not a login session token** [vendor, `21st-registry` SKILL.md].
- **Quota (the killer)** — 21st.dev/pricing, Hobby tier: *"2 component copies & installs / day; 2 MCP searches / day; 30 21st AI credits / month"*. Builder = **$8/mo** (billed quarterly) for unlimited copies/installs + 100 AI credits; Team = $10/seat/mo [vendor]. The CLI's own source comment confirms the enforcement and its intent:
  > *"Search the 21st catalog. Wraps `POST /api/search-mcp`. The free 2/day limit is enforced server-side; when hit, the response carries `limitReached` + an upgrade URL (**the results themselves are an agent-facing upsell**), so we pass that through rather than throwing."* [measured, verbatim comment in `dist/index.js`]

  Read that twice: **when quota is exhausted, the agent does not get an error — it gets a marketing payload in the result slot.** An unattended agent will happily feed an upsell into its own context and may act on it.
- Paid components exist independently of quota: `get` checks `sc?.locked` and dies with *"Component code is paid; upgrade at https://21st.dev/pricing"* [measured].
- **Offline**: fails at the auth/HTTP boundary; nothing is cached locally. Expired session → same "Not signed in" path.
- **Telemetry**: grep of the bundle for `posthog|segment|analytics|sentry|telemetry|track(` returns **zero hits** [measured]. Only outbound hosts in the bundle: `21st.dev`, `api.svgl.app`, `localhost:${port}` (the OAuth callback for `login`). Clean.

### shadcn
- **No auth, no account, no quota** for the directory, `search`, `view`, `add` against public registries [measured — all of the above ran with no credentials].
- Private/paid registries are supported *per-registry* via `components.json` `headers`/`params` with `${ENV_VAR}` expansion [vendor, ui.shadcn.com/docs/registry/namespace] — but **none of the 237 directory entries use it** [measured].
- **Offline**: `init`, `build`, `migrate`, `info`, `eject` are local. `search`/`view`/`add` need network. No local cache.
- **Telemetry**: not audited [UNVERIFIED].

---

## 5. Install semantics

There is only **one** install engine — shadcn's — because `21st add` spawns `npx shadcn@latest add` (§1). So:

- shadcn `add` reads `components.json` for path aliases, base (radix/base), CSS-variables mode, and framework; resolves `registryDependencies` and npm `dependencies` and installs them with the project's package manager; prompts before overwriting unless `-o/--overwrite`; supports `-y` (skip prompt), `--dry-run`, `--diff`, `--view`, `-p/--path` [measured, `add --help` + `view` output shows `dependencies: ["radix-ui"]` alongside `files[]`]. Tailwind v3 vs v4 and RSC are handled from `components.json`/`init` (`--css-variables`, `--base`, `--template`) [vendor, docs/cli] — I did not scaffold a v3 and a v4 project to A/B it [UNVERIFIED].
- **Safety for unattended agent runs**: `shadcn add --dry-run` then `add -y` is the safe pair; without `--overwrite` it *prompts*, which will hang a non-interactive agent — so the skill must pass `-y` explicitly and must **not** pass `--overwrite` unless it means it.
- **`21st add` is strictly less safe**: it spawns `npx` with `stdio: "inherit"` and no `--dry-run`/`--diff` passthrough, it embeds the API key in the URL (visible in the child process's argv — `ps` leaks it; the CLI masks it in its own echo but not in `argv`) [measured], and it fails opaquely if `npx` isn't on `PATH`. For the Nix package this also means `21st add` is not self-contained: the derivation wraps `nodejs` for the CLI itself but the *only mutating command* needs `npx` + a network npm fetch at runtime.

Verdict: let the agent run **`shadcn add`**, never `21st add`. If you want a 21st component, use `21st add --print` (or just construct it) and run the shadcn command yourself — `--print` emits exactly `npx shadcn@latest add "https://21st.dev/r/<user>/<slug>?api_key=$API_KEY_21ST"` [measured].

---

## 6. Theming

- **21st**: `search --type theme` → `theme <id>` prints the theme's CSS (a `:root` + `.dark` block of shadcn tokens) [vendor, `21st-cli-use` SKILL.md]; `publish-theme <file.css>` goes the other way, and the `21st-design-sync` skill exists purely to lift a project's `globals.css` tokens into the public theme library. Applying is "paste the CSS into `globals.css`" — coherent, agent-applicable, and **metadata (theme CSS) is documented as free** [vendor, SKILL.md: *"Metadata (search, previews, a theme's CSS) is free"*] — though the *search* needed to find the theme id is the 2/day-limited call [measured]. Live shape [UNVERIFIED — no key].
- **shadcn**: `registry:style` / `registry:theme` items + `preset` + `apply [preset] --only theme,font`, and `init --preset`/`-d` defaults to `base-nova`. `preset decode/url/open` round-trips a preset code [measured, `--help`]. This is a first-class, offline-composable theming path with no marketplace involved.
- **tweakcn**: not probed this session [UNVERIFIED]; it publishes shadcn-compatible theme CSS, so it lands in the same "paste tokens into globals.css" slot as `21st theme`.

Both can produce a coherent theme an agent can apply. shadcn's `apply --only theme` is the only one that *writes* it for you.

---

## 7. The hallucination question (the one that decides it)

The agent must have the component's **actual source + prop surface in context before it writes JSX**, or it invents props.

**shadcn wins outright.** `shadcn view <item>` returns the registry-item JSON with the whole file inline — no auth, no project, no quota. Actual output, truncated (17 lines total, run this session in an empty `/tmp` dir):

```json
[
  {
    "$schema": "https://ui.shadcn.com/schema/registry-item.json",
    "name": "button",
    "dependencies": ["radix-ui"],
    "files": [
      {
        "path": "registry/new-york-v4/ui/button.tsx",
        "content": "import * as React from \"react\"\nimport { cva, type VariantProps } from \"class-variance-authority\"\n...\nfunction Button({ className, variant = \"default\", size = \"default\", asChild = false, ...props }: React.ComponentProps<\"button\"> & VariantProps<typeof buttonVariants> & { asChild?: boolean }) { ... }\nexport { Button, buttonVariants }\n",
        "type": "registry:ui"
      }
    ],
    "type": "registry:ui"
  }
]
```
[measured]. Every variant (`default|destructive|outline|secondary|ghost|link`), every size (`default|xs|sm|lg|icon|icon-xs|icon-sm|icon-lg`), the `asChild` prop and the `buttonVariants` export are all right there. That is a hallucination-proof read-before-write. It works for **any** registry in the directory (`shadcn view @magicui/marquee`, etc.), and `shadcn search @ns -q … --json` first gives you `{name, type, description, registry, addCommandArgument}` per hit [measured] to pick from. `shadcn add --view [path]` and `--diff` give the same read-before-write inside a project. (Note `shadcn docs button` returns only **URLs**, not inline props — `view` is the source of truth, not `docs` [measured].)

**21st is the wrong shape for this.** `search` returns **metadata only** — the renderer prints `[type $price] name — author [id: N]` and tells you *"Add --json for full metadata, 'get <id>' for component code"* [measured, `printMetaResults`]. Source arrives only via `get <id>`, which is (a) the **metered** call — one of your **2/day** on free — and (b) can come back `locked` for paid items, in which case the CLI exits 1 with an upgrade URL [measured]. So the agent's read-before-write step is rationed, and its search step is rationed *separately*. An agent that searches, reads two candidates, and installs one has already blown a free day's budget.

**Ranking for the `/prototype` skill:** first reach = `shadcn search @ns` → `shadcn view` → `shadcn add -y`. Second reach = `21st search`/`get` **only** with a paid key and only when the shadcn namespaces genuinely have nothing.

---

## 8. Failure modes and lock-in

| Failure | shadcn | 21st |
|---|---|---|
| Quota exhaustion | n/a | **Silent upsell in the results slot**, not an error [measured, source comment]. Worst possible failure mode for an unattended agent — it will read marketing copy as data. |
| Registry 401/403 | Per-registry and *loud*: `shadcn view @reui/button` → *"You are not authorized to access the item at https://reui.io/r/new-york-v4/button.json … you may need to authenticate."* [measured]. Blast radius = one namespace; the other 236 keep working. | Single point of failure — one 401 and the whole tool is dead. |
| Abandoned / dead registries | **4 of 237 are already network-dead** (`@arc`, `@moleculeui`, `@heatmap`, `@pureui`) and 33 have no discoverable index [measured]. Contained: one bad namespace, not a broken CLI. | n/a (one vendor) |
| Vendor disappears | shadcn is MIT, the registry protocol is a JSON schema you can self-host (`shadcn build`), and 204 registries are just static JSON on someone else's CDN. Survivable. | **21st.dev going away takes the catalogue, the auth, the AI sketcher, and `21st add` with it.** The only artefact that survives is component code you already pulled into the repo. Since `add` is a shadcn shim, the *install path* survives — nothing else does. |
| Upstream API drift | Registry item JSON is schema'd (`registry-item.json`) and versioned. | `/api/mcp` + `/api/search-mcp` are private endpoints with no published contract; the CLI JSON-RPCs tool names (`search`, `get_component`, `generate`, `iterate_generation`, …) that can be renamed server-side at any time [measured]. |
| Unversioned skill markdown | shadcn's official skill ships via `pnpm dlx skills add shadcn/ui` [vendor, ui.shadcn.com/docs/skills] — versioned by npm, not in the repo today. | **Live problem in this repo.** `pkgs/21st-cli/package.nix` fetches three `https://21st.dev/skills/*.md` with fixed hashes; the URLs are unversioned, so upstream edits are invisible until `update.sh` reruns (the package's own comment says exactly this). |
| Missing skill | — | **`21st-cli-use/SKILL.md` tells the agent to "See the `21st-ai` skill for the full generate/iterate/grab-code flow"** — and `pkgs/21st-cli/package.nix` only fetches `21st-cli-use`, `21st-registry`, `21st-design-sync`. `https://21st.dev/skills/21st-ai.md` exists (**HTTP 200**) [measured]. The agent is pointed at a skill this repo does not install → it will improvise the `generate` flow. Concrete, fixable gap. |
| Key leak | n/a | `21st add` puts `?api_key=<key>` in the argv of a spawned `npx` [measured] — visible to any local `ps`. |

---

## Recommendation for this repo

**Keep both. Make shadcn the default and confine 21st to what only it can do.**

1. **`/prototype` reaches for shadcn first, always.** The loop is:
   ```
   shadcn search @shadcn @magicui @ai-elements -q "<thing>" --json   # pick from a TRUST LIST, not a global pile
   shadcn view <@ns/item>                                            # full source + props into context — no key, no quota
   shadcn add -y <@ns/item>                                          # never --overwrite unless asked; --dry-run first if unsure
   ```
   Hard-code the trust list in the skill (shadcn has **no global search** — you must name namespaces, and that constraint is a feature here: it stops a blind agent from landing on an unmaintained community upload). Never let the agent run `shadcn add` without `-y`, or it will hang on the overwrite prompt.

2. **21st is the *second* reach, and only for three things:** `21st logo` (free, unmetered, no key), `21st generate`/`iterate`/`take` (AI sketching when the catalogues genuinely have nothing), and `publish`/team libraries. **Do not** let the `/prototype` skill call `21st search`/`get`/`add` on the free tier — 2 searches + 2 copies per day is not a budget, it's a demo, and blowing it returns an **upsell disguised as a search result**. If the user pays for Builder ($8/mo), `21st search` becomes a legitimate third source *after* the shadcn namespaces, because it is the only cross-author search either tool offers.

3. **Never use `21st add`.** It is `npx shadcn@latest add` with your API key in argv. Use `shadcn add` directly. If a 21st item is wanted, `21st add --print` gives you the exact shadcn command; better still, add 21st once as a namespaced registry in the project's `components.json` and let shadcn own the whole path:
   ```jsonc
   { "registries": { "@21st": { "url": "https://21st.dev/r/{name}",
                                "params": { "api_key": "${API_KEY_21ST}" } } } }
   ```
   shadcn expands `${VAR}` from `process.env` in urls/headers/params [vendor, docs/registry/namespace]. Whether `{name}` tolerates the `user/slug` slash is **[UNVERIFIED]** — no key to test with. If it works, `shadcn view @21st/shadcn/button` gives you read-before-write over 21st too, and `21st search` becomes the *only* command you still need from that CLI. **Test this the moment the sops key is deployed** — it is the single highest-value follow-up in this note.

4. **Fix the two packaging gaps in `pkgs/21st-cli/package.nix`** (both measured, both one-liners):
   - Add the fourth skill: `21st-ai` (HTTP 200 at `https://21st.dev/skills/21st-ai.md`). `21st-cli-use/SKILL.md` explicitly delegates the generate/iterate/take flow to it, and today it isn't installed.
   - `21st add` runtime-depends on `npx`, which the wrapper does not provide. Either drop the command from the skills (recommended — see #3) or add `nodejs` to the wrapper's `PATH`.

5. **Nix packaging for shadcn: `npx --yes shadcn@latest` is acceptable, and arguably correct.** shadcn ships a fast-moving registry client whose *client-side* behaviour must track a *server-side* schema; pinning it in a derivation buys reproducibility you don't want here (an old client against a new registry item is the failure you're trying to avoid), and it publishes no prebuilt binary. It costs one npm fetch per invocation and a `~/.npm/_npx` cache hit thereafter. **However**: `npx` means a network dependency on npm at agent runtime and an unpinned executable running in your project — if that trade bothers you, the honest version is a small `pkgs/shadcn/package.nix` (`fetchurl` the npm tarball + `makeWrapper nodejs`, exactly the shape `pkgs/21st-cli/package.nix` already uses — it's ~30 lines) with an `update.sh` in the existing auto-update sweep. That also removes the `npx` dependency `21st add` currently smuggles in. **[inference]** — I'd do it: same pattern, already proven in-tree, and it makes the `/prototype` skill's primary tool a store path instead of a network fetch.

---

## Sources

Primary — executed this session:
- `21st help` and `21st <cmd>` probes — binary built from `pkgs/21st-cli/package.nix` → `/nix/store/hph1acv2jf4qb63fqhzp8njyz1mikr4g-21st-cli-1.6.0/bin/21st` **[primary, measured]**
- `@21st-dev/cli` 1.6.0 bundle source — `/nix/store/hph1acv2jf4qb63fqhzp8njyz1mikr4g-21st-cli-1.6.0/lib/21st/index.js` (68 KB; `addCmd`, `searchCmd`, `printMetaResults`, `getCmd`, `logoCmd`, `TwentyFirstClient.searchComponents`, `callTool`, `clientConfig`) **[primary, measured]**
- Bundled skills — `…/share/claude-skills/{21st-cli-use,21st-registry,21st-design-sync}/SKILL.md` **[primary]**
- `npx shadcn@latest --version` → `4.13.0`; `--help` for `init/add/view/search/docs/registry/mcp/build/info/migrate/preset/apply/eject`, `registry add --help`, `mcp init --help`, `migrate --list` **[primary, measured]**
- `shadcn view @shadcn/button`, `shadcn search @magicui -q marquee --json`, `shadcn view @reui/button` (401), bare `shadcn search -q button` (namespace required) **[primary, measured]**
- `GET https://ui.shadcn.com/r/registries.json` → 237-entry array; index census of all 237 → 204 indexed / 33,006 items / 4 DNS-dead **[primary, measured]**
- `POST https://21st.dev/api/search-mcp` → `401 {"error":"API key is required"}`; `GET https://21st.dev/r/shadcn/button` → `403 {"error":"Authentication required"}`; `HEAD https://21st.dev/skills/21st-ai.md` → `200` **[primary, measured]**

Primary — vendor docs:
- https://21st.dev/pricing — Hobby/Builder/Team tiers, 2 copies+installs/day, 2 MCP searches/day, 30 vs 100 AI credits, $8 / $10-per-seat **[vendor]**
- https://ui.shadcn.com/docs/registry/namespace — `headers`/`params` + `${ENV}` expansion **[vendor]**
- https://ui.shadcn.com/docs/cli, /docs/mcp, /docs/skills (`pnpm dlx skills add shadcn/ui`) **[vendor]**

In-repo:
- `pkgs/21st-cli/package.nix`, `pkgs/21st-cli/update.sh`, `users/hailst0rm/homeManagerModules/code/claude-code.nix` (lines 14–20, 99–106, 420, 1190 — `API_KEY_21ST` from sops `services/21st/api-key`, uncommitted) **[primary]**

Unverified / absent:
- 21st.dev's component count — search API is 401-gated and the site publishes no server-rendered figure **[UNVERIFIED]**
- Live shape of `21st search --json` / `21st get <id>` / `21st theme <id>` output — no API key on this host; described from CLI source only **[UNVERIFIED]**
- Whether shadcn's `{name}` placeholder tolerates a `user/slug` slash (the `@21st`-as-namespaced-registry trick) **[UNVERIFIED — test when the sops key lands]**
- shadcn CLI telemetry **[UNVERIFIED — not audited]**
- tweakcn **[UNVERIFIED — not probed]**
- Tailwind v3-vs-v4 / RSC install behaviour A/B **[UNVERIFIED — no scaffolded projects created]**
