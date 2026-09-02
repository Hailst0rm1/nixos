{
  config,
  lib,
  pkgs,
  pkgs-unstable,
  inputs,
  ...
}: let
  cfg = config.applications;
  proton = config.applications.proton;
  games = config.applications.games;
  spicePkgs = inputs.spicetify-nix.legacyPackages.${pkgs.stdenv.hostPlatform.system};
in {
  imports = [inputs.spicetify-nix.homeManagerModules.spicetify];

  options.applications = {
    bitwarden.enable = lib.mkEnableOption "Enable Bitwarden.";
    brave.enable = lib.mkEnableOption "Enable Brave browser.";
    discord.enable = lib.mkEnableOption "Enable Discord.";
    firefox.enable = lib.mkEnableOption "Enable FireFox.";
    gpt4all.enable = lib.mkEnableOption "Enable gpt4all.";
    libreOffice.enable = lib.mkEnableOption "Enable libreOffice.";
    mattermost.enable = lib.mkEnableOption "Enable Mattermost.";
    obsidian.enable = lib.mkEnableOption "Enable Obsidian.";
    remmina.enable = lib.mkEnableOption "Enable Remmina";
    spotify.enable = lib.mkEnableOption "Enable Spotify.";
    youtube-music.enable = lib.mkEnableOption "Enable youtube-music.";
    zen-browser.enable = lib.mkEnableOption "Enable Zen Browser.";
    claude-desktop.enable = lib.mkEnableOption "Enable Claude Desktop.";
    openconnect.enable = lib.mkEnableOption "Enable Openconnect.";
    signal.enable = lib.mkEnableOption "Enable Signal Desktop.";
    espanso.enable = lib.mkEnableOption "Enable Espanso.";
    aws-cvpn-wrapper.enable = lib.mkEnableOption "Enable AWS CVPN Wrapper.";

    ## Proton Applications
    proton = {
      enableAll = lib.mkEnableOption "Enable all Proton applications.";
      mail.enable = lib.mkEnableOption "Enable ProtonMail Desktop.";
      vpn.enable = lib.mkEnableOption "Enable ProtonVPN GUI.";
      pass.enable = lib.mkEnableOption "Enable ProtonPass.";
      authenticator.enable = lib.mkEnableOption "Enable Proton Authenticator.";
    };

    ## Games
    games = {
      ryujinx.enable = lib.mkEnableOption "Enable Ryujinx emulator.";
    };
  };

  config = {
    home.packages = lib.mkMerge [
      ## Applications
      (lib.mkIf cfg.bitwarden.enable [pkgs.bitwarden-desktop])
      (lib.mkIf cfg.brave.enable [pkgs-unstable.brave])
      # (lib.mkIf cfg.discord.enable [ pkgs-unstable.discord ])
      (lib.mkIf cfg.firefox.enable [pkgs-unstable.firefox])
      (lib.mkIf cfg.gpt4all.enable [pkgs-unstable.gpt4all])
      (lib.mkIf cfg.libreOffice.enable [pkgs.libreoffice-qt6-fresh])
      (lib.mkIf cfg.mattermost.enable [pkgs.mattermost])
      (lib.mkIf cfg.obsidian.enable [pkgs-unstable.obsidian])
      (lib.mkIf cfg.remmina.enable [pkgs-unstable.remmina])
      #(lib.mkIf cfg.spotify.enable [ pkgs-unstable.spotify ]) # Uncomment if not using spicetify flake
      (lib.mkIf cfg.youtube-music.enable [pkgs-unstable.pear-desktop])
      (lib.mkIf cfg.zen-browser.enable [inputs.zen-browser.packages.${pkgs.stdenv.hostPlatform.system}.default])
      (lib.mkIf cfg.claude-desktop.enable (let
        system = pkgs.stdenv.hostPlatform.system;
        # Upstream's claude-desktop.nix still takes a `nodePackages` arg for
        # `nodePackages.asar`, which nixpkgs removed as a top-level alias.
        # Override it to the real top-level `asar` package; the flake's own
        # `claude-desktop-with-fhs` output can't be patched from here since
        # it bakes in the unoverridden `claude-desktop` internally.
        claude-desktop = inputs.claude-desktop.packages.${system}.claude-desktop.override {
          nodePackages = {asar = pkgs.asar;};
        };
        claude-desktop-with-fhs = pkgs.buildFHSEnv {
          name = "claude-desktop";
          targetPkgs = pkgs: with pkgs; [docker glibc openssl nodejs uv];
          runScript = "${claude-desktop}/bin/claude-desktop";
          extraInstallCommands = ''
            mkdir -p $out/share/applications
            cp ${claude-desktop}/share/applications/claude.desktop $out/share/applications/

            mkdir -p $out/share/icons
            cp -r ${claude-desktop}/share/icons/* $out/share/icons/
          '';
        };
      in [
        (pkgs.symlinkJoin {
          name = "claude-desktop-wrapped";
          paths = [claude-desktop-with-fhs];
          buildInputs = [pkgs.makeWrapper];
          postBuild = ''
            wrapProgram $out/bin/claude-desktop \
              --set LIBGL_ALWAYS_SOFTWARE 1
          '';
        })
      ]))
      (lib.mkIf cfg.openconnect.enable [pkgs-unstable.openconnect])
      (lib.mkIf cfg.signal.enable [pkgs-unstable.signal-desktop])
      (lib.mkIf cfg.aws-cvpn-wrapper.enable [(pkgs.callPackage ../pkgs/aws-cvpn-wrapper/package.nix {})])

      ## Proton Applications (with enableAll option)
      (lib.mkIf (proton.mail.enable || proton.enableAll) [pkgs-unstable.protonmail-desktop])
      (lib.mkIf (proton.vpn.enable || proton.enableAll) [pkgs.proton-vpn])
      (lib.mkIf (proton.pass.enable || proton.enableAll) [pkgs-unstable.proton-pass])
      (lib.mkIf (proton.authenticator.enable || proton.enableAll) [pkgs-unstable.proton-authenticator])

      ## Games
      (lib.mkIf games.ryujinx.enable [pkgs-unstable.ryujinx-greemdev])
    ];

    # Hyprland bindings
    wayland.windowManager.hyprland.settings = lib.mkIf config.importConfig.hyprland.enable {
      bind = lib.mkIf cfg.spotify.enable ["$mainMod, S, exec, spotify --disable-gpu"];
    };

    # Spotify theme settings
    programs.spicetify = lib.mkIf cfg.spotify.enable {
      enable = true;
      enabledExtensions = with spicePkgs.extensions; [
        adblockify
        #hidePodcasts
        shuffle # shuffle+ (special characters are sanitized out of extension names)
      ];
      #theme = spicePkgs.themes.catppuccin; # Uncomment if not using stylix
      #colorScheme = "mocha"; # Uncomment if not using stylix
    };

    # Default applications (MIME associations)
    xdg.mimeApps = lib.mkIf cfg.firefox.enable {
      enable = true;
      defaultApplications = {
        "application/pdf" = "firefox.desktop";
        "text/html" = "firefox.desktop";
        "x-scheme-handler/http" = "firefox.desktop";
        "x-scheme-handler/https" = "firefox.desktop";
      };
    };
    xdg.configFile = lib.mkIf cfg.firefox.enable {
      "mimeapps.list".force = true;
    };

    # Espanso service
    # TODO: https://mynixos.com/search?q=espanso
    services.espanso = lib.mkIf cfg.espanso.enable {
      enable = true;
      package = pkgs.espanso-wayland;
    };
  };
}
