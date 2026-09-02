# NixOS Configuration Conventions

Project-specific rules for this NixOS configuration repository.

## Repository Architecture

```
flake.nix          Entry point (inputs + mkSystem calls)
lib/generators.nix mkSystem builder function
hosts/             Per-host NixOS configs (configuration.nix + hardware-configuration.nix)
hosts/default.nix  Shared defaults for ALL hosts (lib.mkDefault values)
nixosModules/      System-level modules (auto-imported, DO NOT add manual imports)
users/<user>/homeManagerModules/  HM modules (auto-imported, DO NOT add manual imports)
users/<user>/hosts/default.nix   HM defaults (lib.mkDefault values)
users/<user>/hosts/<host>.nix    Per-host HM overrides
pkgs/              Custom package derivations (pkgs/<name>/package.nix)
overlays/          Auto-loaded overlays (overlays/<name>.nix)
disko/             Declarative disk partitioning configs
secrets/           sops-nix encrypted YAML files
```

## How mkSystem Works

`lib/generators.nix` defines `mkSystem { hostname; username; }` which:

1. Auto-loads ALL overlays from `overlays/` directory
2. Creates `pkgs-unstable` with the same overlays applied
3. Conditionally includes Home Manager if `users/<user>/hosts/<hostname>.nix` exists
4. Passes `specialArgs` to all NixOS modules: `inputs`, `hostname`, `pkgs-unstable`
5. Passes HM `extraSpecialArgs`: `inputs`, `pkgs-unstable`

## Module Patterns

Modules in `nixosModules/` and `homeManagerModules/` are auto-imported via `lib.filesystem.listFilesRecursive`. **Do NOT add manual imports** for files in these directories.

Standard pattern:
```nix
{ config, lib, pkgs, ... }: let
  cfg = config.<namespace>;
in {
  options.<namespace>.enable = lib.mkEnableOption "description";
  config = lib.mkIf cfg.enable { ... };
}
```

HM modules can read NixOS config via `osConfig` (e.g., `osConfig.security.sops.enable`).

## The Default Chain

Options flow through a priority chain:

1. `nixosModules/variables.nix` defines options with `lib.mkOption`
2. `hosts/default.nix` sets `lib.mkDefault` values for ALL hosts
3. `hosts/<hostname>/configuration.nix` overrides specific values (higher priority)

Same pattern for Home Manager:
1. `users/<user>/hosts/default.nix` sets `lib.mkDefault` values
2. `users/<user>/hosts/<hostname>.nix` overrides per-host

### Always mirror new options to `default.nix`

Whenever you add a new option to a module (NixOS or Home Manager), also add it to the corresponding `default.nix` with a `lib.mkDefault` value — even if the value matches the module's built-in default.

- New option in `nixosModules/**` → mirror in `hosts/default.nix`
- New option in `users/<user>/homeManagerModules/**` → mirror in `users/<user>/hosts/default.nix`

This keeps `default.nix` as the single browseable surface for "what can I toggle on this system?" — without it, options become invisible unless someone reads every module. Match the existing nesting style in `default.nix` (preserve attrset shape, group related sub-options together).

## Package Channels

- `pkgs` — stable (nixos-25.11), use for system-critical packages
- `pkgs-unstable` — latest, use when you need newer versions
- Both share the same overlays

## Custom Packages & Overlays

- Packages: `pkgs/<name>/package.nix` using `callPackage` pattern
- Overlays: `overlays/<name>.nix` with format `final: prev: { name = prev.callPackage ../pkgs/<name>/package.nix {}; }`
- Overlays auto-load from directory; just create the file

## Editing upstream source in an overlay

Applies to any overlay that changes a dependency's own files — today that is
`overlays/serpantinum.nix`, whose QML the top bar is built from.

Carry the change as an **edit over the upstream source**, never as a copied
whole file. A copy goes stale silently and ships a widget frozen at whatever
upstream looked like the day it was copied; an edit that no longer applies
fails the build loudly.

