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
      nftables.enable = true;

      firewall = lib.mkIf config.security.firewall.enable {
        enable = true;
        allowedTCPPorts = lib.mkIf config.cyber.redTools.enable [ 80 443 1337 4444 ];
      };

    # Configure network proxy if necessary
    # proxy.default = "http://user:password@proxy:port/";
    # proxy.noProxy = "127.0.0.1,localhost,internal.domain";
    };

  };

}
