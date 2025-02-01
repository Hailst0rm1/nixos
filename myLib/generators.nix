
{ inputs, ... }: {
  mkSystem = { hostname }:
    let
      # Evaluate the system configuration first (including Home Manager)
      evaluatedSystem = inputs.nixpkgs.lib.nixosSystem {
        specialArgs = {
          pkgs-unstable = import inputs.nixpkgs-unstable {
            system = "x86_64-linux"; # Not needed...?
            config.allowUnfree = true;
          };
          inherit inputs hostname;
        };

        modules = [
          ../hosts/${hostname}/configuration.nix
          inputs.home-manager.nixosModules.home-manager  # Required for nixos evaluation
        ];
      };

      # Extract values from the evaluated configuration
      username = evaluatedSystem.config.username;
      systemArch = evaluatedSystem.config.systemArch;
      nvidiaEnabled = evaluatedSystem.config.graphicDriver.nvidia.enable;

    in
    inputs.nixpkgs.lib.nixosSystem {
      specialArgs = {
        pkgs-unstable = import inputs.nixpkgs-unstable {
          system = systemArch;
          config.allowUnfree = true;
        };

        inherit inputs hostname;
      };

      modules = [
        # System configuration
        ../hosts/${hostname}/configuration.nix

        # Pkgs Overlays
        { nixpkgs.overlays = [ inputs.hyprpanel.overlay ]; }

        # Home Manager configuration
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;

          # Use dynamically extracted username
          home-manager.users.${username} = import ../users/${username}/hosts/${hostname}.nix;

          # Pass extracted config values
          home-manager.extraSpecialArgs = {
            pkgs-unstable = import inputs.nixpkgs-unstable {
              system = systemArch;
              config.allowUnfree = true;
            };

            inherit inputs nvidiaEnabled; # Add config here that HM may rely on
          };
        }
      ];
    };




  mkImage = {
    system,
    hostname,
    username,
    desktop,
    nixos-dir,
    format,
    diskSize,
  }:
    inputs.nixos-generators.nixosGenerate {
      inherit system format;

      specialArgs = {
        pkgs-unstable = import inputs.nixpkgs-unstable {
          inherit system;
          config.allowUnfree = true;
        };

        inherit inputs;
      };

      modules = [
        # System configuration
        ../hosts/${hostname}/configuration.nix

        # Home Manager configuration
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;

          home-manager.users.${username} = import ../users/${username}/hosts/${hostname}.nix;

          # Custom args
          home-manager.extraSpecialArgs = {
            pkgs-unstable = import inputs.nixpkgs-unstable {
              inherit system;
              config.allowUnfree = true;
            };

            inherit hostname username desktop nixos-dir;
          };
        }
      ];
    };

  #getModules = dir: lib.filter
    #(n: lib.strings.hasSuffix ".nix" n)
    #(lib.filesystem.listFilesRecursive "${dir}");

}