Two forms. Pick by what the edit does:

| The edit | Form | Lives in |
| --- | --- | --- |
| Swaps one token — a colour role, a pixel constant, an icon glyph | `substituteInPlace --replace-fail` | `postPatch` in the overlay |
| Adds, removes or moves lines | `.patch` file | `patches/<pkg>/NNNN-name.patch` |
| A whole new file we author, that upstream does not have | real file + `install -D` | `patches/<pkg>/files/<path>` |

The third row is the exception that proves the first two. A diff earns its keep
by breaking loudly when upstream moves the code around it — a file upstream
does not have has no such context, so storing it as a patch buys nothing and
makes it unreadable and uneditable. Keep it as a real file, `install -D` it from
`postPatch`, and use a small `.patch` for the handful of upstream lines that
wire it in. `overlays/serpantinum.nix` does this for the system monitor panel
and the LocalSend backend.

A unified diff pins three context lines either side of its change, so an
unrelated upstream edit *near* the target breaks it. `--replace-fail` keys off
the target string alone and breaks only when that string itself changes. Most
theming tweaks are one-token, so most belong in `postPatch`.

**Confirm the target string occurs exactly once in the file before adding a
`--replace-fail`.** `substituteInPlace` rewrites every occurrence, so a
repeated string silently changes lines you did not mean to touch — the one
failure mode here that does not announce itself. When it is not unique, use a
`.patch` file.

### Generating a patch

Patches apply in list order, and each one's context lines must match the file
*after* the earlier patches ran. So generate against a tree that already has
them:

```sh
src=$(nix eval --raw --impure --expr \
  '(builtins.getFlake (toString /home/hailst0rm/.nixos)).nixosConfigurations.<host>.pkgs.<pkg>.src.outPath')
cp -r --no-preserve=mode "$src" /tmp/w/before
for p in patches/<pkg>/*.patch; do patch -d /tmp/w/before -p1 -i "$p"; done
cp -r --no-preserve=mode /tmp/w/before /tmp/w/after   # edit files under after/
diff -u /tmp/w/before/<file> /tmp/w/after/<file> \
  | sed 's|^--- /tmp/w/before/|--- a/|; s|^+++ /tmp/w/after/|+++ b/|'
```

Numbers order the sequence; they are not identities. Gaps are fine — `0007`
does not exist.

Glyph edits carry non-ASCII codepoints that a shell heredoc will silently
strip. Write them from Python with `chr(0xF1105)` rather than pasting the
character, then read the bytes back with `cat -v` to confirm they landed.

### Proving a refactor changed nothing

Moving an edit between the two forms, or renumbering patches, must leave the
built output identical. Build the derivation before and after, then diff the
payload directory:

```sh
diff -r /nix/store/<old>-<pkg>/share/<pkg> /nix/store/<new>-<pkg>/share/<pkg>
```

Wrapper scripts under `bin/` always differ by their own store path; the payload
directory is the one that must match byte for byte.

## GitHub fetches: pin to tags or SHAs, never branches

**Never** use `rev = "main"` / `"master"` / `"HEAD"` in `fetchFromGitHub`, and
never embed `/main/` or `/master/` in a `raw.githubusercontent.com` URL. Nix
uses the fetch's `hash` as the FOD identity, so the first build freezes the
source forever — new upstream commits stay invisible until somebody manually
changes the hash. The repo has hit this twice (`litellm` pricing snapshot,
`mattpocock/skills`).

Pick a ref by precedence:

1. **Latest stable release tag** if upstream publishes them
   (`git ls-remote --tags --refs <url> | tail`). Skip `-rc.*` / `-dev.*` /
   `-beta` / `-alpha` suffixes.
2. **Current branch HEAD SHA** if no tags exist. Get it with
   `git ls-remote <url> refs/heads/<branch>` and leave a one-line comment
   naming the tracked branch.

Use `${...}` interpolation so the version string appears exactly once — that
form is what `scripts/nix-github-update-report.py` substitutes when bumping:

