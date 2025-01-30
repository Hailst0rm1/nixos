{ inputs, lib, config, ... }: {
  mkSystem = { hostname }:
    inputs.nixpkgs.lib.nixosSystem {
      specialArgs = {
        pkgs-unstable = import inputs.nixpkgs-unstable {
          #inherit system;
          config.allowUnfree = true;
        };

        inherit inputs hostname ;
      };

      modules = [
        # System configuration
        ../hosts/${hostname}/configuration.nix

        {nixpkgs.overlays = [ inputs.hyprpanel.overlay ];}

        # Home Manager configuration
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;

          home-manager.users.${config.username} = import ../users/${config.username}/hosts/${config.hostname}.nix;

          # Custom args
          home-manager.extraSpecialArgs = {
            pkgs-unstable = import inputs.nixpkgs-unstable {
              #inherit config.system;
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

    # Recursively constructs an attrset of a given folder, recursing on directories, value of attrs is the filetype
  getDir = dir: lib.mapAttrs
    (file: type:
      if type == "directory" then lib.getDir "${dir}/${file}" else type
    )
    (builtins.readDir dir);

  # Collects all files of a directory as a list of strings of paths
  files = dir: lib.collect lib.isString (lib.mapAttrsRecursive (path: type: lib.concatStringsSep "/" path) (lib.getDir dir));

  # Filters out directories that don't end with .nix or are this file, also makes the strings absolute
  validFiles = dir: map
    (file: ./. + "/${file}")
    (lib.filter
      (file: lib.hasSuffix ".nix" file && file != "default.nix" &&
        ! lib.hasPrefix "x/taffybar/" file &&
        ! lib.hasSuffix "-hm.nix" file)
      (lib.files dir));
}
