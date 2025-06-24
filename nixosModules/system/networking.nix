{
  lib,
  config,
  ...
}: {
  options = {
    security = {
      firewall.enable = lib.mkEnableOption "Turn on the firewall";
    };
    system = {
    };
  };

  config = {
    networking = {
      hostName = lib.mkDefault config.hostname;
      networkmanager.enable = true;
      nftables.enable = lib.mkIf (!config.cyber.redTools.enable) true;

      firewall = lib.mkIf config.security.firewall.enable {
        enable = lib.mkIf config.cyber.redTools.enable false; # Default is true
      };
    };
  };
}
