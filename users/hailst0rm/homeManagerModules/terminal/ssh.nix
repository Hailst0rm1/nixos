{
  config,
  lib,
  ...
}: let
  cfg = config.importConfig.ssh;
in {
  options.importConfig.ssh.enable = lib.mkEnableOption "Enable ssh configuration.";

  config = lib.mkIf cfg.enable {
    programs.ssh = {
      enable = true;
      # enableDefaultConfig = false;
      extraConfig = ''
        Host github.com
          IdentityFile ~/.ssh/github

        Host git.pontonsecurity.com
          User git
          IdentityFile ~/.ssh/id_hailst0rm
          IdentitiesOnly yes
          PreferredAuthentications publickey

        Host nix-server
          HostName nix-server
          User hailst0rm
          IdentityFile ~/.ssh/yubia
          IdentityFile ~/.ssh/yubic
          IdentitiesOnly yes
          PreferredAuthentications publickey
      '';
    };
  };
}
