{
  pkgs,
  lib,
  config,
  ...
}: let
  # Define the zsh history sync script
  zsh-history-sync = pkgs.writeShellScriptBin "zsh-history-sync" ''
    #!/usr/bin/env bash

    HISTORY_FILE="$HOME/.local/share/zsh/history"
    REPO_DIR="$HOME/.config/zsh-history-repo"
    REPO_URL="git@github.com:Hailst0rm1/zsh-history.git"

    # Function to log messages
    log() {
      echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1"
    }

    # Function to setup repository
    setup_repo() {
      if [ ! -d "$REPO_DIR" ]; then
        log "Setting up zsh-history repository..."
        git clone "$REPO_URL" "$REPO_DIR" 2>/dev/null || {
          log "Creating new repository..."
          mkdir -p "$REPO_DIR"
          cd "$REPO_DIR"
          git init
          git remote add origin "$REPO_URL"
          touch history
          git add history
          git commit -m "Initial commit"
          git push -u origin main 2>/dev/null || git push -u origin master
        }
      fi

      # Ensure git line ending settings
      cd "$REPO_DIR"
      git config core.autocrlf false
      git config core.eol lf
    }

    # Function to deduplicate history file
    deduplicate_history() {
      local file="$1"

      if [ ! -f "$file" ]; then
        log "History file not found for deduplication"
        return 1
      fi

      local temp_file="$(mktemp)"

      # Process the file to extract unique commands
      # Handle both extended format (: timestamp:duration;command) and simple format
      awk '
        BEGIN {
          in_multiline = 0
          current_entry = ""
          current_cmd = ""
        }

        /^: [0-9]+:[0-9]+;/ {
          # Extended format entry
          if (current_cmd != "" && !(current_cmd in seen)) {
            seen[current_cmd] = 1
            print current_entry
          }

          # Extract the command part (everything after the semicolon)
          match($0, /^: [0-9]+:[0-9]+;(.*)$/, arr)
          current_cmd = arr[1]
          current_entry = $0
          in_multiline = 1
          next
        }

        /^[^:]/ {
          if (in_multiline) {
            # Continuation of multi-line extended format command
            current_cmd = current_cmd "\n" $0
            current_entry = current_entry "\n" $0
          } else {
            # Simple format entry
            if (!($0 in seen)) {
              seen[$0] = 1
              print $0
            }
          }
          next
        }

        /^$/ {
          # Empty line might indicate end of multi-line command
          if (current_cmd != "" && !(current_cmd in seen)) {
            seen[current_cmd] = 1
            print current_entry
          }
          current_cmd = ""
          current_entry = ""
          in_multiline = 0
          next
        }

        END {
          # Output the last entry if exists
          if (current_cmd != "" && !(current_cmd in seen)) {
            seen[current_cmd] = 1
            print current_entry
          }
        }
      ' "$file" > "$temp_file"

      # Count entries before and after
      local before_count=$(wc -l < "$file")
      local after_count=$(wc -l < "$temp_file")

      # Replace the original file
      mv "$temp_file" "$file"

      log "Deduplicated history: $before_count lines -> $after_count lines"
    }

    # Function to pull latest changes
    pull_history() {
      cd "$REPO_DIR"
      log "Pulling latest history from remote..."

      # Store the current repo history hash before pulling
      local before_pull_hash=""
      if [ -f "$REPO_DIR/history" ]; then
        before_pull_hash=$(sha256sum "$REPO_DIR/history" | cut -d' ' -f1)
      fi

      # Fetch and pull latest changes
      git fetch origin
      git pull origin main 2>/dev/null || git pull origin master 2>/dev/null || {
        log "No remote changes or pull failed"
        return 0
      }

      # Check if repo history actually changed after pull
      local after_pull_hash=""
      if [ -f "$REPO_DIR/history" ]; then
        after_pull_hash=$(sha256sum "$REPO_DIR/history" | cut -d' ' -f1)
      fi

      # Only process if the repo history actually changed
      if [ "$before_pull_hash" != "$after_pull_hash" ]; then
        if [ -f "$REPO_DIR/history" ]; then
          if [ -f "$HISTORY_FILE" ]; then
            # Check if remote has content not in local
            local local_hash=$(sha256sum "$HISTORY_FILE" | cut -d' ' -f1)
            local remote_hash="$after_pull_hash"

            if [ "$local_hash" != "$remote_hash" ]; then
              log "Remote history differs from local, merging and deduplicating"
              # Merge both files then deduplicate
              cat "$HISTORY_FILE" "$REPO_DIR/history" > "$HISTORY_FILE.tmp"
              mv "$HISTORY_FILE.tmp" "$HISTORY_FILE"
              deduplicate_history "$HISTORY_FILE"
            else
              log "Local and remote history are identical"
            fi
          else
            # No local history, just copy remote
            log "Copying remote history to local"
            mkdir -p "$(dirname "$HISTORY_FILE")"
            cp "$REPO_DIR/history" "$HISTORY_FILE"
            deduplicate_history "$HISTORY_FILE"
          fi
        fi
      else
        log "No changes in remote history"
      fi

      log "Pull completed"
    }

    # Function to push local changes
    push_history() {
      cd "$REPO_DIR"

      # Check if local history exists
      if [ ! -f "$HISTORY_FILE" ]; then
        log "No local history file found"
        return 0
      fi

      # Deduplicate local history before pushing
      deduplicate_history "$HISTORY_FILE"

      # Copy local history to repo
      cp "$HISTORY_FILE" "$REPO_DIR/history"

      # Check if there are changes
      if git diff --quiet HEAD -- history 2>/dev/null; then
        log "No changes to push"
        return 0
      fi

      log "Pushing history to remote..."
      git add history
      git commit -m "Update history from $(hostname) - $(date '+%Y-%m-%d %H:%M:%S')"
      git push origin main 2>/dev/null || git push origin master 2>/dev/null || {
        log "Push failed, trying to resolve..."
        git pull --rebase origin main 2>/dev/null || git pull --rebase origin master 2>/dev/null
        git push origin main 2>/dev/null || git push origin master 2>/dev/null
      }

      log "Push completed"
    }

    # Main execution
    case "''${1:-sync}" in
      "setup")
        setup_repo
        ;;
      "pull")
        setup_repo
        pull_history
        ;;
      "push")
        setup_repo
        push_history
        ;;
      "sync")
        setup_repo
        pull_history
        push_history
        ;;
      "dedup")
        # Standalone deduplication command
        if [ -f "$HISTORY_FILE" ]; then
          deduplicate_history "$HISTORY_FILE"
        else
          log "No history file found"
          exit 1
        fi
        ;;
      *)
        echo "Usage: $0 {setup|pull|push|sync|dedup}"
        echo "  setup: Initialize the repository"
        echo "  pull:  Pull remote history"
        echo "  push:  Push local history"
        echo "  sync:  Pull then push (default)"
        echo "  dedup: Deduplicate local history"
        exit 1
        ;;
    esac
  '';
