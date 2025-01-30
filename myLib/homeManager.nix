{ inputs, config, ... }: {
  imports = [ inputs.home-manager.nixosModules.home-manager ];

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
