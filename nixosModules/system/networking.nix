{ 
  lib,
  config,
  ...
}: {
  options.system.firewall.enable = lib.mkEnableOption "Turn on the firewall";

  config = {
    networking = {
      hostName = lib.mkDefault config.hostname;
      networkmanager.enable = true;

      firewall = lib.mkIf config.system.firewall.enable {
        enable = true;
      };

    # Configure network proxy if necessary
    # proxy.default = "http://user:password@proxy:port/";
    # proxy.noProxy = "127.0.0.1,localhost,internal.domain";
    };

  };

}
