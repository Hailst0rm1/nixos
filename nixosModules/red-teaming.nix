{
  lib,
  config,
  ...
}: {
  config = lib.mkIf config.cyber.redTools.enable {
    # Enables editing of hosts file
    environment.etc.hosts.enable = false;
    environment.etc.hosts.mode = "0700";

    # Want to allow all incoming traffic
    networking = {
      firewall.enable = false;
    };

    # Configure proxy using proxychains for red-teaming lateral movement
    programs.proxychains = lib.mkIf config.cyber.redTools.enable {
      enable = true;
      quietMode = false;
      proxies = {
        pen-200 = {
          enable = true;
          type = "socks5";
          host = "192.168.173.63";
          port = 1337;
        };
      };
    };
  };
}
