---
name: nix-development
description: NixOS and Nix ecosystem development - creating modules, packaging software, writing overlays, configuring systems, managing flakes, Home Manager, sops-nix secrets, and using the MCP NixOS server for package/option discovery. Use this skill whenever working with .nix files, NixOS configuration, Home Manager modules, Nix derivations, overlays, flake inputs, nixos-rebuild, mkDerivation, mkOption, mkEnableOption, mkIf, or any Nix packaging task. Also use when searching for NixOS options, packages, or debugging Nix build failures. Even if the task seems simple, consult this skill for correct patterns and MCP server usage.
---

# Nix Development

Comprehensive guide for NixOS module development, package creation, and system configuration. Uses the MCP NixOS server for live package and option discovery.

## MCP NixOS Server

Always use the MCP server instead of guessing package names, option paths, or versions. Two tools are available:

### `nix` tool — Search and info

| Intent | Call |
|--------|------|
| Search packages | `nix {"action":"search","query":"package-name"}` |
| Package info in channel | `nix {"action":"info","query":"package-name","channel":"unstable"}` |
| Search NixOS options | `nix {"action":"search","query":"services.nginx","type":"options"}` |
| Home Manager options | `nix {"action":"search","source":"home-manager","query":"programs.git"}` |
| nix-darwin options | `nix {"action":"search","source":"darwin","query":"services"}` |
| Nixvim options | `nix {"action":"search","source":"nixvim","query":"plugins.telescope"}` |
| Check binary cache | `nix {"action":"cache","query":"package-name"}` |
| Available channels | `nix {"action":"channels"}` |
| Flake inputs | `nix {"action":"flake-inputs","query":"github:owner/repo"}` |
| Read store path | `nix {"action":"store","type":"read","query":"/nix/store/..."}` |
| Search Noogle (functions) | `nix {"action":"search","source":"noogle","query":"lib.mkOption"}` |
| NixOS Wiki | `nix {"action":"search","source":"wiki","query":"topic"}` |
| nix.dev docs | `nix {"action":"search","source":"nix-dev","query":"topic"}` |

### `nix_versions` tool — Version history

| Intent | Call |
|--------|------|
| Which commit shipped version X? | `nix_versions {"package":"name","version":"1.0"}` |
| All versions of a package | `nix_versions {"package":"name"}` |

### When to use MCP

- Before writing any `environment.systemPackages` or `home.packages` — verify the attribute path
- Before using any NixOS/HM option — verify it exists and check its type
- When debugging "attribute not found" errors — search for the correct path
- When choosing between stable and unstable — check what version each channel has

## Reference Routing

Read the appropriate reference file based on what you're doing:

| Task | Reference |
|------|-----------|
| Creating or modifying NixOS/HM modules, options, types | Read `references/modules.md` |
| Creating packages, derivations, overlays, fetchers | Read `references/packages.md` |
| System configuration, flakes, secrets, services, hosts | Read `references/system.md` |

Read only what you need — each reference is self-contained.

## Quick Patterns (for simple tasks without loading references)

### Module enable pattern
```nix
{ config, lib, ... }: let
  cfg = config.namespace;
in {
  options.namespace.enable = lib.mkEnableOption "feature";
  config = lib.mkIf cfg.enable { };
}
```

### Package in overlay
```nix
# overlays/name.nix
final: prev: {
  name = prev.callPackage ../pkgs/name/package.nix {};
}
```

### Fetcher with hash
```nix
src = pkgs.fetchFromGitHub {
  owner = "owner"; repo = "repo"; rev = "v1.0";
  hash = ""; # Build once to get correct hash from error
};
```
