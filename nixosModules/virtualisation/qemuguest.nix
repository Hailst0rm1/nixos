{...}: {
  services = {
    xserver.videoDrivers = ["qxl bochs_drm"];
    rpcbind.enable = true;
    nfs.server.enable = true;
    spice-vdagentd.enable = true;
    qemuGuest.enable = true;
  };
}

