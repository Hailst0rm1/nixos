{
  config,
  lib,
  ...
}: let
  pubKeys = lib.filesystem.listFilesRecursive ./keys;
in {
  programs.ssh = {
    startAgent = true;
    enableAskPassword = false;

    # For yubikey
    extraConfig = ''
      AddKeysToAgent yes
      Host github.com
      IdentityFile ~/.ssh/github
    '';
  };

  # Enable the OpenSSH daemon.
  services.openssh = lib.mkIf config.services.openssh.enable {
    settings = {
      # Harden
      PasswordAuthentication = false;
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

  # Allows these users to SSH into the machine (All the public keys in ./keys)
  users.users.${config.username}.openssh.authorizedKeys.keys = lib.mkIf config.services.openssh.enable lib.lists.forEach pubKeys (key: builtins.readFile key);
}
