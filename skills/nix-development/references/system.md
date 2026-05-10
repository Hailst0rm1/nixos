# NixOS System Configuration

## Flake Structure

A NixOS flake typically has:

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    # Additional inputs...
  };

  outputs = { self, nixpkgs, ... }@inputs: {
    nixosConfigurations.hostname = nixpkgs.lib.nixosSystem {
      specialArgs = { inherit inputs; };
      modules = [ ./hosts/hostname/configuration.nix ];
    };
  };
}
```

### Input Management

```bash
# Update all inputs
nix flake update

# Update a single input
nix flake lock --update-input nixpkgs

# Show flake outputs
nix flake show

# Check flake validity
nix flake check
```

### Following Inputs

To avoid duplicate nixpkgs instances, use `follows`:

```nix
home-manager.inputs.nixpkgs.follows = "nixpkgs";
```

This ensures home-manager uses the same nixpkgs as your system.

### Adding a New Flake Input

1. Add to `inputs` block in `flake.nix`
2. Add `follows` for nixpkgs if applicable
3. Access in modules via `inputs` specialArg: `inputs.<name>.nixosModules.<module>`
4. Run `nix flake lock` to generate the lock entry

## Service Configuration

### NixOS Service Pattern

```nix
{ config, lib, pkgs, ... }: let
  cfg = config.services.myapp;
in {
  options.services.myapp = {
    enable = lib.mkEnableOption "My application";
    port = lib.mkOption {
      type = lib.types.port;
      default = 3000;
    };
  };

  config = lib.mkIf cfg.enable {
    systemd.services.myapp = {
      description = "My Application";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        ExecStart = "${pkgs.myapp}/bin/myapp --port ${toString cfg.port}";
        Restart = "on-failure";
        DynamicUser = true;
        StateDirectory = "myapp";
      };
    };

    # Open firewall port
    networking.firewall.allowedTCPPorts = [ cfg.port ];
  };
}
```

### Container Services (Podman/Docker)

```nix
virtualisation.oci-containers.containers.myapp = {
  image = "myapp:latest";
  ports = ["8080:8080"];
  environment = {
    KEY = "value";
  };
  volumes = ["/var/lib/myapp:/data"];
};
```

## Secrets Management (sops-nix)

### Setup

sops-nix encrypts secrets at rest and decrypts them at activation time. Secrets are accessible as files under `/run/secrets/`.

### Declaring Secrets

```nix
sops.secrets."services/myapp/api-key" = {
  owner = config.username;
  group = "users";
  mode = "0400";
};
```

### Using Secrets in Services

```nix
# As environment file
systemd.services.myapp.serviceConfig.EnvironmentFile =
  config.sops.secrets."services/myapp/env".path;

# As individual file
systemd.services.myapp.serviceConfig.ExecStart = let
  wrapper = pkgs.writeShellScript "myapp-wrapper" ''
    export API_KEY="$(cat ${config.sops.secrets."services/myapp/api-key".path})"
    exec ${pkgs.myapp}/bin/myapp "$@"
  '';
in "${wrapper}";
```

### Wrapper Script Pattern

For MCP servers and tools that need secrets as environment variables:

```nix
let
  keyPath = config.sops.secrets."services/myapp/key".path;
  wrapper = pkgs.writeShellScript "myapp-wrapper" ''
    KEY_FILE="${keyPath}"
    if [ -f "$KEY_FILE" ]; then
      export API_KEY="$(cat "$KEY_FILE")"
    fi
    exec ${pkg}/bin/myapp "$@"
  '';
in {
  # Use wrapper instead of direct binary
}
```

### Editing Secrets

```bash
sops secrets/<username>.yaml  # Opens in $EDITOR, decrypts in-memory
```

Requires the age key to be available at `~/.config/sops/age/keys.txt` or via SSH key.

## Rebuild Commands

```bash
# Test build (no switch)
nixos-rebuild build --flake .#hostname

# Switch to new configuration
sudo nixos-rebuild switch --flake .#hostname

# Build and switch with nh (user-friendly wrapper)
nh os switch

# Rollback to previous generation
sudo nixos-rebuild switch --rollback

# List generations
nix-env --list-generations --profile /nix/var/nix/profiles/system
```

## Debugging

```bash
# Interactive Nix evaluator
nix repl
# Then: :lf .   (load current flake)
# Then: nixosConfigurations.hostname.config.services.nginx

# Evaluate an expression
nix eval .#nixosConfigurations.hostname.config.services.nginx.enable

# Build with full logs
nix build --print-build-logs .#nixosConfigurations.hostname.config.system.build.toplevel

# Show what changed between generations
nix store diff-closures /nix/var/nix/profiles/system-{N-1}-link /nix/var/nix/profiles/system-{N}-link
```

## Using MCP for System Configuration

### Discovering Options

Before adding any NixOS option, verify it exists:

```
nix {"action":"search","query":"services.nginx","type":"options"}
```

For Home Manager options:
```
nix {"action":"search","source":"home-manager","query":"programs.zsh"}
```

### Checking Package Availability

Before adding packages, verify the attribute path:

```
nix {"action":"info","query":"package-name","channel":"unstable"}
```

Check if a package has a binary substitute (avoids building from source):
```
nix {"action":"cache","query":"package-name"}
```

### Reference Links

- NixOS Manual: https://nixos.org/manual/nixos/stable/
- NixOS Options Search: https://search.nixos.org/options
- Home Manager Options: https://nix-community.github.io/home-manager/options.html
- nix.dev tutorials: https://nix.dev/
- Nixpkgs Manual: https://nixos.org/manual/nixpkgs/stable/
- MCP NixOS Server: https://github.com/utensils/mcp-nixos
