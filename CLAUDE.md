# NixOS Configuration Conventions

Project-specific rules for this NixOS configuration repository.

## Module Structure
- Use `lib.mkEnableOption` for boolean options
- Use `lib.mkIf` for conditional configuration
- Structure modules with proper imports and options
- Use `let...in` for complex attribute sets
- Prefer functional programming patterns
- Keep functions small and focused (single responsibility)

## Package Channels
- Prefer `pkgs-unstable` for latest versions when needed
- Use `pkgs` (stable) for system-critical packages

## Formatting & Style
- Use `nixfmt` for formatting Nix files
- Follow Nix best practices and RFC conventions
- Use clear, descriptive variable and function names
- Group related functionality together
- Add comments for complex logic, not obvious code

## Validation
- Run `nixos-rebuild build` to verify changes before switching
- Test configuration changes before deployment
- Consider edge cases and failure modes

## Commits
- Write clear commit messages (conventional commits style)
- Document non-obvious design decisions
