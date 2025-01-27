{
  pkgs, 
  username,
  ...
}: {
  services.xserver.videoDrivers = ["vmware"];
  virtualisation.vmware.guest.enable = true;

  # Auto Mount fileshare
  programs.fuse.userAllowOther = true;
  system.fsPackages = [pkgs.open-vm-tools];

  fileSystems."/home/${username}/shares" = {
    device = ".host:/";
    fsType = "fuse./run/current-system/sw/bin/vmhgfs-fuse";
    options = ["umask=22" "uid=1000" "gid=1000" "allow_other" "defaults" "auto_unmount"];
  };
}

