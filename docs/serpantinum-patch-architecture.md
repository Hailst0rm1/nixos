# Is the serpantinum patch-file overlay the right architecture?

**Date:** 2026-09-01 · **Companion:** `docs/serpantinum-v2-audit.md`, `docs/serpantinum-v2-migration-plan.md`
**Scope:** `overlays/serpantinum.nix` + `patches/serpantinum/*.patch` only. Does not revisit the
v1→v2 migration decision itself — that's settled in the companion docs and this doc agrees with it.

## Status (2026-09-01)

Recommendations 1 and 2 are **done**: the 8 one-token patches listed below were converted to
`postPatch` + `substituteInPlace --replace-fail` in `overlays/serpantinum.nix`, and the
convention is now written up in AGENTS.md "Editing upstream source in an overlay". The
conversion was verified byte-identical — `diff -r` over `share/serpantinum` between the
pre- and post-conversion builds reports no differences.

`0009-timedate-center-white.patch` stayed a patch file against this doc's recommendation: it
removes and moves anchor lines rather than swapping a token, and its `anchors.left: parent.left`
target is not unique in the file. `0008-kb-extended-layout.patch` likewise — its target string
repeats three times and is dense with shell quoting.

Recommendation 3 (upstream reports) is **not done** and was deliberately deferred.

## Verdict

**Yes, keep it** — patches-via-`overrideAttrs` is the only mechanism that actually exists for what
these changes need, because Quickshell has no per-file config override, and upstream's own settings
schema doesn't expose the specific knobs being changed. The real finding isn't "wrong architecture,"
it's that **about half the patch set (9 of 18) is single-line/single-token constant swaps that should
be `postPatch` + `substituteInPlace` instead of unified-diff patches** — same fail-loud property, but
immune to the context-line drift that is the actual source of per-release breakage.

One correction to the premise: there are **18** patches on disk (`0001`–`0006`, `0008`–`0019`), not
19 — `0007` was never created (numbering gap, verified via `git log --all` — no commit ever added or
removed a `0007-*.patch`).

---

## 1. Patch-by-patch: config, upstream, or genuinely a patch

Checked against the actual shipped config surface: `nix/settings-options.nix` (typed schema) and
`config/serpantinum/settings.json` (template) in the serpantinum flake input, resolved at
`/nix/store/v1j1x31gn0iyzh6dl8n15b2a75icd9yd-source` via
`(builtins.getFlake "/home/hailst0rm/.nixos").inputs.serpantinum.outPath`.

| # | Patch | Could be config today? | Upstreamable? | Verdict |
|---|---|---|---|---|
| 0001 | ClickButton 2-stop gradient | No — no `Gradient` type exists anywhere in `bar/` except the wave-fill canvases (`grep -rl Gradient src/quickshell/bar/` → only `BatWidget.qml`, `SysMonWidget.qml` and their `Side*` twins) | Yes, as a `theme.gradientButtons: bool` | **Genuine patch** — structural QML addition |
| 0002 | `SysMonWidget` temp pill: `red`→accent | No — `ThemeBackend`'s 22 colour properties are read directly by widgets; there is no per-widget override key wired to any UI element | **Yes, and half-built already** — see finding below | **Genuine patch**, but file upstream first |
| 0003 | `MediaWidget` hover: `green`→accent | Same as 0002 | Same | **Genuine patch** |
| 0004 | `SideMediaWidget` hover: `green`→accent | Same as 0002, on the sidebar's parallel widget | Same | **Genuine patch** — exists only because `bar/` and `sidemodules/` duplicate the same widget logic in two files |
| 0005 | Hyprsplit workspace ranges + qs_manager dispatch fix | No — `WorkspacesWidget.qml:29` hardcodes `Math.min(10, …)` with no config override, and has zero per-monitor-offset awareness | **Yes, strongly** — the 10-workspace clamp is an arbitrary ceiling with no product reason to exist, and the `qs_manager.sh` dispatch uses Hyprland's newer Lua syntax (`hl.dsp.focus`) which doesn't work against classic `hyprland.conf` config — that's an upstream compatibility bug, not a local preference | **Genuine patch**, and the single best upstream PR candidate in the set |
| 0006 | Disable `WallpaperEngine` Loader | No — `wallpaperDir` exists in the schema but there is no `wallpaper.enabled` toggle to skip the Loader | Yes, as `wallpaper.enabled: bool` | **Genuine patch** |
| 0008 | KB widget: show full layout name instead of 2-letter code | No — hardcoded in the widget's shell one-liner, no settings key | Maybe, as a `general.keyboardLayoutFormat` enum, but low value | **Genuine patch**, cosmetic |
| 0009 | TimeDate: center-align, remove left anchor | No — no bar-module layout/alignment settings exist | Low value to upstream (personal alignment preference) | **Genuine patch** |
| 0010 | Weather: `peach`→`text` | No — same colour-role problem as 0002-0004 | Same as 0002 | **Genuine patch** |
| 0011 | Weather temp: drop the forced `.0` decimal | No — hardcoded in `jq` formatting inside `weather.sh` | Yes — arguably a real upstream bug (forcing `12.0°` instead of `12°`) | **Genuine patch**, reasonable upstream bug report |
| 0012 | KB pill: widen `100`→`160` | No — pill width is a hardcoded constant, not a setting | No, layout is upstream's call | **Genuine patch** |
| 0013 | Bar gap: `2`→`10` | No — same, hardcoded constant | No | **Genuine patch** |
| 0014 | Battery icon: drop the low-battery variant | No — hardcoded ternary | No, this reduces information (hides low-battery state) — a personal preference, not a bug | **Genuine patch** |
| 0015 | SysMon pill: kill the wave animation | No — hardcoded formula | No | **Genuine patch** |
| 0016 | Left widget: swap the settings-gear glyph for a NixOS logo glyph | No — icon glyph is hardcoded, not themeable | No, NixOS-specific | **Genuine patch** (branding, correctly kept local — do not upstream) |
| 0017 | Battery pill: force full fill instead of proportional | No — hardcoded formula | No, reduces info the same way as 0014 | **Genuine patch** |
| 0018 | Battery pill hover-scale | No — no hover-scale property anywhere on this widget | Maybe, as a generic `theme.hoverScale` applied shell-wide, which would also retire 0019 | **Genuine patch** |
| 0019 | TimeDate hover-scale | Same as 0018 | Same — 0018+0019 are the same feature applied to two files; a generic hover-scale setting would replace both with zero patches | **Genuine patch**, but bundle with 0018 in any upstream ask |

