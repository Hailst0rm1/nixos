{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  ...
}: {
  options.redTools.enable = lib.mkEnableOption "Enable Red Tooling";

  config = lib.mkIf config.redTools.enable {
    home.packages = [
      pkgs.openvpn
     
      # Red Tooling
      pkgs-unstable.nmap
    ];
  };
}

