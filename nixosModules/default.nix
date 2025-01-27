{
  config,
  lib,
  ...
}: let
  cfg = config.nixosModules;
in {

  options.nixosModules = {
    default = lib.enableOption "Applies the default NixOS modules.";
  };

  config = lib.mkIf cfg.default {
    nixosModules = {
      # Gnome as default desktop: desktop/gnome.nix
      desktop.gnome.enable = true;

      # Vmware: virtualisation/vmware.nix
      virtualisation.vmware.enable = true;

      # system/default.nix
      system.default.enable = true;
    };
  };
  
  imports = lib.mkIf cfg.default [
    ./desktop/${config.desktop}.nix

    ./virtualisation/vmware.nix
    ./system
  ];
}

