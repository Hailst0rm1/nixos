{
  pkgs,
  lib,
  config,
  ...
}: let
  # Shared deduplication AWK script used by both startup and push
  # Deduplicates by command text, keeps the entry with the latest timestamp,
  # and sorts output by timestamp so file order matches chronological order.
  deduplicateAwk = ''
    BEGIN {
        current_cmd = ""
        current_block = ""
        current_ts = 0
        in_multiline = 0
    }

    /^: *[0-9]+:[0-9]+;/ {
        if (current_cmd != "") {
            # Store pending multiline command
            if (!(cmd_key in timestamps) || current_ts > timestamps[cmd_key]) {
                commands[cmd_key] = current_block
                timestamps[cmd_key] = current_ts
            }
        }

        # Extract timestamp and command part
        match($0, /^: *([0-9]+):[0-9]+;(.*)$/, arr)
        current_ts = arr[1] + 0
        cmd_only = arr[2]

        current_cmd = cmd_only
        current_block = $0

        if ($0 ~ /\\$/) {
            in_multiline = 1
        } else {
            in_multiline = 0
            cmd_key = current_cmd
            if (!(cmd_key in timestamps) || current_ts > timestamps[cmd_key]) {
                commands[cmd_key] = current_block
                timestamps[cmd_key] = current_ts
            }
            current_cmd = ""
            current_block = ""
        }
        next
    }

    in_multiline {
        current_cmd = current_cmd "\n" $0
        current_block = current_block "\n" $0

        if ($0 !~ /\\$/) {
            in_multiline = 0
            cmd_key = current_cmd
            if (!(cmd_key in timestamps) || current_ts > timestamps[cmd_key]) {
                commands[cmd_key] = current_block
                timestamps[cmd_key] = current_ts
            }
            current_cmd = ""
            current_block = ""
        }
        next
    }

    END {
        # Sort by timestamp so file order is chronological
        n = asorti(timestamps, sorted_keys, "@val_num_asc")
        for (i = 1; i <= n; i++) {
            print commands[sorted_keys[i]]
        }
    }
  '';

  # Define the zsh history sync script for startup (pull from remote and merge)
  zsh-history-sync-startup = pkgs.writeShellScriptBin "zsh-history-sync-startup" ''
    #!/usr/bin/env bash

    set -e

    HISTORY_FILE="$HOME/.local/share/zsh/history"
    REPO_DIR="$HOME/.config/zsh-history-repo"
    REPO_URL="git@github.com:Hailst0rm1/zsh-history.git"
    REMOTE_HISTORY="$REPO_DIR/history"
    BACKUP_FILE="$HOME/.local/share/zsh/history.bak"

    # Colors for output
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m' # No Color

    log_info() {
        echo -e "''${GREEN}[INFO]''${NC} $1"
    }

    log_warn() {
        echo -e "''${YELLOW}[WARN]''${NC} $1"
    }

    log_error() {
        echo -e "''${RED}[ERROR]''${NC} $1"
    }

    # Clone or pull the repository
    if [[ ! -d "$REPO_DIR" ]]; then
        log_info "Cloning repository from $REPO_URL"
        git clone "$REPO_URL" "$REPO_DIR"
    else
        log_info "Repository exists, pulling latest changes"
        cd "$REPO_DIR"
        git pull origin main || git pull origin master || log_warn "Could not pull from remote"
        cd - > /dev/null
    fi

    # Backup current local history if it exists
    if [[ -f "$HISTORY_FILE" ]]; then
        log_info "Creating backup of local history: $BACKUP_FILE"
        cp "$HISTORY_FILE" "$BACKUP_FILE"
    fi

    mkdir -p "$(dirname "$HISTORY_FILE")"

    # Merge local and remote history instead of overwriting
    if [[ -f "$HISTORY_FILE" ]] && [[ -f "$REMOTE_HISTORY" ]]; then
        log_info "Merging local and remote history"
        TEMP_MERGED=$(mktemp)
        cat "$HISTORY_FILE" "$REMOTE_HISTORY" > "$TEMP_MERGED"

        # Deduplicate the merged result (keeps the latest occurrence of each command)
        TEMP_DEDUPED=$(mktemp)
        awk '${deduplicateAwk}' "$TEMP_MERGED" > "$TEMP_DEDUPED"
        mv "$TEMP_DEDUPED" "$HISTORY_FILE"
        rm -f "$TEMP_MERGED"

        local_count=$(wc -l < "$HISTORY_FILE")
        log_info "Merged history: $local_count entries"
    elif [[ -f "$REMOTE_HISTORY" ]]; then
        log_info "No local history found, using remote"
        cp "$REMOTE_HISTORY" "$HISTORY_FILE"
        local_count=$(wc -l < "$HISTORY_FILE")
        log_info "Local history set from remote: $local_count entries"
    else
        log_warn "No remote history found, keeping local"
    fi

    log_info "Done!"
  '';

  # Define the zsh history sync script for periodic/shutdown (push to remote)
  zsh-history-sync-push = pkgs.writeShellScriptBin "zsh-history-sync-push" ''
    #!/usr/bin/env bash
    set -e
    HISTORY_FILE="$HOME/.local/share/zsh/history"
    REPO_DIR="$HOME/.config/zsh-history-repo"
    REPO_URL="git@github.com:Hailst0rm1/zsh-history.git"
    REMOTE_HISTORY="$REPO_DIR/history"

    # Colors for output
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m' # No Color

    log_info() {
        echo -e "''${GREEN}[INFO]''${NC} $1"
    }

    log_warn() {
        echo -e "''${YELLOW}[WARN]''${NC} $1"
    }

    log_error() {
        echo -e "''${RED}[ERROR]''${NC} $1"
    }


    # Deduplication function
    deduplicate_history() {
        local input_file="$1"
        local output_file="$2"

        awk '${deduplicateAwk}' "$input_file" > "$output_file"
    }

    # Check if local history file exists
    if [[ ! -f "$HISTORY_FILE" ]]; then
        log_error "Local history file not found: $HISTORY_FILE"
        exit 1
    fi

    # Check if repository exists
    if [[ ! -d "$REPO_DIR" ]]; then
        log_error "Repository not found: $REPO_DIR. Run startup sync first."
        exit 1
    fi

    # Deduplicate local history before comparing/pushing
    log_info "Deduplicating local history"
    TEMP_DEDUPED=$(mktemp)
    deduplicate_history "$HISTORY_FILE" "$TEMP_DEDUPED"

    # Count changes
    original_count=$(wc -l < "$HISTORY_FILE")
    deduped_count=$(wc -l < "$TEMP_DEDUPED")
    removed=$((original_count - deduped_count))

    if [[ $removed -gt 0 ]]; then
        log_info "Removed $removed duplicate entries"
    fi

    # Update local history with deduplicated version
    mv "$TEMP_DEDUPED" "$HISTORY_FILE"

    # Check if there are differences with remote
    if [[ ! -f "$REMOTE_HISTORY" ]] || ! cmp -s "$HISTORY_FILE" "$REMOTE_HISTORY"; then
        log_info "Differences detected, updating remote history"
        cp "$HISTORY_FILE" "$REMOTE_HISTORY"

        cd "$REPO_DIR"
        git add history
        git commit -m "Update history: $deduped_count entries ($(date '+%Y-%m-%d %H:%M:%S'))"

        log_info "Pushing to remote"
        git push origin main || git push origin master

        log_info "History synced successfully!"
    else
        log_info "No changes detected, skipping sync"
    fi

    log_info "Done!"
  '';
