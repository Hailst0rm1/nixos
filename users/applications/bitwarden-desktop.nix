{ config, lib, pkgs, ... }:
let
  cfg = config.applications.bitwarden;
in {
  options.applications.bitwarden = {
    enable = lib.mkEnableOption "Enable bitwarden.";
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      pkgs.bitwarden-desktop
    ];
  };
}

