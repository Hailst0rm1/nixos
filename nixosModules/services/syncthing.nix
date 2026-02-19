{
  config,
  lib,
  pkgs,
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

  folderIds = lib.attrNames cfg.folders;

  syncFilesScript = pkgs.writeShellScriptBin "sync-files" ''
    CONFIG_DIR="${homeDir}/.config/syncthing"
    API_KEY=$(${pkgs.gnugrep}/bin/grep -oP '(?<=<apikey>)[^<]+' "$CONFIG_DIR/config.xml" 2>/dev/null)
    PORT="${toString cfg.guiPort}"
    CURL="${pkgs.curl}/bin/curl"
    PYTHON="${pkgs.python3}/bin/python3"
    FOLDERS="${lib.concatStringsSep " " folderIds}"

    if [ -z "$API_KEY" ]; then
      echo "Error: Could not read Syncthing API key from $CONFIG_DIR/config.xml"
      exit 1
    fi

    api() {
      $CURL -sf "http://127.0.0.1:$PORT$1" -H "X-API-Key: $API_KEY" "''${@:2}"
    }

    if ! api "/rest/system/status" > /dev/null 2>&1; then
      echo "Error: Syncthing is not running or not reachable on port $PORT"
      exit 1
    fi

    check_status() {
      ALL_SYNCED=true

      for folder in $FOLDERS; do
        STATUS=$(api "/rest/db/status?folder=$folder")
        if [ -z "$STATUS" ]; then
          ALL_SYNCED=false
          echo -e "\033[31m✗\033[0m $folder: failed to query"
          continue
        fi

        eval "$(echo "$STATUS" | $PYTHON -c "
    import sys, json
    d = json.load(sys.stdin)
    state = d.get('state', 'unknown')
    need = d.get('needFiles', 0)
    total = d.get('globalFiles', 0)
    local_f = d.get('localFiles', 0)
    errs = d.get('errors', 0)
    nb = d.get('needBytes', 0)
    if nb > 1073741824: ns = f'{nb/1073741824:.1f} GB'
    elif nb > 1048576: ns = f'{nb/1048576:.1f} MB'
    elif nb > 1024: ns = f'{nb/1024:.1f} KB'
    else: ns = f'{nb} B'
    print(f\"S_STATE='{state}'\")
    print(f\"S_NEED='{need}'\")
    print(f\"S_TOTAL='{total}'\")
    print(f\"S_LOCAL='{local_f}'\")
    print(f\"S_ERRS='{errs}'\")
    print(f\"S_NEED_STR='{ns}'\")
    " 2>/dev/null)"

        if [ "$S_STATE" = "idle" ] && [ "$S_NEED" = "0" ] && [ "$S_ERRS" = "0" ]; then
          echo -e "\033[32m✓\033[0m $folder: \033[32midle\033[0m  $S_LOCAL/$S_TOTAL files"
        elif [ "$S_ERRS" != "0" ]; then
          ALL_SYNCED=false
          echo -e "\033[31m✗\033[0m $folder: $S_STATE  $S_LOCAL/$S_TOTAL files  need: $S_NEED ($S_NEED_STR)  \033[31merrors: $S_ERRS\033[0m"
        else
          ALL_SYNCED=false
          echo -e "\033[33m⟳\033[0m $folder: $S_STATE  $S_LOCAL/$S_TOTAL files  need: $S_NEED ($S_NEED_STR)"
        fi
      done
    }

    show_peers() {
      CONN=$(api "/rest/system/connections")
      echo "$CONN" | $PYTHON -c "
    import sys, json
    d = json.load(sys.stdin)
    peers = [(k[:7], v.get('connected', False)) for k, v in d.get('connections', {}).items()]
    parts = []
    for sid, c in peers:
        s = '\033[32mconnected\033[0m' if c else '\033[31mdisconnected\033[0m'
        parts.append(f'{sid}...={s}')
    print('\033[1mPeers:\033[0m ' + ('  '.join(parts) if parts else 'No peers configured'))
    " 2>/dev/null
    }

    TIMEOUT=300
    for arg in "$@"; do
      case "$arg" in
        --timeout=*) TIMEOUT="''${arg#--timeout=}" ;;
        -h|--help)
          echo "Usage: sync-files [OPTIONS]"
          echo ""
          echo "Options:"
          echo "  --timeout=SECS     Max seconds to wait (default: 300)"
          echo "  -h, --help         Show this help"
          exit 0
          ;;
      esac
    done

    # Trigger rescan, then wait until all folders are idle
    show_peers
    echo ""

    for folder in $FOLDERS; do
      api "/rest/db/scan?folder=$folder" -X POST > /dev/null 2>&1
    done

    START=$SECONDS

    # Check immediately — if already synced, just print and exit
    check_status > /dev/null 2>&1
    if [ "$ALL_SYNCED" = true ]; then
      check_status
      echo ""
      echo -e "\033[32mAll folders in sync.\033[0m"
      exit 0
    fi

    # Poll until synced
    while true; do
      ELAPSED=$((SECONDS - START))
      if [ "$ELAPSED" -ge "$TIMEOUT" ]; then
        echo -e "\n\033[31mTimeout after ''${TIMEOUT}s. Current status:\033[0m"
        check_status
        exit 1
      fi

      check_status > /dev/null 2>&1
      if [ "$ALL_SYNCED" = true ]; then
        check_status
        echo ""
        echo -e "\033[32mAll folders in sync. (''${ELAPSED}s)\033[0m"
        exit 0
      fi

      SUMMARY=""
      for folder in $FOLDERS; do
        STATUS=$(api "/rest/db/status?folder=$folder")
        PART=$(echo "$STATUS" | $PYTHON -c "
    import sys, json
    d = json.load(sys.stdin)
    s = d.get("state","?")
    n = d.get("needFiles",0)
    t = d.get("globalFiles",0)
    l = d.get("localFiles",0)
    sym = "✓" if s == "idle" and n == 0 else "⟳"
    extra = (" need:%d" % n) if n > 0 else ""
    print("%s%d/%d%s" % (sym, l, t, extra))
    " 2>/dev/null)
        SUMMARY="$SUMMARY $folder=$PART"
      done
      printf "\r\033[K\033[33m⟳\033[0m Waiting... ''${ELAPSED}s $SUMMARY"
      sleep 2
    done
  '';
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
          rescanIntervalS = mkOption {
            type = types.nullOr types.ints.unsigned;
            default = null;
            description = "Full rescan interval in seconds. null uses Syncthing's default (3600). Lower values help when fsWatcher misses events (e.g. on USB drives).";
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
    environment.systemPackages = [syncFilesScript];

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

        folders = lib.mapAttrs (_id: folder:
          {
            inherit (folder) label path type;
            devices =
              if folder.devices == []
              then otherDeviceNames
              else folder.devices;
          }
          // lib.optionalAttrs (folder.rescanIntervalS != null) {
            inherit (folder) rescanIntervalS;
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
