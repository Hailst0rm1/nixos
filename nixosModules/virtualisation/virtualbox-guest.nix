{
  config,
  lib,
  ...
}: let
  cfg = config.virtualisation.guest.virtualbox;
in {
  options.virtualisation.guest.virtualbox = lib.mkEnableOption "Enable virtualbox guest.";

  config = lib.mkIf cfg {
    virtualisation.virtualbox.guest = {
      enable = true;
      clipboard = true;
      dragAndDrop = false;
    };

    boot.loader.systemd-boot.enable = lib.mkForce false;
  };
}
