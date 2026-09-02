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

      settings = {
        # Default configuration for all hosts
        "*" = {
          ForwardAgent = false;
          AddKeysToAgent = "no";
          Compression = false;
          ServerAliveInterval = 0;
          ServerAliveCountMax = 3;
          HashKnownHosts = false;
          UserKnownHostsFile = "~/.ssh/known_hosts";
          ControlMaster = "no";
          ControlPath = "~/.ssh/master-%r@%n:%p";
          ControlPersist = "no";
        };

        "github.com" = {
          IdentityFile = "~/.ssh/github";
          IdentitiesOnly = true;
        };

        # Second GitHub account (K-Dfirmed / Dfirmed org). Key selection has to
        # happen per-remote, not per-repo — a repo can hold remotes on both
        # accounts — so it hangs off the host alias rather than core.sshCommand.
        # terminal/git.nix rewrites Dfirmed URLs onto this alias automatically.
        "github-dfirmed" = {
          HostName = "github.com";
          User = "git";
          IdentityFile = "~/.ssh/github-dfirmed";
          IdentitiesOnly = true;
        };

        "git.pontonsecurity.com" = {
          User = "git";
          IdentityFile = "~/.ssh/id_hailst0rm";
          IdentitiesOnly = true;
          PreferredAuthentications = "publickey";
        };

        "nix-server" = {
          HostName = "nix-server";
          User = "hailst0rm";
          IdentityFile = ["~/.ssh/yubia" "~/.ssh/yubic"];
          IdentitiesOnly = true;
          PreferredAuthentications = "publickey";
        };
      };
    };
  };
}
