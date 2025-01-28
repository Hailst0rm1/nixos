{ config, lib, pkgs, ...}:
let
  cfg = config.virtualisation.host.vmware;
in{
  options.virtualisation.host.vmware = lib.mkEnableOption "Enable vmware host";

  config = lib.mkIf cfg {
    virtualisation.vmware.host.enable = true;
    virtualisation.vmware.host.package = pkgs.vmware-workstation;
  };
}
