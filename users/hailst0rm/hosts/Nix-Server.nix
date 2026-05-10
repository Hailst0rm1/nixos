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
    claudecodeui.enable = true; # Claude Code UI Web Interface
    whisperStt.enable = false;
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
      ExecStart = "${config.home.profileDirectory}/bin/claude --print -p \"Execute the workflow in workflows/daily_digest.md. Run each tool and report results.\"";
      TimeoutStartSec = "20min";
      StandardOutput = "journal";
      StandardError = "journal";
      Environment = [
        "HOME=${config.home.homeDirectory}"
        "NOTEBOOKLM_BIN=${notebooklm-py}/bin/notebooklm"
        "PATH=${python}/bin:${notebooklm-py}/bin:${config.home.profileDirectory}/bin:/run/current-system/sw/bin"
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
