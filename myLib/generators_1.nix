{ inputs, ... }: {
  mkSystem = { hostname }:
    let
      # Evaluate the NixOS system to extract config values
      #evaluatedSystem = inputs.nixpkgs.lib.nixosSystem {
        #modules = [ ../hosts/${hostname}/configuration.nix ];
      #};

      # Extract values from evaluated configuration
      #systemArch = evaluatedSystem.config.systemArch;
      systemArch = "x86_64-linux";
      #username = evaluatedSystem.config.username;
      username = "hailst0rm";
      #inherit (import ../hosts/${hostname}/configuration.nix) systemArch username;
    in
    inputs.nixpkgs.lib.nixosSystem {
      specialArgs = {
        pkgs-unstable = import inputs.nixpkgs-unstable {
          #inherit systemArch;
          system = systemArch;
          config.allowUnfree = true;
        };

        inherit inputs hostname;
      };

      modules = [
        # System configuration
        ../hosts/${hostname}/configuration.nix

        {nixpkgs.overlays = [ inputs.hyprpanel.overlay ];}

        # Home Manager configuration
        #./homeManager.nix
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;

          home-manager.users.${username} = import ../users/${username}/hosts/${hostname}.nix;

          # Custom args
          home-manager.extraSpecialArgs = {
            pkgs-unstable = import inputs.nixpkgs-unstable {
              system = systemArch;
              #inherit systemArch;
              config.allowUnfree = true;
            };

            inherit inputs;
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
