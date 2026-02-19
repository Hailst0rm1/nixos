{
  config,
  lib,
  ...
}: let
  cfg = config.services.syncthing-sync;
  username = config.username;
  homeDir = "/home/${username}";

  placeholderId = "XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX";
  otherDevices = lib.filterAttrs (name: dev: name != config.hostname && dev.id != placeholderId) cfg.devices;
  otherDeviceNames = lib.attrNames otherDevices;

  foldersWithStignore = lib.filterAttrs (_: f: f.stignore != "") cfg.folders;
  foldersWithEnsureDir = lib.filterAttrs (_: f: f.ensureDir) cfg.folders;
in {
  options.services.syncthing-sync = with lib; {
    enable = mkEnableOption "Syncthing file synchronization across machines";

    devices = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          id = mkOption {
            type = types.str;
            description = "Syncthing device ID.";
          };
          addresses = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Transport addresses (e.g. tcp://hostname:22000). Empty uses discovery.";
          };
          autoAcceptFolders = mkOption {
            type = types.bool;
            default = false;
            description = "Whether to auto-accept folder invitations from this device.";
          };
        };
      });
      default = {};
      description = "Syncthing peer devices, keyed by hostname.";
    };

    folders = mkOption {
      type = types.attrsOf (types.submodule {
        options = {
          label = mkOption {
            type = types.str;
            default = "";
            description = "Human-readable folder label.";
          };
          path = mkOption {
            type = types.str;
            description = "Local path for this synced folder.";
          };
          devices = mkOption {
            type = types.listOf types.str;
            default = [];
            description = "Device names to share with. Empty means all other devices.";
          };
          type = mkOption {
            type = types.enum ["sendreceive" "sendonly" "receiveonly" "receiveencrypted"];
            default = "sendreceive";
            description = "Folder sync type.";
          };
          stignore = mkOption {
            type = types.lines;
            default = "";
            description = "Contents of the .stignore file for this folder. Empty means no managed .stignore.";
          };
          ensureDir = mkOption {
            type = types.bool;
            default = true;
            description = "Whether to create the folder path via tmpfiles.rules.";
          };
        };
      });
      default = {};
      description = "Syncthing folders to synchronize, keyed by folder ID.";
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
            inherit (dev) id addresses autoAcceptFolders;
          })
          otherDevices;

        folders =
          lib.mapAttrs (_id: folder: {
            inherit (folder) label path type;
            devices =
              if folder.devices == []
              then otherDeviceNames
              else folder.devices;
          })
          cfg.folders;
      };
    };

    # Firewall: Syncthing protocol + discovery
    networking.firewall = {
      allowedTCPPorts = [22000];
      allowedUDPPorts = [22000 21027];
    };

    # Ensure target directories exist
    systemd.tmpfiles.rules =
      lib.mapAttrsToList (_id: folder: "d ${folder.path} 0755 ${username} users -")
      foldersWithEnsureDir;

    # Declarative .stignore files
    environment.etc = lib.mapAttrs' (id: folder:
      lib.nameValuePair "syncthing-stignore-${id}" {
        text = folder.stignore;
      })
    foldersWithStignore;

    systemd.services = lib.mapAttrs' (id: folder:
      lib.nameValuePair "syncthing-stignore-${id}" {
        description = "Place .stignore for Syncthing folder '${id}'";
        after = ["syncthing.service"];
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          Type = "oneshot";
          User = username;
          Group = "users";
          RemainAfterExit = true;
        };
        script = ''
          target="${folder.path}/.stignore"
          source="/etc/syncthing-stignore-${id}"
          if [ ! -f "$target" ] || ! diff -q "$source" "$target" > /dev/null 2>&1; then
            rm -f "$target"
            cp "$source" "$target"
            chmod 0644 "$target"
          fi
        '';
      })
    foldersWithStignore;
  };
}
