{
  config,
  lib,
  pkgs-unstable,
  ...
}: {
  programs.ssh = {
    startAgent = true;
    enableAskPassword = false;

    # For yubikey
    extraConfig = ''
      AddKeysToAgent yes

      Host github.com
        IdentityFile ~/.ssh/github

      Host git.${config.services.domain}
        HostName git.${config.services.domain}
        ProxyCommand ${pkgs-unstable.cloudflared}/bin/cloudflared access ssh --hostname %h
        User git
        IdentityFile ~/.ssh/id_hailst0rm
        IdentitiesOnly yes
        PreferredAuthentications publickey
    '';
  };

  # Enable the OpenSSH daemon.
  services.openssh = lib.mkIf config.services.openssh.enable {
    settings = {
      # Harden
      PasswordAuthentication = lib.mkIf config.security.sops.enable false;
      PubkeyAuthentication = true;
      PermitRootLogin = "no";
      # Automatically remove stale sockets
      StreamLocalBindUnlink = "yes";
      # Allow forwarding ports to everywhere
      GatewayPorts = "clientspecified";
    };
  };

  # yubikey login / sudo
  security.pam = {
    rssh.enable = true;
    services.sudo.rssh = true;
  };

  networking.firewall.allowedTCPPorts = [22];

  # Allows these users to SSH into the machine (All the public keys in ./keys)
  # users.users.${config.username}.openssh.authorizedKeys.keys = lib.mkIf config.services.openssh.enable lib.lists.forEach ./keys (key: builtins.readFile key);
  users.users.${config.username}.openssh.authorizedKeys.keys = lib.mkIf config.services.openssh.enable (
    lib.forEach (builtins.attrNames (builtins.readDir ./keys)) (
      keyFile:
        builtins.readFile (./keys + "/${keyFile}")
    )
  );
}
