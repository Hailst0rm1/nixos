{
  pkgs,
  lib,
  ...
}: {
  services.xserver = {
    enable = true;
    displayManager = {
      gdm.enable = lib.mkDefault true;
    };
    xkb.layout = "us";
  };
}

