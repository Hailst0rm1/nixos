{
  pkgs,
  lib,
  config,
  osConfig,
  ...
}: let
  cfg = config.importConfig.zsh-history-sync;

  # Per-machine paths. The live HISTFILE is local-only (git never touches it);
  # the synced clone and the throwaway merged view live elsewhere.
  histFile = "${config.xdg.dataHome}/zsh/history";
  repoDir = "${config.home.homeDirectory}/.config/zsh-history-repo";
  stateDir = "${config.xdg.stateHome}/zsh-history-sync";
  mergedFile = "${stateDir}/merged.zhist";
  hostName = osConfig.networking.hostName;

  # The sync engine — validated standalone (see zsh-history-sync.sh). readFile
  # avoids escaping every bash ${...} through the Nix string parser; PATH is
  # baked so the script works identically under a systemd user service.
  zhs = pkgs.writeShellScriptBin "zsh-history-sync" ''
    export PATH=${lib.makeBinPath [pkgs.git pkgs.openssh pkgs.gawk pkgs.coreutils pkgs.util-linux]}:"$PATH"
    ${builtins.readFile ./zsh-history-sync.sh}
  '';

  # Environment shared by every unit. GIT_SSH_COMMAND is quoted so systemd keeps
  # the spaced value as a single assignment.
  syncEnv =
    [
      "ZHS_HISTFILE=${histFile}"
      "ZHS_REPO_DIR=${repoDir}"
      "ZHS_REPO_URL=${cfg.repoUrl}"
      "ZHS_HOST=${hostName}"
      "ZHS_STATE_DIR=${stateDir}"
      "ZHS_BRANCH=${cfg.branch}"
      "HOME=${config.home.homeDirectory}"
    ]
    # By default git uses your normal SSH key (resolved via ~/.ssh/config), which
    # already authenticates non-interactively in a systemd user service — no agent
    # needed. Only force a dedicated key when deployKeyPath is set; IdentitiesOnly
    # then makes ssh use ONLY that key, so leave it null to keep the existing key.
    ++ lib.optional (cfg.deployKeyPath != null)
    ''GIT_SSH_COMMAND="ssh -i ${cfg.deployKeyPath} -o IdentitiesOnly=yes -o StrictHostKeyChecking=accept-new"'';
in {
  options.importConfig.zsh-history-sync = {
    enable = lib.mkEnableOption "per-host append-only zsh history sync across devices via a GitHub repo";

    repoUrl = lib.mkOption {
      type = lib.types.str;
      default = "git@github.com:Hailst0rm1/zsh-history.git";
      description = "SSH URL of the history sync repository.";
    };

    branch = lib.mkOption {
      type = lib.types.str;
      default = "main";
      description = "Branch in the sync repository to push/pull.";
    };

    deployKeyPath = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = ''
        Optional. Path to a dedicated passphrase-less SSH private key for the sync
        repo. Leave null (the default) to use your normal SSH key via ~/.ssh/config,
        which already authenticates fine inside the systemd user services. Only set
        this if you want an isolated deploy key — note IdentitiesOnly=yes then makes
        ssh use ONLY this key.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [zhs pkgs.git];

    # zsh integration: this host's own history stays in $HISTFILE (auto-loaded);
    # cross-machine history is loaded read-only from the merged view. SHARE_HISTORY
    # off + INC_APPEND_HISTORY keeps $HISTFILE a clean single-writer record so the
    # merged entries never get written back into it. Runs last (mkOrder 1500).
    programs.zsh.initContent = lib.mkOrder 1500 ''
      unsetopt SHARE_HISTORY
      setopt INC_APPEND_HISTORY HIST_FIND_NO_DUPS EXTENDED_HISTORY
      [[ -r "${mergedFile}" ]] && fc -R "${mergedFile}"
    '';

    # Login: pull remote host files and rebuild the merged view.
    systemd.user.services.zsh-history-sync = {
      Unit = {
        Description = "Pull zsh history from GitHub and rebuild merged view";
        After = ["network-online.target"];
        Wants = ["network-online.target"];
      };
      Service = {
        Type = "oneshot";
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 5";
        ExecStart = "${zhs}/bin/zsh-history-sync pull";
        Environment = syncEnv;
        StandardOutput = "journal";
        StandardError = "journal";
        TimeoutStartSec = "120s";
      };
      Install.WantedBy = ["default.target"];
    };

    # Push this host's new history. Invoked by the periodic timer and at logout.
    systemd.user.services.zsh-history-sync-push = {
      Unit.Description = "Push this host's zsh history to GitHub";
      Service = {
        Type = "oneshot";
        ExecStart = "${zhs}/bin/zsh-history-sync push";
        Environment = syncEnv;
        StandardOutput = "journal";
        StandardError = "journal";
        TimeoutStartSec = "120s";
      };
    };

    systemd.user.timers.zsh-history-sync-periodic = {
      Unit.Description = "Periodic zsh history push (every 30 min)";
      Timer = {
        OnBootSec = "5min";
        OnUnitActiveSec = "30min";
        Persistent = true;
        Unit = "zsh-history-sync-push.service";
      };
      Install.WantedBy = ["timers.target"];
    };

    # Logout/shutdown: best-effort final push (|| true so it never blocks exit).
    systemd.user.services.zsh-history-sync-shutdown = {
      Unit = {
        Description = "Push zsh history to GitHub before session exit";
        DefaultDependencies = false;
        Before = ["exit.target"];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "${pkgs.bash}/bin/bash -c '${zhs}/bin/zsh-history-sync push || true'";
        Environment = syncEnv;
        StandardOutput = "journal";
        StandardError = "journal";
        TimeoutStartSec = "30s";
      };
      Install.WantedBy = ["exit.target"];
    };
  };
}
