{inputs, ...}: let
  lib = inputs.nixpkgs.lib;
in {
  mkSystem = {hostname}: let
    # Evaluate the system configuration first (including Home Manager)
    evaluatedSystem = lib.nixosSystem {
      specialArgs = {
        pkgs-unstable = import inputs.nixpkgs-unstable {
          system = "x86_64-linux"; # Required...
          config.allowUnfree = true;
        };
        inherit inputs hostname;
      };

      modules = [
        ../hosts/${hostname}/configuration.nix
        inputs.home-manager.nixosModules.home-manager # Required for nixos evaluation
      ];
    };

    # --- Extract values from the evaluated configuration

    # Variables.nix
    username = evaluatedSystem.config.username;
    nixosDir = evaluatedSystem.config.nixosDir;
    systemArch = evaluatedSystem.config.systemArch;
    myLocation = evaluatedSystem.config.myLocation;
    laptop = evaluatedSystem.config.laptop;
    redTools = evaluatedSystem.config.cyber.redTools.enable;
    sops = evaluatedSystem.config.security.sops.enable;

    # Graphic driver
    nvidiaEnabled = evaluatedSystem.config.graphicDriver.nvidia.enable;

    # --- Home Manager configuration
    homeManager =
      []
      ++ lib.optionals (builtins.pathExists ../users/${username}/hosts/${hostname}.nix) [
        inputs.home-manager.nixosModules.home-manager
        {
          home-manager.useGlobalPkgs = true;
          home-manager.useUserPackages = true;

          # Use dynamically extracted username
          home-manager.users.${username} = import ../users/${username}/hosts/${hostname}.nix;

          # Pass extracted config values (custom args passed to HM)
          home-manager.extraSpecialArgs = {
            pkgs-unstable = import inputs.nixpkgs-unstable {
              system = systemArch;
              config.allowUnfree = true;
            };

            inherit inputs username hostname nixosDir systemArch myLocation laptop nvidiaEnabled redTools sops; # Add config here that HM may rely on
          };
        }
      ];

    # --- Overlays
    overlays =
      []
      ++ (
        lib.mapAttrsToList
        (name: _: import ../overlays/${name})
        (lib.filterAttrs
          (name: type: lib.hasSuffix ".nix" name && type == "regular")
          (builtins.readDir ../overlays))
      );
  in
    lib.nixosSystem {
      specialArgs = {
        pkgs-unstable = import inputs.nixpkgs-unstable {
          system = systemArch;
          config.allowUnfree = true;
        };

        inherit inputs hostname;
      };

      modules =
        [
          # System configuration
          ../hosts/${hostname}/configuration.nix

          # Pkgs Overlays
          {
            nixpkgs.overlays =
              [
                inputs.hyprpanel.overlay
              ]
              ++ overlays;
          }
        ]
        ++ homeManager;
    };

  # TODO: FIX LIKE SYSTEM
  # mkImage = {
  #   system,
  #   hostname,
  #   username,
  #   desktop,
  #   nixos-dir,
  #   format,
  #   diskSize,
  # }:
  #   inputs.nixos-generators.nixosGenerate {
  #     inherit system format;

  #     specialArgs = {
  #       pkgs-unstable = import inputs.nixpkgs-unstable {
  #         inherit system;
  #         config.allowUnfree = true;
  #       };

  #       inherit inputs;
  #     };

  #     modules = [
  #       # System configuration
  #       ../hosts/${hostname}/configuration.nix

  #       # Home Manager configuration
  #       inputs.home-manager.nixosModules.home-manager
  #       {
  #         home-manager.useGlobalPkgs = true;
  #         home-manager.useUserPackages = true;

  #         home-manager.users.${username} = import ../users/${username}/hosts/${hostname}.nix;

  #         # Custom args
  #         home-manager.extraSpecialArgs = {
  #           pkgs-unstable = import inputs.nixpkgs-unstable {
  #             inherit system;
  #             config.allowUnfree = true;
  #           };

  #           inherit hostname username desktop nixos-dir;
  #         };
  #       }
  #     ];
  #   };
}
