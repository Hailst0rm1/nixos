{inputs, ...}: let
  lib = inputs.nixpkgs.lib;
in {
  mkSystem = {hostname}: let
    # --- Overlays (defined first so they can be used everywhere)
    overlays =
      [
        inputs.nix-vscode-extensions.overlays.default
      ]
      ++ (
        lib.mapAttrsToList
        (name: _: import ../overlays/${name})
        (lib.filterAttrs
          (name: type: lib.hasSuffix ".nix" name && type == "regular")
          (builtins.readDir ../overlays))
      );

    # Evaluate the system configuration first (including Home Manager)
    evaluatedSystem = lib.nixosSystem {
      specialArgs = {
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
    hostPlatform = evaluatedSystem.config.nixpkgs.hostPlatform.system;
    myLocation = evaluatedSystem.config.myLocation;
    laptop = evaluatedSystem.config.laptop;
    redTools = evaluatedSystem.config.cyber.redTools.enable;
    sops = evaluatedSystem.config.security.sops.enable;

    # Graphic driver
    nvidiaEnabled = evaluatedSystem.config.graphicDriver.nvidia.enable;

    # Create pkgs-unstable using the detected host platform
    pkgs-unstable = import inputs.nixpkgs-unstable {
      system = hostPlatform;
      config.allowUnfree = true;
      overlays = overlays;
    };

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
            inherit inputs username hostname nixosDir hostPlatform myLocation laptop nvidiaEnabled redTools sops pkgs-unstable;
          };
        }
      ];
  in
    lib.nixosSystem {
      specialArgs = {
        inherit inputs hostname pkgs-unstable;
      };

      modules =
        [
          # System configuration
          ../hosts/${hostname}/configuration.nix

          # Pkgs Overlays (including pkgs-unstable as an overlay for consistency)
          {
            nixpkgs.overlays =
              [
                # inputs.hyprpanel.overlay
                # Make pkgs-unstable available as pkgs.pkgs-unstable too
                (_final: _prev: {
                  inherit pkgs-unstable;
                })
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
