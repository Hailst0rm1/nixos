{
  pkgs,
  config,
  lib,
  ...
}: let
  hasDesktop = config.importConfig.hyprland.enable;
  nixosDir = config.nixosDir;
  stateDir = "${config.xdg.stateHome}/nix-sync-check";

  # Shared logic for checking remote and building the update message
  checkScript = pkgs.writeShellScriptBin "nix-check-remote" ''
    #!/usr/bin/env sh

    cd ${nixosDir}

    # Test GitHub connectivity via SSH
    MAX_RETRIES=12  # Check for up to 1 hour (12 * 5 minutes)
    RETRY_COUNT=0
    CONNECTION_OK=false

    while [ $RETRY_COUNT -lt $MAX_RETRIES ]; do
      if timeout 5 git ls-remote git@github.com:hailst0rm1/nixos.git HEAD &>/dev/null; then
        CONNECTION_OK=true
        break
      else
        if [ $RETRY_COUNT -eq 0 ]; then
          ${
      if hasDesktop
      then ''
        if command -v zenity &> /dev/null; then
          zenity --warning \
            --title="GitHub Connection Failed" \
            --text="Cannot reach GitHub via SSH.\n\nWill keep checking in the background every 5 minutes.\nYou'll be notified when updates are available." \
            --width=400 \
            --timeout=10 &
        fi
        notify-send "NixOS Config Sync" "Cannot reach GitHub. Will keep checking..." --icon=dialog-warning &
      ''
      else ''
        echo "Cannot reach GitHub via SSH. Will keep checking in the background every 5 minutes."
      ''
    }
        fi
        RETRY_COUNT=$((RETRY_COUNT + 1))
        sleep 300
      fi
    done

    if [ "$CONNECTION_OK" = false ]; then
      exit 0
    fi

    # Fetch remote changes without merging
    git fetch origin master --quiet

    # Check if local is behind remote
    LOCAL=$(git rev-parse HEAD)
    REMOTE=$(git rev-parse origin/master)

    if [ "$LOCAL" = "$REMOTE" ]; then
      # Up to date — clear any stale notification file
      rm -f "${stateDir}/update-available" 2>/dev/null
      exit 0
    fi

    # Count commits behind
    BEHIND=$(git rev-list HEAD..origin/master --count)

    # Get commit messages and parse them
    COMMITS=$(while IFS= read -r line; do
      if echo "$line" | grep -q ":"; then
        MESSAGE=$(echo "$line" | cut -d':' -f2-)
        MESSAGE=$(echo "$MESSAGE" | sed 's/ ([^)]*)$//')
        MESSAGE=$(echo "$MESSAGE" | sed 's/^ *//;s/ *$//')
        echo "• $MESSAGE"
      else
        echo "• $line"
      fi
    done <<< "$(git log HEAD..origin/master --pretty=format:"%s")")

    # Get list of changed files (limit to 10)
    CHANGED_FILES=$(git diff --name-only HEAD origin/master | head -10 | sed 's/^/• /')
    FILE_COUNT=$(git diff --name-only HEAD origin/master | wc -l)

    if [ "$FILE_COUNT" -gt 10 ]; then
      CHANGED_FILES="$CHANGED_FILES
    • ... and $((FILE_COUNT - 10)) more files"
    fi

    ${
      if hasDesktop
      then ''
        # Desktop: GUI prompt
        if command -v zenity &> /dev/null; then
          zenity --question \
            --title="NixOS Config Updates Available" \
            --text="Your NixOS configuration is $BEHIND commit(s) behind remote.\n\n<b>Commits:</b>\n$COMMITS\n\n<b>Changed files:</b>\n$CHANGED_FILES\n\nWould you like to pull the changes now?" \
            --width=500 \
            --height=400

          if [ $? -eq 0 ]; then
            git pull origin master
            notify-send "NixOS Config" "Successfully pulled $BEHIND commit(s) from remote" --icon=dialog-information
          else
            notify-send "NixOS Config" "Skipped pulling remote changes" --icon=dialog-warning
          fi
        fi
      ''
      else ''
            # Server: Write notification to state file for terminal display
            mkdir -p "${stateDir}"
            cat > "${stateDir}/update-available" << ENDMSG
        BEHIND=$BEHIND
        COMMITS=$(echo "$COMMITS" | sed 's/"/\\"/g')
        CHANGED_FILES=$(echo "$CHANGED_FILES" | sed 's/"/\\"/g')
        ENDMSG
      ''
    }
  '';

  # Terminal banner script for server (reads state file and displays on login)
  terminalBanner = pkgs.writeShellScriptBin "nix-sync-banner" ''
    #!/usr/bin/env sh

    STATE_FILE="${stateDir}/update-available"

    if [ ! -f "$STATE_FILE" ]; then
      exit 0
    fi

    # Source the state file
    . "$STATE_FILE"

    if [ -z "$BEHIND" ] || [ "$BEHIND" = "0" ]; then
      rm -f "$STATE_FILE"
      exit 0
    fi

    # Colors
    yellow='\033[0;33m'
    cyan='\033[0;36m'
    green='\033[0;32m'
    bold='\033[1m'
    reset='\033[0m'
    dim='\033[2m'

    echo ""
    echo -e "''${yellow}''${bold}  NixOS config is $BEHIND commit(s) behind remote''${reset}"
    echo -e "''${dim}  ──────────────────────────────────────────────''${reset}"
    echo ""
    echo -e "''${cyan}  Commits:''${reset}"
    echo "$COMMITS" | while IFS= read -r line; do
      echo -e "    ''${green}$line''${reset}"
    done
    echo ""
    echo -e "''${cyan}  Changed files:''${reset}"
    echo "$CHANGED_FILES" | while IFS= read -r line; do
      echo -e "    $line"
    done
    echo ""
    echo -e "''${dim}  Run 'nix-pull' to pull changes or 'nix-check-remote' to re-check''${reset}"
    echo ""
  '';
