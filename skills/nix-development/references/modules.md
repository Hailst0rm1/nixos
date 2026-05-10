# NixOS & Home Manager Module Development

## Module Anatomy

Every NixOS/HM module is a function that returns an attrset with `options` and/or `config`:

```nix
{ config, lib, pkgs, ... }: let
  cfg = config.<namespace>;
in {
  options.<namespace> = {
    enable = lib.mkEnableOption "description of feature";
    setting = lib.mkOption {
      type = lib.types.str;
      default = "value";
      description = "What this setting controls";
    };
  };

  config = lib.mkIf cfg.enable {
    # Configuration applied when enabled
  };
}
```

## Common Patterns

### Basic Enable Pattern

The most common module shape. The `cfg` shorthand avoids repeating the full config path:

```nix
{ config, lib, pkgs, ... }: let
  cfg = config.services.myService;
in {
  options.services.myService = {
    enable = lib.mkEnableOption "my service";
    port = lib.mkOption {
      type = lib.types.port;
      default = 8080;
      description = "Port to listen on";
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.myService = {
      wantedBy = ["multi-user.target"];
      serviceConfig.ExecStart = "${pkgs.myService}/bin/myService --port ${toString cfg.port}";
    };
  };
}
```

### String-Switched Pattern

When behavior depends on a string value rather than a boolean:

```nix
{ config, lib, ... }: let
  cfg = config.desktopEnvironment.name;
in {
  config = lib.mkIf (cfg == "hyprland") {
    # Hyprland-specific configuration
  };
}
```

### Multi-Condition Pattern

Use `lib.mkMerge` when a module needs multiple conditional blocks:

```nix
{ config, lib, ... }: {
  config = lib.mkMerge [
    (lib.mkIf config.services.foo.enable {
      # foo-specific config
    })
    (lib.mkIf config.services.bar.enable {
      # bar-specific config
    })
    {
      # unconditional config
    }
  ];
}
```

### Nested Enable Options

Group related options under a parent namespace:

```nix
options.services.mcp = {
  enable = lib.mkEnableOption "MCP server configuration";
  servers = {
    nixos = { enable = lib.mkEnableOption "NixOS MCP server"; };
    discord = { enable = lib.mkEnableOption "Discord MCP server"; };
  };
};
```

## Option Types

| Type | Description | Example |
|------|-------------|---------|
| `lib.types.str` | String | `"hello"` |
| `lib.types.int` | Integer | `42` |
| `lib.types.bool` | Boolean | `true` |
| `lib.types.port` | Port number (0-65535) | `8080` |
| `lib.types.path` | File path | `/etc/config` |
| `lib.types.listOf T` | List of type T | `["a" "b"]` |
| `lib.types.attrsOf T` | Attrset with values of type T | `{ key = "val"; }` |
| `lib.types.enum [...]` | One of listed values | `"a"` from `["a" "b"]` |
| `lib.types.nullOr T` | T or null | `null` or `"value"` |
| `lib.types.submodule { options = ...; }` | Nested module | Complex structure |
| `lib.types.anything` | Any value | Escape hatch |

## Option Modifiers

| Modifier | Priority | Use |
|----------|----------|-----|
| `lib.mkDefault val` | 1000 (low) | Set overrideable defaults in host/default configs |
| Normal assignment | 100 | Standard priority |
| `lib.mkForce val` | 50 (high) | Force override, use sparingly |
| `lib.mkOverride N val` | N | Explicit priority control |
| `lib.mkIf bool val` | — | Conditional value |
| `lib.mkMerge [...]` | — | Merge multiple definitions |

The priority system means `lib.mkDefault` values can be overridden by normal assignments, and `lib.mkForce` overrides everything. This enables the default chain pattern (defaults.nix sets mkDefault, host configs override).

## Home Manager Specifics

HM modules follow the same patterns but with HM-specific options:

### Common HM Options
```nix
# Install packages for the user
home.packages = with pkgs; [ ripgrep fd ];

# Manage dotfiles
home.file.".config/app/config.toml".text = ''
  setting = true
'';

# XDG config files
xdg.configFile."app/config.toml".source = ./config.toml;

# Program-specific modules
programs.git = {
  enable = true;
  userName = "name";
};

# Systemd user services
systemd.user.services.myservice = { ... };
```

### Accessing NixOS Config from HM

Use `osConfig` to read NixOS-level configuration:

```nix
{ config, osConfig, lib, ... }: {
  # Conditionally enable based on NixOS option
  importConfig.sops.enable = lib.mkDefault osConfig.security.sops.enable;

  # Read NixOS values
  home.file.".config/app".text = ''
    hostname = ${osConfig.hostname}
  '';
}
```

### HM Module Arguments

HM modules receive these arguments:
- `config` — HM config (home-manager level)
- `osConfig` — NixOS config (system level)
- `lib` — nixpkgs lib
- `pkgs` — system packages (with overlays)
- `pkgs-unstable` — unstable packages (via extraSpecialArgs)
- `inputs` — flake inputs (via extraSpecialArgs)

## Anti-Patterns

- **Manual imports for auto-imported modules** — files in `nixosModules/` and `homeManagerModules/` are auto-imported; adding them to `imports` causes duplicate definition errors
- **Using mkDefault in module definitions** — mkDefault belongs in host/default configs, not in the module that defines the option. Use `default = ...` in `mkOption` instead
- **Mixing options and config without mkMerge** — if you have multiple `mkIf` blocks, wrap them in `mkMerge`
- **Hardcoding paths** — use `config.nixosDir`, `config.home.homeDirectory`, or option values
- **Guessing option paths** — always verify with the MCP `nix` tool first
