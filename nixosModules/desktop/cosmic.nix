{ inputs, lib, config, ...}:
let
  cfg = config.nixosModules.desktop.cosmic;
in {
  nix.settings = {
    substituters = ["https://cosmic.cachix.org/"];
    trusted-public-keys = ["cosmic.cachix.org-1:Dya9IyXD4xdBehWjrkPv6rtxpmMdRel02smYzA85dPE="];
  };

  options.nixosModules.desktop.cosmic = {
    enable = lib.enableOption "Enables the cosmic DE.";
  };

  config = lib.mkIf cfg.enable {
    imports = [inputs.nixos-cosmic.nixosModules.default];

    services.desktopManager.cosmic.enable = true;
    services.displayManager.cosmic-greeter.enable = true;
  };
}

