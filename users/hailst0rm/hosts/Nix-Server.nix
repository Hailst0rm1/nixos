{
  config,
  lib,
  pkgs,
  ...
}: let
  notebooklm-py = pkgs.callPackage ../../../pkgs/notebooklm-py/package.nix {};
  python = pkgs.python3.withPackages (ps: with ps; [feedparser pyyaml]);
in {
  imports = [./default.nix];

  # Override only what's different from default
  fileManager = "";
  browser = "";
  video = "";
  image = "";

  programs.zsh.initContent = ''
    eval "$(direnv hook zsh)"
  '';

  importConfig = {
    stylix.enable = false;
    hyprland = {
      enable = false;
      accentColour = "pink";
      quickshell.ilyamiro.enable = false;
    };
  };

  # Disable stylix version checks since theme is disabled on server
  stylix.enableReleaseChecks = false;

  code.vscode.enable = false;
  code.claude-code.enable = true;
  code.codex.enable = true;

  home.packages = [pkgs.gws];

  applications = {
    bitwarden.enable = false;
    discord.enable = false;
    firefox.enable = false;
    libreOffice.enable = false;
    obsidian.enable = false;
    remmina.enable = false;
    spotify.enable = false;
    claude-desktop.enable = false;
    proton.enableAll = false;
    signal.enable = false;
  };

  services = {
    claudecodeui.enable = false; # Claude Code UI Web Interface
    whisperStt.enable = false;
    obsidian-sync = {
      enable = true;
      vaultName = "wiki"; # Set your remote vault name
      vaultPath = "/home/hailst0rm/Obsidian/wiki"; # Set your local vault path
    };
  };

  # Daily News Digest - Claude Code Agent
  systemd.user.services.notebooklm-news = {
    Unit = {
      Description = "Daily News Digest - Claude Code Agent";
      After = ["network-online.target"];
      Wants = ["network-online.target"];
    };

    Service = {
      Type = "oneshot";
      WorkingDirectory = "/mnt/nas/Code/notebooklm-news";
      ExecStart = "${config.home.profileDirectory}/bin/claude --print --dangerously-skip-permissions --permission-mode bypassPermissions --no-session-persistence -p \"You are an autonomous agent running a daily news digest workflow. Execute the workflow defined in workflows/daily_digest.md by running each tool in sequence. If any tool fails, diagnose the error, attempt a fix, verify it works, and update the workflow documentation with what you learned. Output a final summary of sources added, audio status, and any errors encountered.\"";
      TimeoutStartSec = "20min";
      StandardOutput = "journal";
      StandardError = "journal";
      Environment = [
        "HOME=${config.home.homeDirectory}"
        "NOTEBOOKLM_BIN=${notebooklm-py}/bin/notebooklm"
        "PATH=${python}/bin:${notebooklm-py}/bin:${pkgs.yt-dlp}/bin:${config.home.profileDirectory}/bin:/run/current-system/sw/bin"
      ];
    };
  };

  systemd.user.timers.notebooklm-news = {
    Unit = {
      Description = "Run Daily News Digest at 5 AM";
    };

    Timer = {
      OnCalendar = "*-*-* 05:00:00";
      Persistent = true;
    };

    Install = {
      WantedBy = ["timers.target"];
    };
  };
}
