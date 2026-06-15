{
  lib,
  config,
  osConfig,
  pkgs,
  ...
}: {
  imports =
    [
      ../../applications.nix
      ../../../nixosModules/variables.nix
    ]
    ++ lib.filter
    (n: lib.strings.hasSuffix ".nix" n)
    (lib.filesystem.listFilesRecursive ../homeManagerModules);

  programs = {
    home-manager.enable = true;
  };

  home = {
    stateVersion = "25.11";
    username = lib.mkDefault config.username;
    homeDirectory = lib.mkDefault "/home/${config.username}";
    enableNixpkgsReleaseCheck = lib.mkDefault false;
  };

  # Propagate nixosDir from NixOS config into HM
  nixosDir = lib.mkDefault osConfig.nixosDir;

  # Variables.nix defaults (mainly used for zsh-environment)
  terminal = lib.mkDefault "ghostty";
  shell = lib.mkDefault "zsh";
  editor = lib.mkDefault "hx";
  fileManager = lib.mkDefault "nautilus";
  browser = lib.mkDefault "firefox";
  video = lib.mkDefault "totem";
  image = lib.mkDefault "loupe";
  keyboard = lib.mkDefault "colemak-se,se";

  # Import configuration for other tools
  importConfig = {
    git.enable = lib.mkDefault true;
    ssh.enable = lib.mkDefault true;
    yazi.enable = lib.mkDefault true;
    stylix.enable = lib.mkDefault true;
    sops.enable = lib.mkDefault osConfig.security.sops.enable;
    zsh-history-sync.enable = lib.mkDefault true;
    hyprland = {
      enable = lib.mkDefault true;
      customScreenPicker = lib.mkDefault true;
      accentColour = lib.mkDefault "green";
      panel = lib.mkDefault "hyprpanel";
      lockscreen = lib.mkDefault "hyprlock";
      appLauncher = lib.mkDefault "rofi";
      notifications = lib.mkDefault "hyprpanel";
      wallpaper = lib.mkDefault "mpvpaper";
      monitorOrientations = lib.mkDefault {
        "0" = "left";
        "1" = "left";
      };
      quickshell.ilyamiro = {
        enable = lib.mkDefault true;
        openweatherCityId = lib.mkDefault "2673730";
      };
    };
  };

  # IDE for coding
  code = {
    claude-code = {
      enable = lib.mkDefault false;
      exa.enable = lib.mkDefault true;
      codegraph.enable = lib.mkDefault true;
      perplexity.enable = lib.mkDefault false;
      claude-mem.enable = lib.mkDefault true;
      tokenOptimizer.enable = lib.mkDefault false;
      playground.enable = lib.mkDefault true;
      visual-explainer.enable = lib.mkDefault true;
      pluginAutoUpdate.enable = lib.mkDefault true;
      sessionHandoffReminder = {
        enable = lib.mkDefault true;
        thresholdMinutes = lib.mkDefault 60;
      };
      sound = {
        enable = lib.mkDefault true;
        volume = lib.mkDefault 55;
        stopSound = lib.mkDefault "${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/complete.oga";
        notificationSound = lib.mkDefault "${pkgs.sound-theme-freedesktop}/share/sounds/freedesktop/stereo/bell.oga";
      };
      localLlm = {
        enable = lib.mkDefault false;
        authToken = lib.mkDefault "ollama";
        apiKey = lib.mkDefault "";
        baseUrl = lib.mkDefault "http://localhost:11434";
      };
    };
    codex.enable = lib.mkDefault false;
    sandcastle = {
      # Default-on wherever claude-code is enabled.
      enable = lib.mkDefault config.code.claude-code.enable;
      container = lib.mkDefault "podman";
      image = lib.mkDefault "sandcastle-agent:latest";
      model = lib.mkDefault "claude-opus-4-7";
      effort = lib.mkDefault "high";
      baseBranch = lib.mkDefault "master";
      maxIssues = lib.mkDefault 4;
      concurrency = lib.mkDefault 2;
      implementIterations = lib.mkDefault 40;
    };
    helix = {
      enable = lib.mkDefault true;
      languages = {
        cpp = lib.mkDefault false;
        cSharp = lib.mkDefault false;
        python = lib.mkDefault false;
        rust = lib.mkDefault false;
        web = lib.mkDefault false;
      };
    };
    vscode = {
      enable = lib.mkDefault true;
      languages = {
        cpp = lib.mkDefault false;
        python = lib.mkDefault false;
        rust = lib.mkDefault false;
      };
    };
  };

  applications = {
    bitwarden.enable = lib.mkDefault true;
    brave.enable = lib.mkDefault false;
    discord.enable = lib.mkDefault true;
    firefox.enable = lib.mkDefault true;
    gpt4all.enable = lib.mkDefault false;
    libreOffice.enable = lib.mkDefault true;
    mattermost.enable = lib.mkDefault false;
    obsidian.enable = lib.mkDefault true;
    remmina.enable = lib.mkDefault true;
    spotify.enable = lib.mkDefault true;
    youtube-music.enable = lib.mkDefault false;
    zen-browser.enable = lib.mkDefault false;
    claude-desktop.enable = lib.mkDefault true;
    openconnect.enable = lib.mkDefault false;
    espanso.enable = lib.mkDefault false;
    aws-cvpn-wrapper.enable = lib.mkDefault false;
    signal.enable = lib.mkDefault true;
    proton = {
      enableAll = lib.mkDefault true;
      mail.enable = lib.mkDefault false;
      vpn.enable = lib.mkDefault false;
      pass.enable = lib.mkDefault false;
      authenticator.enable = lib.mkDefault false;
    };
    games = {
      ryujinx.enable = lib.mkDefault false;
    };
  };

  services = {
    claudecodeui.enable = lib.mkDefault false; # Claude Code UI Web Interface
    claude-mcp = {
      enable = lib.mkDefault true;
      servers = {
        nixos.enable = lib.mkDefault true;
        perplexity.enable = lib.mkDefault true;
        exa.enable = lib.mkDefault true;
      };
    };
    whisperStt = {
      enable = lib.mkDefault true;
      model = lib.mkDefault "large-v3-turbo"; # Multilingual with native punctuation (English, Swedish, etc.)
      # language = null means auto-detect (default)
      keybind = lib.mkDefault "$mainMod CTRL, S"; # ALT+CTRL+S to toggle recording
      vadFilter = lib.mkDefault true;
      vadMinSilenceMs = lib.mkDefault 700; # short pauses → sentence breaks → better punctuation
      vadThreshold = lib.mkDefault 0.4; # lower than Silero default 0.5 so "I" is not dropped
      outputMode = lib.mkDefault "paste"; # paste via Ctrl+Shift+V; avoids per-key kbproto races
    };
    readAloud = {
      enable = lib.mkDefault true;
      keybind = lib.mkDefault "$mainMod CTRL, R"; # SUPER+CTRL+R to read primary selection aloud
      speed = lib.mkDefault 1.5; # 1.5x faster than normal; pitch preserved
    };
  };

  cyber = {
    redTools.enable = lib.mkDefault osConfig.cyber.redTools.enable;
    malwareAnalysis.enable = lib.mkDefault false;
  };

  # GTK / Nautilus sidebar bookmarks
  gtk.enable = true;
  gtk.gtk3.bookmarks =
    [
      "file://${config.home.homeDirectory}/Documents"
      "file://${config.home.homeDirectory}/Pictures"
      "file://${config.home.homeDirectory}/Downloads"
      "file://${config.nixosDir} NixOS"
    ]
    ++ lib.optionals osConfig.services.syncthing-sync.enable [
      "file://${config.home.homeDirectory}/Code"
    ]
    ++ lib.optionals osConfig.services.nas.client.enable [
      "file://${osConfig.services.nas.client.mountPoint} NAS"
    ]
    ++ lib.optionals config.cyber.redTools.enable [
      "file://${config.home.homeDirectory}/cyber/postex-tools/payloads Payloads"
    ];
}
