{
  pkgs,
  config,
  lib,
  ...
}: let
  # Define the script as a separate variable so we can reference it
  nix-check-remote = pkgs.writeShellScriptBin "nix-check-remote" ''
        #!/usr/bin/env sh

        # cd to your config dir
        cd ${config.nixosDir}

        # Fetch remote changes without merging
        git fetch origin master --quiet

        # Check if local is behind remote
        LOCAL=$(git rev-parse HEAD)
        REMOTE=$(git rev-parse origin/master)

        if [ "$LOCAL" != "$REMOTE" ]; then
          # Count commits behind
          BEHIND=$(git rev-list HEAD..origin/master --count)

          # Get commit messages and parse them
          COMMITS=$(while IFS= read -r line; do
            # Check if the line contains a colon (hostname prefix)
            if echo "$line" | grep -q ":"; then
              # Extract everything after the first colon
              MESSAGE=$(echo "$line" | cut -d':' -f2-)
              # Remove the version info in parentheses at the end
              MESSAGE=$(echo "$MESSAGE" | sed 's/ ([^)]*)$//')
              # Remove leading/trailing spaces
              MESSAGE=$(echo "$MESSAGE" | sed 's/^ *//;s/ *$//')
              # Output with bullet point
              echo "• $MESSAGE"
            else
              # No colon found, use the whole line
              echo "• $line"
            fi
          done <<< "$(git log HEAD..origin/master --pretty=format:"%s")")

          # Get list of changed files (limit to 10 to avoid huge popups)
          CHANGED_FILES=$(git diff --name-only HEAD origin/master | head -10 | sed 's/^/• /')
          FILE_COUNT=$(git diff --name-only HEAD origin/master | wc -l)

          # Add ellipsis if there are more than 10 files
          if [ "$FILE_COUNT" -gt 10 ]; then
            CHANGED_FILES="$CHANGED_FILES
    • ... and $((FILE_COUNT - 10)) more files"
          fi

          # Use zenity for GUI prompt if available, otherwise fall back to terminal
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
          else
            # Terminal fallback
            echo "Your NixOS configuration is $BEHIND commit(s) behind remote."
            echo ""
            echo "Commits:"
            echo "$COMMITS"
            echo ""
            echo "Changed files:"
            echo "$CHANGED_FILES"
            echo ""
            read -p "Would you like to pull the changes now? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
              git pull origin master
              echo "Successfully pulled changes from remote"
            else
              echo "Skipped pulling remote changes"
            fi
          fi
        fi
  '';
in {
  home.packages = with pkgs; [
    # Script to check for remote changes
    nix-check-remote

    # Add zenity for GUI prompts
    zenity
  ];

  # Systemd user service to check on login
  systemd.user.services.nix-config-sync-check = {
    Unit = {
      Description = "Check for NixOS config updates from remote";
      After = ["graphical-session.target"];
    };

    Service = {
      Type = "oneshot";
      ExecStart = "${pkgs.writeShellScript "nix-sync-check" ''
        # Wait a bit for desktop to fully load
        sleep 5
        ${nix-check-remote}/bin/nix-check-remote
      ''}";
      RemainAfterExit = false;
    };

    Install = {
      WantedBy = ["graphical-session.target"];
    };
  };
}
