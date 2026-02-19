{
  config,
  lib,
  ...
}: let
  cfg = config.services.syncthing-sync;
  username = config.username;
  homeDir = "/home/${username}";

  allDevices = {
    "Nix-Server" = {
      id = cfg.deviceIds.server;
      addresses = ["tcp://nix-server:22000"];
    };
    "Nix-Workstation" = {
      id = cfg.deviceIds.workstation;
      addresses = ["tcp://nix-workstation:22000"];
    };
    "Nix-Laptop" = {
      id = cfg.deviceIds.laptop;
      addresses = ["tcp://nix-laptop:22000"];
    };
  };

  otherDevices = lib.filterAttrs (name: _: name != config.hostname) allDevices;
  otherDeviceNames = lib.attrNames otherDevices;

  isServer = cfg.role == "server";

  nixosConfigPath =
    if isServer
    then "/mnt/nas/NixOS"
    else "${homeDir}/.nixos";
in {
  options.services.syncthing-sync = with lib; {
    enable = mkEnableOption "Syncthing file synchronization across machines";

    role = mkOption {
      type = types.enum ["server" "client"];
      description = "Whether this machine is the always-on server or a client.";
    };

    deviceIds = {
      server = mkOption {
        type = types.str;
        default = "XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX";
        description = "Syncthing device ID for Nix-Server.";
      };
      workstation = mkOption {
        type = types.str;
        default = "XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX";
        description = "Syncthing device ID for Nix-Workstation.";
      };
      laptop = mkOption {
        type = types.str;
        default = "XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX";
        description = "Syncthing device ID for Nix-Laptop.";
      };
    };

    guiPort = mkOption {
      type = types.port;
      default = 8384;
      description = "Port for the Syncthing web GUI (localhost only).";
    };
  };

  config = lib.mkIf cfg.enable {
    services.syncthing = {
      enable = true;
      user = username;
      group = "users";
      dataDir = homeDir;
      configDir = "${homeDir}/.config/syncthing";

      overrideDevices = true;
      overrideFolders = true;

      settings = {
        gui.address = "127.0.0.1:${toString cfg.guiPort}";

        devices =
          lib.mapAttrs (_name: dev: {
            inherit (dev) id addresses;
            autoAcceptFolders = false;
          })
          otherDevices;

        folders = {
          "nixos-config" = {
            label = "NixOS Config";
            path = nixosConfigPath;
            devices = otherDeviceNames;
            type = "sendreceive";
          };
          "code" = {
            label = "Code Projects";
            path =
              if isServer
              then "/mnt/nas/Code"
              else "${homeDir}/Code";
            devices = otherDeviceNames;
            type = "sendreceive";
          };
          "wiki" = {
            label = "Wiki / Notes";
            path =
              if isServer
              then "/mnt/nas/wiki"
              else "${homeDir}/Documents/wiki";
            devices = otherDeviceNames;
            type = "sendreceive";
          };
        };
      };
    };

    # Firewall: Syncthing protocol + discovery
    networking.firewall = {
      allowedTCPPorts = [22000];
      allowedUDPPorts = [22000 21027];
    };

    # Ensure target directories exist
    systemd.tmpfiles.rules =
      if isServer
      then [
        "d /mnt/nas/NixOS 0755 ${username} users -"
        "d /mnt/nas/Code 0755 ${username} users -"
        "d /mnt/nas/wiki 0755 ${username} users -"
      ]
      else [
        "d ${homeDir}/Code 0755 ${username} users -"
        "d ${homeDir}/Documents/wiki 0755 ${username} users -"
      ];

    # Declarative .stignore for nixos-config folder (avoids REST API race)
    environment.etc."syncthing-stignore-nixos-config".text = ''
      .claude
      .direnv
      result
    '';
    systemd.services.syncthing-stignore = {
      description = "Place .stignore file for Syncthing nixos-config folder";
      after = ["syncthing.service"];
      wantedBy = ["multi-user.target"];
      serviceConfig = {
        Type = "oneshot";
        User = username;
        Group = "users";
        RemainAfterExit = true;
      };
      script = ''
        target="${nixosConfigPath}/.stignore"
        source="/etc/syncthing-stignore-nixos-config"
        if [ ! -f "$target" ] || ! diff -q "$source" "$target" > /dev/null 2>&1; then
          cp "$source" "$target"
        fi
      '';
    };
  };
}
