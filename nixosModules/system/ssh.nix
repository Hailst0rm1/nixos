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
    '';
  };

  # Enable the OpenSSH daemon.
  services.openssh = lib.mkIf config.services.openssh.enable {
    settings = {
      PasswordAuthentication = true;
      PubkeyAuthentication = true;
      PermitRootLogin = "no";
      LogLevel = "DEBUG";
    };
  };

  # Allows these users to SSH into the machine (All the public keys in ./keys)
  users.users.${config.username}.openssh.authorizedKeys.keys = lib.mkIf config.services.openssh.enable lib.lists.forEach pubKeys (key: builtins.readFile key);
}
