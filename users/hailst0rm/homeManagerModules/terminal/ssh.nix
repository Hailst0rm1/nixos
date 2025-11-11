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
      enableDefaultConfig = false;

      matchBlocks = {
        # Default configuration for all hosts
        "*" = {
          forwardAgent = false;
          addKeysToAgent = "no";
          compression = false;
          serverAliveInterval = 0;
          serverAliveCountMax = 3;
          hashKnownHosts = false;
          userKnownHostsFile = "~/.ssh/known_hosts";
          controlMaster = "no";
          controlPath = "~/.ssh/master-%r@%n:%p";
          controlPersist = "no";
        };

        "github.com" = {
          identityFile = "~/.ssh/github";
        };

        "git.pontonsecurity.com" = {
          user = "git";
          identityFile = "~/.ssh/id_hailst0rm";
          identitiesOnly = true;
          extraOptions = {
            PreferredAuthentications = "publickey";
          };
        };

        "nix-server" = {
          hostname = "nix-server";
          user = "hailst0rm";
          identityFile = ["~/.ssh/yubia" "~/.ssh/yubic"];
          identitiesOnly = true;
          extraOptions = {
            PreferredAuthentications = "publickey";
          };
        };
      };
    };
  };
}
