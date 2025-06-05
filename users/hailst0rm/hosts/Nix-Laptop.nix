{
  pkgs,
  lib,
  config,
  username,
  hostname,
  nixosDir,
  systemArch,
  myLocation,
  laptop,
  redTools,
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

  #   nixpkgs.overlays = [ (final: prev: {
  #   # FIX for responder: https://github.com/NixOS/nixpkgs/issues/255281#issuecomment-2229259710
  #   responder-patched = prev.responder.overrideAttrs (oldAttrs: rec {
  #     version = "responder-overlay";
  #     buildInputs = oldAttrs.buildInputs or [] ++ [prev.openssl prev.coreutils];

  #     installPhase = ''
  #       runHook preInstall

  #       mkdir -p $out/bin $out/share $out/share/Responder
  #       cp -R . $out/share/Responder

  #       makeWrapper ${prev.python3.interpreter} $out/bin/responder \
  #         --set PYTHONPATH "$PYTHONPATH:$out/share/Responder" \
  #         --add-flags "$out/share/Responder/Responder.py" \
  #         --run "mkdir -p /tmp/Responder"

  #       substituteInPlace $out/share/Responder/Responder.conf \
  #         --replace "Responder-Session.log" "/tmp/Responder/Responder-Session.log" \
  #         --replace "Poisoners-Session.log" "/tmp/Responder/Poisoners-Session.log" \
  #         --replace "Analyzer-Session.log" "/tmp/Responder/Analyzer-Session.log" \
  #         --replace "Config-Responder.log" "/tmp/Responder/Config-Responder.log" \
  #         --replace "Responder.db" "/tmp/Responder/Responder.db"

  #       runHook postInstall

  #       runHook postPatch
  #     '';

  #     postInstall = ''
  #       wrapProgram $out/bin/responder \
  #         --run "mkdir -p /tmp/Responder/certs && ${prev.openssl}/bin/openssl genrsa -out /tmp/Responder/certs/responder.key 2048 && ${prev.openssl}/bin/openssl req -new -x509 -days 3650 -key /tmp/Responder/certs/responder.key -out /tmp/Responder/certs/responder.crt -subj '/'"
  #     '';

  #     postPatch = ''
  #       if [ -f $out/share/Responder/settings.py ]; then
  #         substituteInPlace $out/share/Responder/settings.py \
  #           --replace "self.LogDir = os.path.join(self.ResponderPATH, 'logs')" "self.LogDir = os.path.join('/tmp/Responder/', 'logs')"
  #       fi

  #       if [ -f $out/share/Responder/utils.py ]; then
  #         substituteInPlace $out/share/Responder/utils.py \
  #           --replace "logfile = os.path.join(settings.Config.ResponderPATH, 'logs', fname)" "logfile = os.path.join('/tmp/Responder/', 'logs', fname)"
  #       fi

  #       if [ -f $out/share/Responder/Responder.py ]; then
  #         substituteInPlace $out/share/Responder/Responder.py \
  #           --replace "certs/responder.crt" "/tmp/Responder/certs/responder.crt" \
  #           --replace "certs/responder.key" "/tmp/Responder/certs/responder.key"
  #       fi

  #       if [ -f $out/share/Responder/Responder.conf ]; then
  #         substituteInPlace $out/share/Responder/Responder.conf \
  #           --replace "certs/responder.crt" "/tmp/Responder/certs/responder.crt" \
  #           --replace "certs/responder.key" "/tmp/Responder/certs/responder.key"
  #       fi
  #     '';
  #   });
  # }
  # )];

  home = {
    stateVersion = "24.11";
    username = lib.mkDefault "${config.username}";
    homeDirectory = lib.mkDefault "/home/${config.username}";
  };

  # NIXOS Variables.nix (inherited from system config)
  username = username;
  hostname = hostname;
  nixosDir = nixosDir;
  systemArch = systemArch;
  myLocation = myLocation;
  laptop = laptop;

  # Variables.nix (mainly used for zsh-environment)
  terminal = "ghostty";
  shell = "zsh";
  editor = "hx";
  fileManager = "nautilus";
  browser = "firefox";
  video = "totem";
  image = "loupe";
  keyboard = "colemak-se,se";

  # Import configuration for other tools
  importConfig = {
    git.enable = true;
    yazi.enable = true;
    stylix.enable = true;
    sops.enable = true;
    hyprland = {
      enable = true;
      panel = "hyprpanel";
      lockscreen = "hyprlock";
      appLauncher = "rofi";
      notifications = "hyprpanel";
      wallpaper = "swww";
    };
  };

  # IDE for coding
  code = {
    helix = {
      enable = true;
      languages = {
        cpp = false;
        cSharp = false;
        python = false;
        rust = false;
        web = false;
      };
    };
    vscode = {
      enable = true;
      languages = {
        cpp = false;
        python = false;
        rust = false;
      };
    };
  };

  applications = {
    bitwarden.enable = true;
    discord.enable = true;
    firefox.enable = true;
    gpt4all.enable = false;
    libreOffice.enable = true;
    mattermost.enable = false;
    obsidian.enable = true;
    proton.enableAll = true;
    remmina.enable = true;
    spotify.enable = true;
    zen-browser.enable = false;
    openconnect.enable = true;
    games = {
      ryujinx.enable = false;
    };
  };

  cyber = {
    malwareAnalysis.enable = false;
    redTools.enable = lib.mkDefault redTools;
  };
}
