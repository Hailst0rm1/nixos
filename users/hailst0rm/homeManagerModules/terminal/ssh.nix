{
  config,
  lib,
  ...
}: let
  cfg = config.importConfig.ssh;
  keysDir = ../../../../nixosModules/system/keys;
  pubKeys = builtins.attrNames (builtins.readDir keysDir);
in {
  options.importConfig.ssh.enable = lib.mkEnableOption "Enable ssh configuration.";

  config = lib.mkIf cfg.enable {
    # Write public keys to ~/.ssh/ (only when sops provides the private keys)
    home.file = lib.mkIf config.importConfig.sops.enable (lib.listToAttrs (map (keyFile: {
        name = ".ssh/${keyFile}";
        value.source = keysDir + "/${keyFile}";
      })
      pubKeys));

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
