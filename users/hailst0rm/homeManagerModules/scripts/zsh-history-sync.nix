{
  pkgs,
  lib,
  config,
  ...
}: let
  # Define the zsh history sync script
  zsh-history-sync = pkgs.writeShellScriptBin "zsh-history-sync" ''
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

    # Function to deduplicate history
    deduplicate_history() {
        local input_file="$1"
        local output_file="$2"

        declare -A seen_commands
        declare -a output_lines

        # Read file in reverse to prioritize most recent entries
        while IFS= read -r line; do
            # Extract the actual command from the line
            if [[ $line =~ ^:[[:space:]]*[0-9]+:[0-9]+\;(.*)$ ]]; then
                # Line has timestamp format: ": 1759996768:0;command"
                command="''${BASH_REMATCH[1]}"
                is_timestamped=true
            else
                # Line without timestamp
                command="$line"
                is_timestamped=false
            fi

            # Check if we've seen this command before
            if [[ -z "''${seen_commands[$command]}" ]]; then
                # First time seeing this command
                seen_commands[$command]=1
                output_lines+=("$line")
            elif [[ "$is_timestamped" == true ]] && [[ "''${seen_commands[$command]}" == "untimestamped" ]]; then
                # We saw an untimestamped version, but now have a timestamped one
                # Replace the untimestamped version with this timestamped one
                for i in "''${!output_lines[@]}"; do
                    if [[ "''${output_lines[$i]}" == "$command" ]]; then
                        output_lines[$i]="$line"
                        seen_commands[$command]=1
                        break
                    fi
                done
            fi

            # Track whether we've seen an untimestamped version
            if [[ "$is_timestamped" == false ]]; then
                seen_commands[$command]="untimestamped"
            fi
        done < <(tac "$input_file")

        # Output in original order (reverse again since we read backwards)
        for ((i=''${#output_lines[@]}-1; i>=0; i--)); do
            echo "''${output_lines[$i]}"
        done > "$output_file"
    }

    # Check if local history file exists
    if [[ ! -f "$HISTORY_FILE" ]]; then
        log_error "Local history file not found: $HISTORY_FILE"
        exit 1
    fi

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

    # Create temporary file for merged history
    TEMP_MERGED=$(mktemp)
    TEMP_DEDUPED=$(mktemp)

    # Merge local and remote history
    log_info "Merging local and remote history"
    if [[ -f "$REMOTE_HISTORY" ]]; then
        cat "$REMOTE_HISTORY" "$HISTORY_FILE" > "$TEMP_MERGED"
    else
        log_warn "Remote history file not found, using local only"
        cp "$HISTORY_FILE" "$TEMP_MERGED"
    fi

    # Deduplicate the merged history
    log_info "Deduplicating merged history"
    deduplicate_history "$TEMP_MERGED" "$TEMP_DEDUPED"

    # Count entries
    local_count=$(wc -l < "$HISTORY_FILE")
    if [[ -f "$REMOTE_HISTORY" ]]; then
        remote_count=$(wc -l < "$REMOTE_HISTORY")
    else
        remote_count=0
    fi
    merged_count=$(wc -l < "$TEMP_DEDUPED")

    log_info "Local entries: $local_count"
    log_info "Remote entries: $remote_count"
    log_info "Merged unique entries: $merged_count"

    # Update local history file
    log_info "Updating local history file"
    cp "$TEMP_DEDUPED" "$HISTORY_FILE"

    # Update remote history file
    log_info "Updating remote history file"
    cp "$TEMP_DEDUPED" "$REMOTE_HISTORY"

    # Commit and push to remote
    cd "$REPO_DIR"
    if [[ -n $(git status --porcelain) ]]; then
        log_info "Committing changes"
        git add history
        git commit -m "Update history: $merged_count entries ($(date '+%Y-%m-%d %H:%M:%S'))"

        log_info "Pushing to remote"
        git push origin main || git push origin master

        log_info "History synced successfully!"
    else
        log_info "No changes to commit"
    fi
    cd - > /dev/null

    # Cleanup
    rm "$TEMP_MERGED" "$TEMP_DEDUPED"

    log_info "Done!"

  '';
in {
  options.importConfig.zsh-history-sync.enable = lib.mkEnableOption "Enable zsh history synchronization across devices using a git repository";

  config = lib.mkIf config.importConfig.zsh-history-sync.enable {
    home.packages = with pkgs; [
      zsh-history-sync
      git
    ];

    # Systemd user service to sync history on login
    systemd.user.services.zsh-history-sync = {
      Unit = {
        Description = "Sync zsh history with remote repository";
        After = ["network-online.target" "graphical-session.target"];
        Wants = ["network-online.target"];
      };

      Service = {
        Type = "oneshot";
        ExecStartPre = "${pkgs.coreutils}/bin/sleep 10";
        ExecStart = "${zsh-history-sync}/bin/zsh-history-sync";
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

    # Systemd user service to sync history before shutdown
    systemd.user.services.zsh-history-sync-shutdown = {
      Unit = {
        Description = "Sync zsh history before shutdown";
        DefaultDependencies = false;
        Before = ["shutdown.target" "reboot.target" "halt.target"];
      };

      Service = {
        Type = "oneshot";
        ExecStart = "${zsh-history-sync}/bin/zsh-history-sync";
        StandardOutput = "journal";
        StandardError = "journal";
        TimeoutStartSec = "30s";
        Environment = [
          "PATH=${pkgs.git}/bin:${pkgs.openssh}/bin:${pkgs.coreutils}/bin:${pkgs.gawk}/bin:/run/current-system/sw/bin"
        ];
      };

      Install = {
        WantedBy = ["shutdown.target" "reboot.target" "halt.target"];
      };
    };

    # Timer to periodically sync history (every 30 minutes)
    systemd.user.timers.zsh-history-sync = {
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
