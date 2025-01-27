{ 
  lib,
  hostname,
  ...
}: {
  networking = {
    hostName = lib.mkDefault hostname;
    networkmanager.enable = true;

    firewall = {
      enable = true;
    };

  # Configure network proxy if necessary
  # proxy.default = "http://user:password@proxy:port/";
  # proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  };

}
