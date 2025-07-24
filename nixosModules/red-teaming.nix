{
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
      quietMode = false;
      proxies = {
        pen-200 = {
          enable = true;
          type = "socks5";
          host = "127.0.0.1";
          port = 4443;
        };
      };
    };
  };
}
