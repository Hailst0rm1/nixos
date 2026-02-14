{inputs, ...}: let
  lib = inputs.nixpkgs.lib;
in {
  mkSystem = {
    hostname,
    username ? "hailst0rm",
  }: let
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

    # Create pkgs-unstable (all hosts are x86_64-linux)
    pkgs-unstable = import inputs.nixpkgs-unstable {
      system = "x86_64-linux";
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

          home-manager.users.${username} = {
            imports = [../users/${username}/hosts/${hostname}.nix];

            # Set identity values so HM modules can read config.hostname etc.
            hostname = hostname;
            username = username;
          };

          # Only pass what HM modules can't get from the module system
          home-manager.extraSpecialArgs = {
            inherit inputs pkgs-unstable;
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
