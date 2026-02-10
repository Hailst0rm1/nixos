# The Vibe Companion - NixOS Package

This package provides The Vibe Companion, a web UI for Claude Code agents.

## Description

The Vibe Companion is a web interface that allows you to:
- Run multiple Claude Code sessions simultaneously
- Stream responses in real-time
- Visualize and approve tool calls
- Persist sessions across restarts
- Manage environment profiles
- Work with git worktrees

## Installation

### Using in NixOS Configuration

Add to your NixOS configuration or home-manager:

```nix
{ pkgs, ... }:
{
  environment.systemPackages = [
    (pkgs.callPackage ./pkgs/companion {})
  ];
}
```

Or in your flake:

```nix
{
  nixpkgs.overlays = [
    (final: prev: {
      the-vibe-companion = prev.callPackage ./pkgs/companion {};
    })
  ];
}
```

### Building Standalone

```bash
nix-build -E 'with import <nixpkgs> {}; callPackage ./package.nix {}'
```

## Usage

After installation, run:
```bash
the-vibe-companion
```

Then open your browser to http://localhost:3456

## Requirements

- Bun runtime (automatically provided by the package)
- Claude Code CLI must be installed separately
- An Anthropic API key configured for Claude Code

## Configuration

The companion stores configuration in `~/.companion/`:
- `envs/` - Environment profiles with API keys
- `worktrees/` - Git worktree mappings
- `session-names.json` - Session name mappings

## Environment Variables

- `PORT` - Server port (default: 3456)
- `NODE_ENV` - Environment mode (automatically set to production)

## Tech Stack

- **Runtime**: Bun
- **Backend**: Hono server
- **Frontend**: React 19, Vite, Tailwind v4
- **State Management**: Zustand

## Package Details

- **Version**: 0.14.0
- **Source**: GitHub (The-Vibe-Company/companion)
- **Build System**: Bun (native Bun package, not npm-based)
- **Build Type**: stdenv.mkDerivation (includes node_modules in output)

## Notes

- This package uses Bun's native build tooling
- The package includes all node_modules in the output for runtime dependencies
- Network access is required during build to fetch dependencies
- Tests are disabled as they require API keys and a full environment

## License

MIT
