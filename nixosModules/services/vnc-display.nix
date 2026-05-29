{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.services.vncDisplay;
  vncPort = 5900 + cfg.display;
  authFlags =
    if cfg.auth.type == "vncPassword"
    then "-SecurityTypes VncAuth -PasswordFile ${cfg.auth.passwordFile}"
    else "-SecurityTypes None";
  wmStart = lib.optionalString (cfg.windowManager == "openbox") ''
    DISPLAY=:${toString cfg.display} ${pkgs.openbox}/bin/openbox &
    wmPid=$!
  '';
in {
  options.services.vncDisplay = {
    enable = lib.mkEnableOption "Headless Xvnc + noVNC for agent visibility over Tailscale";

    display = lib.mkOption {
      type = lib.types.int;
      default = 99;
      description = "X display number. Xvnc binds :DISPLAY and TCP port 5900+DISPLAY.";
    };

    novncPort = lib.mkOption {
      type = lib.types.port;
      default = 6080;
      description = "noVNC HTTP port. Reach over Tailscale at http://<host>:PORT/vnc.html.";
    };

    geometry = lib.mkOption {
      type = lib.types.str;
      default = "1920x1080";
      description = "Xvnc screen geometry (WxH).";
    };

    user = lib.mkOption {
      type = lib.types.str;
      default = config.username;
      description = "User the Xvnc and window manager processes run as.";
    };

    windowManager = lib.mkOption {
      type = lib.types.enum ["openbox" "none"];
      default = "openbox";
      description = "Lightweight WM inside the X session. Required for proper popup focus/z-order (e.g. BankID).";
    };

    auth = {
      type = lib.mkOption {
        type = lib.types.enum ["none" "vncPassword"];
        default = "none";
        description = "VNC authentication. 'none' relies on the tailscale0 firewall trust as the boundary.";
      };
      passwordFile = lib.mkOption {
        type = lib.types.nullOr lib.types.path;
        default = null;
        description = "Path to a vncpasswd-formatted file. Required when auth.type = \"vncPassword\". Typically a sops secret path.";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = cfg.auth.type != "vncPassword" || cfg.auth.passwordFile != null;
        message = "services.vncDisplay.auth.passwordFile must be set when auth.type = \"vncPassword\".";
      }
    ];

    environment.systemPackages =
      [pkgs.tigervnc pkgs.novnc]
      ++ lib.optional (cfg.windowManager == "openbox") pkgs.openbox;

    systemd.tmpfiles.rules = [
      "d /var/lib/vnc-display 0750 ${cfg.user} users -"
    ];

    networking.firewall.interfaces.tailscale0.allowedTCPPorts = [cfg.novncPort];

    systemd.services.vnc-display = {
      description = "Xvnc headless X server for agent visibility (:${toString cfg.display})";
      after = ["network.target"];
      wantedBy = ["multi-user.target"];
      environment = {
        HOME = "/var/lib/vnc-display";
      };
      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Group = "users";
        Restart = "on-failure";
        RestartSec = 5;
      };
      script = ''
        ${pkgs.tigervnc}/bin/Xvnc :${toString cfg.display} \
          -geometry ${cfg.geometry} \
          -depth 24 \
          -localhost yes \
          -AlwaysShared \
          -AcceptCutText=1 -SendCutText=1 \
          ${authFlags} &
        xvncPid=$!

        cleanup() {
          ${lib.optionalString (cfg.windowManager == "openbox") ''
          if [ -n "''${wmPid:-}" ]; then
            kill "$wmPid" 2>/dev/null || true
          fi
        ''}
          kill "$xvncPid" 2>/dev/null || true
        }
        trap cleanup EXIT INT TERM

        for _ in $(seq 1 50); do
          [ -S /tmp/.X11-unix/X${toString cfg.display} ] && break
          kill -0 "$xvncPid" 2>/dev/null || exit 1
          sleep 0.1
        done

        ${wmStart}
        wait "$xvncPid"
      '';
    };

    systemd.services.novnc = {
      description = "noVNC websockify proxy for vnc-display";
      after = ["vnc-display.service"];
      bindsTo = ["vnc-display.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "simple";
        User = cfg.user;
        Restart = "on-failure";
        RestartSec = 5;
        ExecStart = "${pkgs.python3Packages.websockify}/bin/websockify --web ${pkgs.novnc}/share/webapps/novnc 0.0.0.0:${toString cfg.novncPort} 127.0.0.1:${toString vncPort}";
      };
    };
  };
}