in {
  config = lib.mkMerge [
    # Shared: nix-check-remote script is always available
    {
      home.packages = [checkScript];
    }

    # Desktop: GUI notifications via zenity + notify-send
    (lib.mkIf hasDesktop {
      home.packages = [pkgs.zenity];

      systemd.user.services.nix-config-sync-check = {
        Unit = {
          Description = "Check for NixOS config updates from remote";
          After = ["graphical-session.target" "network-online.target"];
        };

        Service = {
          Type = "oneshot";
          ExecStart = "${pkgs.writeShellScript "nix-sync-check" ''
            sleep 15
            ${checkScript}/bin/nix-check-remote
          ''}";
          RemainAfterExit = false;
        };

        Install = {
          WantedBy = ["graphical-session.target"];
        };
      };
    })

    # Server: terminal banner on login + periodic timer
    (lib.mkIf (!hasDesktop) {
      home.packages = [terminalBanner];

      systemd.user.services.nix-config-sync-check = {
        Unit = {
          Description = "Check for NixOS config updates from remote";
          After = ["network-online.target"];
        };

        Service = {
          Type = "oneshot";
          ExecStart = "${checkScript}/bin/nix-check-remote";
          RemainAfterExit = false;
        };
      };

      systemd.user.timers.nix-config-sync-check = {
        Unit = {
          Description = "Periodically check for NixOS config updates";
        };

        Timer = {
          OnBootSec = "2min";
          OnUnitActiveSec = "1h";
          Persistent = true;
        };

        Install = {
          WantedBy = ["timers.target"];
        };
      };

      # Show banner on shell login
      programs.zsh.initContent = ''
        # Show NixOS config sync notification if updates are available
        ${terminalBanner}/bin/nix-sync-banner
      '';
    })
  ];
}
