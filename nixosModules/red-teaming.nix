{
  pkgs,
  lib,
  config,
  ...
}: {
  config = lib.mkIf config.cyber.redTools.enable {
    # Enable OpenSSH for tunneling etc.
    services.openssh.enable = lib.mkForce true;

    # Want to allow all incoming traffic
    networking = {
      firewall.enable = false;
    };

    # For bloodhound
    services.neo4j = {
      enable = true;
      bolt = {
        tlsLevel = "DISABLED"; # Disable Bolt encryption to avoid the SSL policy error
      };
      https.enable = false;
    };

    # Replaced with lingolo-ng
    # Configure proxy using proxychains for red-teaming lateral movement
    programs.proxychains = lib.mkIf config.cyber.redTools.enable {
      enable = false; # Set to true to reactivate
      package = pkgs.proxychains-ng;
      quietMode = false;
      proxies = {
        pen-200 = {
          enable = true;
          type = "http";
          host = "192.168.145.224";
          port = 3128;
        };
      };
    };

    # Override the generated config to add credentials
    # environment.etc."proxychains.conf" = lib.mkIf config.cyber.redTools.enable {
    #   text = lib.mkForce ''
    #     strict_chain
    #     quiet_mode
    #     tcp_read_time_out 15000
    #     tcp_connect_time_out 8000

    #     [ProxyList]
    #     http 192.168.145.224 3128 ext_acc DoNotShare!SkyLarkLegacyInternal2008
    #   '';
    # };
  };
}