in {
  options.importConfig.zsh-history-sync.enable = lib.mkEnableOption "Enable zsh history synchronization across devices using a git repository";

  config = lib.mkIf config.importConfig.zsh-history-sync.enable {
    home.packages = with pkgs; [
      zsh-history-sync
      git
    ];

    # Systemd user service to pull history on login
    systemd.user.services.zsh-history-pull = {
      Unit = {
        Description = "Pull zsh history from remote on login";
        After = ["network-online.target"];
        Wants = ["network-online.target"];
      };

      Service = {
        Type = "oneshot";
        ExecStart = "${zsh-history-sync}/bin/zsh-history-sync pull";
        StandardOutput = "journal";
        StandardError = "journal";
      };

      Install = {
        WantedBy = ["default.target"];
      };
    };

    # Systemd user service to push history on shutdown
    systemd.user.services.zsh-history-push = {
      Unit = {
        Description = "Push zsh history to remote on shutdown";
        DefaultDependencies = false;
        Before = ["shutdown.target" "reboot.target" "halt.target"];
        RequiresMountsFor = ["%h"];
      };

      Service = {
        Type = "oneshot";
        ExecStart = "${zsh-history-sync}/bin/zsh-history-sync push";
        TimeoutStartSec = "30s";
        StandardOutput = "journal";
        StandardError = "journal";
      };

      Install = {
        WantedBy = ["shutdown.target"];
      };
    };

    # Timer to periodically sync history (every 30 minutes)
    systemd.user.services.zsh-history-periodic-sync = {
      Unit = {
        Description = "Periodic zsh history sync";
        After = ["network-online.target"];
        Wants = ["network-online.target"];
      };

      Service = {
        Type = "oneshot";
        ExecStart = "${zsh-history-sync}/bin/zsh-history-sync sync";
        StandardOutput = "journal";
        StandardError = "journal";
      };
    };

    systemd.user.timers.zsh-history-periodic-sync = {
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
  };
}
