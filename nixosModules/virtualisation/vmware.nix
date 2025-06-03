{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}: let
  cfg = config.virtualisation.host.vmware;
in {
  options.virtualisation.host.vmware = lib.mkEnableOption "Enable vmware host";

  config = lib.mkIf cfg {
    virtualisation.vmware.host.enable = true;
    virtualisation.vmware.host.package = pkgs-unstable.vmware-workstation;

    boot.kernelParams = ["transparent_hugepage=never"];

    # Add VMware kernel modules for zen
    boot.extraModulePackages = lib.mkIf (config.system.kernel == "zen") [
      pkgs.linuxKernel.packages.linux_zen.vmware
    ];

    # Dark theme (applied in HM-stylix manually)
    environment.systemPackages = [pkgs.gnome-themes-extra];
  };
}
