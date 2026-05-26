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

# currentDate
Today's date is 2026-05-10.
