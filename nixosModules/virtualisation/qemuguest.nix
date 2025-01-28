{ config, lib, ...}:
let
  cfg = config.virtualisation.guest.qemu;
in {
  options.virtualisation.guest.qemu = lib.mkEnableOption "Enable qemu guest.";

  config = lib.mkIf cfg {
    services = {
      xserver.videoDrivers = ["qxl bochs_drm"];
      rpcbind.enable = true;
      nfs.server.enable = true;
      spice-vdagentd.enable = true;
      qemuGuest.enable = true;
    };
  };
}