```nix
# Release-tag form (preferred):
let
  fooRelease = "v1.2.3";
in
fetchurl {
  url = "https://raw.githubusercontent.com/<owner>/<repo>/refs/tags/${fooRelease}/path/to/file";
  hash = "sha256-...";
}

# SHA-pin form (when no tags exist):
fetchFromGitHub {
  owner = "<owner>";
  repo = "<repo>";
  # Tracks main; bump SHA + hash to pull new upstream changes.
  rev = "<40-char-SHA>";
  hash = "sha256-...";
}
```

Refresh hash via `nix flake prefetch github:<owner>/<repo>/<rev> --json`
(source trees) or
`nix store prefetch-file --json --hash-type sha256 "<url>"` (raw files).

When **adding a new GitHub fetch**, apply this rule from the start — don't
write `rev = "main";` even as a placeholder. The auto-update sweep in
`scripts/AUTO-UPDATE-PLAYBOOK.md` will flag it on the next pass; saving the
trip is cheaper.

## Secrets (sops-nix)

- Encrypted files: `secrets/<username>.yaml`
- Declare in `nixosModules/security/sops.nix`
- Access: `config.sops.secrets."path/to/secret".path`
- Wrapper script pattern for env vars (see `homeManagerModules/code/claude-code.nix` for examples):
  ```nix
  wrapper = pkgs.writeShellScript "wrapper" ''
    export API_KEY="$(cat "${config.sops.secrets."key".path}")"
    exec ${pkg}/bin/cmd "$@"
  '';
  ```
- Guard secret declarations with `lib.mkIf config.<service>.enable`

## Adding a New Host

1. Create `hosts/<hostname>/configuration.nix` importing `../default.nix`
2. Generate `hardware-configuration.nix` via `nixos-generate-config`
3. Override only values that differ from `hosts/default.nix`
4. Add to `flake.nix`: `<hostname> = mkSystem { hostname = "<hostname>"; };`
5. Create `users/<user>/hosts/<hostname>.nix` importing `./default.nix` with overrides
6. Create disko config in `disko/` if needed

## MCP Server

The `nix` MCP tool searches packages, options, and docs across NixOS, Home Manager, nix-darwin, nixvim, FlakeHub, NixHub, wiki, and nix.dev. Use it instead of guessing package names or option paths.

The `nix_versions` MCP tool shows which nixpkgs commit shipped a specific package version.

## Formatting & Validation

- Format: `alejandra`

### Build verification policy

**Do NOT run `nixos-rebuild build` or `nixos-rebuild dry-build` to verify config changes.** Full-system builds take minutes and burn substantial CPU/IO per host — not worth it on routine edits. Trust the edit; the user runs `nh os switch` when ready and will surface real failures.

Build proactively **only** when:

- A custom package in `pkgs/` was added or modified. Build just that derivation so the package compiles in isolation — do not rebuild the whole system:
  ```sh
  nix build .#<pkg>          # if exposed in flake outputs
  nix-build -E '(import <nixpkgs> {}).callPackage ./pkgs/<name>/package.nix {}'
  ```
- The user explicitly asks ("test the build", "verify it builds", "build and switch", etc.).

Commands (for reference when explicitly invoked):

- Whole-system build-test: `nixos-rebuild build --flake .#<hostname>`
- Activation: `nh os switch` or `sudo nixos-rebuild switch --flake .#<hostname>`

## Commits

Follow the existing convention: `<Hostname>: description (Generation N built on YYYY-MM-DD)`

## Agent skills

### Issue tracker

Issues live as GitHub issues in `hailst0rm1/nixos` (via the `gh` CLI). See `docs/agents/issue-tracker.md`.

### Triage labels

Default canonical vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context — `CONTEXT.md` + `docs/adr/` at the repo root (created lazily by `/grill-with-docs`). See `docs/agents/domain.md`.

# currentDate
Today's date is 2026-05-10.