in {
  options.importConfig.zsh-history-sync.enable = lib.mkEnableOption "Enable zsh history synchronization across devices using a git repository";

  config = lib.mkIf config.importConfig.zsh-history-sync.enable {
    home.packages = with pkgs; [
      zsh-history-sync-startup
      zsh-history-sync-push
      git
    ];

    # Systemd user service to sync history on login (pull from remote)
    systemd.user.services.zsh-history-sync = {
      Unit = {
        Description = "Sync zsh history from remote repository on startup";
        After = ["network-online.target" "graphical-session.target"];
        Wants = ["network-online.target"];
      };

      Service = {
        Type = "oneshot";
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 10";
        ExecStart = "${zsh-history-sync-startup}/bin/zsh-history-sync-startup";
        StandardOutput = "journal";
        StandardError = "journal";
        Environment = [
          "PATH=${pkgs.git}/bin:${pkgs.openssh}/bin:${pkgs.coreutils}/bin:${pkgs.gawk}/bin:/run/current-system/sw/bin"
        ];
      };

      Install = {
        WantedBy = ["default.target"];
      };
    };

    # Systemd user service to sync history before session exit (covers shutdown/reboot/logout)
    systemd.user.services.zsh-history-sync-shutdown = {
      Unit = {
        Description = "Sync zsh history to remote before session exit";
        DefaultDependencies = false;
        Before = ["exit.target"];
      };

      Service = {
        Type = "oneshot";
        # Use -c with || true so a network failure doesn't block shutdown
        ExecStart = "${pkgs.bash}/bin/bash -c '${zsh-history-sync-push}/bin/zsh-history-sync-push || true'";
        StandardOutput = "journal";
        StandardError = "journal";
        TimeoutStartSec = "30s";
        Environment = [
          "PATH=${pkgs.git}/bin:${pkgs.openssh}/bin:${pkgs.coreutils}/bin:${pkgs.gawk}/bin:/run/current-system/sw/bin"
          "HOME=%h"
        ];
      };

      Install = {
        WantedBy = ["exit.target"];
      };
    };

    # Timer to periodically sync history (every 30 minutes) - push to remote
    systemd.user.timers.zsh-history-sync-periodic = {
      Unit = {
        Description = "Run zsh history sync every 30 minutes";
        After = ["network-online.target"];
      };

      Timer = {
        OnBootSec = "5min";
        OnUnitActiveSec = "30min";
        Persistent = true;
      };

      Install = {
        WantedBy = ["timers.target"];
      };
    };

    # Service triggered by the timer (push to remote)
    systemd.user.services.zsh-history-sync-periodic = {
      Unit = {
        Description = "Periodically sync zsh history to remote";
      };

      Service = {
        Type = "oneshot";
        ExecStart = "${zsh-history-sync-push}/bin/zsh-history-sync-push";
        StandardOutput = "journal";
        StandardError = "journal";
        Environment = [
          "PATH=${pkgs.git}/bin:${pkgs.openssh}/bin:${pkgs.coreutils}/bin:${pkgs.gawk}/bin:/run/current-system/sw/bin"
        ];
      };
    };
  };
}