**Bottom line on "config vs patch":** none of the 18 patches can be expressed through
`programs.serpantinum.settings` today. The schema genuinely has no per-widget colour, size, or
animation override surface — the audit doc's "†" (typed-but-unused) options don't cover any of this
either.

### Highest-value finding: `bar.groupColors` is a half-built version of exactly this feature

`nix/settings-options.nix` types a `bar.groupColors : attrsOf str` option ("Per status-icon-group
accent overrides, e.g. `{ g_kb = "#96cdf8"; }`"), and the settings-editor UI
(`src/quickshell/guide/BarTab.qml:42,78,410,420,719,720,757`) reads and writes it. But **no bar
widget consumes it** —
`grep -rn "groupColors\|g_kb\|g_vol\|g_wifi" src/quickshell/` only returns hits inside
`BarTab.qml`. `SysMonWidget.qml`, `MediaWidget.qml`, `SideMediaWidget.qml`, and `WeatherWidget.qml`
all read `ThemeBackend.<colorName>` directly and ignore `groupColors` entirely.

This means patches 0002, 0003, 0004, and 0010 — four of the eighteen — are working around a
**wiring gap upstream already intended to close**, not a missing feature. Filing this as an upstream
issue (or a small PR wiring `groupColors` into those four widgets) would let all four patches be
deleted and replaced with a `bar.groupColors` block in `serpantinum.nix`.

---

## 2. Does Quickshell offer a file-shadowing override mechanism?

No. Verified against the official docs (`git.outfoxxed.me/quickshell/quickshell-docs`, the doc
source Quickshell publishes to quickshell.org — quickshell.org itself 403s automated fetches):

> "The `-p` or `--path` option will launch the shell root at the given path. It will also accept
> folders with a `shell.qml` file in them." … "The `-m` or `--manifest` option specifies the
> quickshell manifest to read configs from."

`QS_CONFIG_PATH` is documented as the environment-variable equivalent of `-p`/`--path`. Both
mechanisms **select an entire config root** — there is no supported way to point Quickshell at two
roots and have one shadow individual files of the other, no `QML_IMPORT_PATH`-style search-path
layering for shell components, and no singleton-override hook. This closes off "drop a file in
`~/.config` to override one shipped component" as an option; it is not merely undocumented, the
loader model doesn't support it.

That leaves exactly two ways to change one shipped file without forking: **patch it**, or
**overwrite it in `postInstall`/`postFixup`** (which this overlay already does once, for
`assets/logo.svg` — see below).

---

## 3. Options comparison (maintenance cost per upstream release)

| Option | Failure mode on upstream change | What the error looks like | Fix effort | Verdict for this repo |
|---|---|---|---|---|
| **Status quo** — `.patch` files via `overrideAttrs` | `patch` rejects a hunk whose context lines moved | Build fails immediately with a `.rej` file and a hunk number | Regenerate the one broken patch against the new source (minutes, per patch) | **Keep**, with the substituteInPlace split below |
| **Hard fork** (own remote, rebase on upstream tags) | Every upstream commit becomes a rebase, not just the ~6 files actually touched | Merge conflicts across unrelated files as upstream refactors around your changes | Constant — you're now maintaining a full downstream branch of a fast-moving, still-pre-1.0 project (25 commits in 2 days per the audit doc) | **No** — vastly more surface area than 18 small diffs for the same 6 files actually touched |
| **Whole-file copy in `postInstall`** | Silent — the copied file simply becomes stale; nothing fails | New upstream feature/fix in that file quietly never ships; discovered by users, not by CI | Someone has to notice, diff manually, and re-port by hand | **No** — this repo already rejected this explicitly (migration plan: "Patches fail the build loudly... whole-file copies would silently ship stale widgets forever") and this audit agrees: fail-loud beats fail-silent for logic-bearing changes |
| **Config where possible + patches for the rest** | Same as status quo for the patched remainder; zero for the config part | N/A for the config part | Config part: none, ever, across upstream bumps | **This is the target state** — but today 0/18 patches are config-eligible (§1), so it's aspirational until `groupColors` gets wired upstream |
| **Contribute upstream so it lands in config** | None, once merged | N/A | One-time PR review cost, then free forever | **Do this for 0002/0003/0004/0010 (groupColors) and 0005 (workspace clamp + Lua dispatch bug)** — see recommendations |

`postInstall`/`postFixup` are already in productive use in this same overlay for two things that
are *not* QML logic changes — swapping `assets/logo.svg` for a branding asset, and double-wrapping
the binaries to add `pactl`/`xdg-user-dir` to `PATH` (`overlays/serpantinum.nix:34-62`). Both are
legitimate uses of "overwrite the output" because neither has any content upstream could change
under you (a static asset path, a wrapper's `PATH` prefix) — this is consistent with the "silent
staleness" argument only applying to logic-bearing files, not fixed paths/assets.

---

## 4. Nixpkgs conventions

Confirmed from `doc/stdenv/stdenv.chapter.md` (NixOS/nixpkgs, `master`):

- `patches` is a first-class `stdenv.mkDerivation` attribute: "The patch phase applies the list of
  patches defined in the `patches` variable. They must be in the format accepted by the `patch`
  command…" — this is exactly how `overlays/serpantinum.nix` uses it via `overrideAttrs`.
- `substitute` / `substituteInPlace` are documented as string-substitution utilities usable in any
  phase (typically `postPatch`), described as complementary to `patches`, not a replacement for it.
- The manual does **not** state a preference between the two for constant-swap changes — that
  judgment call is mine, based on the mechanical difference: a unified-diff patch encodes several
  lines of *context* and fails if any of them move, even for unrelated reasons; `substituteInPlace
  --replace-fail "old" "new"` encodes only the exact string being changed and fails only if that
  literal text is gone. For a single-token colour/size swap, the patch's context lines are pure
  incidental risk with no benefit.
- Nixpkgs has no stated position on "how many local patches is too many" — carrying a double-digit
  patch set against one package is unremarkable in nixpkgs itself (kernel, chromium, and many
  desktop packages carry more). The volume isn't the problem; the *shape* of each patch is.

---

## 5. Flake input pinning

- `flake.nix:121-122`: `serpantinum = { url = "github:ilyamiro/serpantinum"; };` — no `ref`, so it
  tracks the default branch's tip **at `nix flake update` time**.
- `flake.lock`'s `serpantinum` node is pinned to `rev = "2dfad60ddd03581fc9842c3cce8dc7ca4344cc4e"`,
  which is **already behind** `master`'s current tip (`53988e21d1901b0b044eb624872e39f9475beb40`,
  confirmed via `git ls-remote --heads`). This is normal flake-lock behaviour, not drift: the lock
  freezes an exact rev regardless of what the input URL points at, and nothing moves until an
  explicit `nix flake update`.
- `git ls-remote --tags --refs https://github.com/ilyamiro/serpantinum` returns **nothing** —
  upstream publishes no tags or releases at all, confirming both companion docs' claim.
- **AGENTS.md's rule does not apply here as literally written.** The rule targets
  `fetchFromGitHub`/`rev = "main"` *inside a derivation*, where the FOD hash is fixed at first build
  and silently never re-checked. A flake input has no such gap — `flake.lock` already pins an exact
  rev+hash and Nix refuses to build against anything else until you deliberately run
  `nix flake update`. Functionally, "track `master`, but only advance the lock file deliberately" is
  the same guarantee the rule is protecting, just implemented by the flake-lock mechanism instead of
  a manual `rev =`. This matches the migration plan's decision #1 verbatim, and this audit confirms
  it holds up under Nix's actual locking semantics — no action needed here.
- The one real risk is orthogonal to pinning: **every one of the 18 patches must reapply on every
  `nix flake update --update-input serpantinum`**, regardless of whether the input is a branch or a
  tag, because there are no tags to pin to instead. That risk is inherent to depending on an
  untagged, fast-moving upstream — it is not fixed by any pinning strategy, only mitigated by
  keeping the patch set small and low-context (§6).

---

## 6. Recommendations, ranked

1. **Split the patch set: keep unified-diff patches only for structural changes; convert pure
   constant/token swaps to `postPatch` + `substituteInPlace`.**
   File: `overlays/serpantinum.nix`. Move `0002`, `0003`, `0004`, `0009`, `0010`, `0012`, `0013`,
   `0014`, `0015` out of the `patches` list into a `postPatch` block of
   `substituteInPlace "src/quickshell/.../Widget.qml" --replace-fail "old line" "new line"` calls
   (one call per file; multiple `--replace-fail` pairs per call where a file has more than one
   swap). Delete those 9 `.patch` files. Keep `0001`, `0005`, `0006`, `0011`, `0016`, `0017`,
   `0018`, `0019` as real patches — each adds or restructures a QML block, which `patch` represents
   far more legibly than a giant substitution string would.
   *Effect:* the 9 converted changes stop breaking on unrelated nearby edits; they only break when
   the literal line they target is itself touched, which is a strictly smaller and more meaningful
   set of upstream changes to react to.

2. **File an upstream issue (or small PR) wiring `bar.groupColors` into the widgets that read
   `ThemeBackend` colours directly.** This is the one change that would let real patches
   (0002/0003/0004/0010) disappear entirely rather than just get cheaper. Point to
   `guide/BarTab.qml:719-720` as evidence the settings plumbing already exists and only the
   widget-side consumption is missing.

3. **File the `WorkspacesWidget` clamp (`Math.min(10, …)`) and the `qs_manager.sh` Lua-dispatch
   syntax as upstream bugs**, independent of whether patch 0005 stays local. The clamp has no
   stated rationale and the dispatch syntax targets a Hyprland config style (Lua) that isn't the
   only one Hyprland supports — both look like oversights, not deliberate design, so they're
   reasonable to report even before a fix is accepted.

4. **Leave `flake.nix`'s `serpantinum` input exactly as-is** (branch-tracking + `flake.lock` pin).
   No change needed — §5 shows the AGENTS.md concern doesn't actually apply, and switching to a
   manual `rev` pin would only add a maintenance step (remembering to bump it) for a guarantee the
   lock file already provides.

5. **Do not fork, and do not switch to whole-file `postInstall` copies.** Both were already
   correctly rejected by the migration plan; this audit found nothing that changes that conclusion.

Not recommended: trying to eliminate the patch set entirely. Even after (2) and (3) land upstream
(if they land — this is a small, fast-moving project with no tags and no stated contribution
process visible in the repo), branding (0016), personal layout/visual preferences (0009, 0012,
0013, 0014, 0017, 0018, 0019), and the wallpaper-engine opt-out (0006) have no reason to ever be
upstream config — they're this repo's taste, not a gap in serpantinum.

---

## Sources

- This repo: `overlays/serpantinum.nix`, `patches/serpantinum/*.patch` (18 files),
  `users/hailst0rm/homeManagerModules/hyprland/serpantinum.nix`, `flake.nix:121-122`, `flake.lock`,
  `AGENTS.md` ("GitHub fetches: pin to tags or SHAs, never branches"),
  `docs/serpantinum-v2-audit.md`, `docs/serpantinum-v2-migration-plan.md`.
- Upstream serpantinum flake input, resolved via
  `nix eval --raw --impure --expr '(builtins.getFlake (toString /home/hailst0rm/.nixos)).inputs.serpantinum.outPath'`
  → `/nix/store/v1j1x31gn0iyzh6dl8n15b2a75icd9yd-source`: `nix/settings-options.nix`,
  `nix/package.nix`, `config/serpantinum/settings.json`,
  `src/quickshell/singletons/ThemeBackend.qml`, `src/quickshell/guide/BarTab.qml`,
  `src/quickshell/bar/modules/WorkspacesWidget.qml`.
- `git ls-remote --tags --refs https://github.com/ilyamiro/serpantinum` (empty — no tags) and
  `git ls-remote --heads https://github.com/ilyamiro/serpantinum` (master @ `53988e21…`).
- Quickshell docs (doc source, quickshell.org 403s automated fetches):
  https://git.outfoxxed.me/quickshell/quickshell-docs — `content/docs/configuration/intro.md`
  (`-p`/`--path`, `-m`/`--manifest`, `QS_CONFIG_PATH`).
- Nixpkgs manual: https://nixos.org/manual/nixpkgs/stable/ and
  https://raw.githubusercontent.com/NixOS/nixpkgs/master/doc/stdenv/stdenv.chapter.md
  (`patches` attribute, `substitute`/`substituteInPlace`).
