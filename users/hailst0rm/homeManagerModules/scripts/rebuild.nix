{
  pkgs,
  hostname,
  config,
  ...
}: {
  # Shell script to handle rebuilds in a more convenient way
  home.packages = with pkgs; [
    # Prerequisites
    libnotify
    alejandra

    # Switch
    (writeShellScriptBin "nix-switch" ''
      #!/usr/bin/env sh

      # cd to your config dir
      pushd ${config.nixosDir}

      # Fetch remote changes to check if we're behind
      git fetch origin master --quiet
      LOCAL=$(git rev-parse HEAD)
      REMOTE=$(git rev-parse origin/master)

      if [ "$LOCAL" != "$REMOTE" ]; then
        BEHIND=$(git rev-list HEAD..origin/master --count)
        echo "Warning: Local config is $BEHIND commit(s) behind remote."
        read -p "Pull remote changes before rebuilding? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
          git pull origin master
        fi
      fi

      # Check if the user passed "--show-trace" as an argument
      show_trace_flag=""
      if [ "$1" = "trace" ]; then
        show_trace_flag="--show-trace"
      fi

      # Exit if no changes are made
      if git diff HEAD --quiet; then
          echo "Warning: No changes detected in config."
      fi

      # Autoformat the nix files with alejandra
      alejandra . &>/dev/null \
        || ( alejandra . ; echo "formatting failed!" && exit 1)

      # Show the changes
      git diff HEAD -U0
      git add .

      # Rebuild with optional --show-trace and exit on failure
      echo "It is time to rebuild NixOS..."
      sudo nixos-rebuild switch --flake ./#${config.hostname} $show_trace_flag || {
        echo "Nixos-rebuild failed."
        notify-send -e "NixOS Rebuild Failed!" --icon=dialog-error
        popd
        exit 1
      }

      # Get current generation metadata
      current=$(nixos-rebuild list-generations | grep current)

      echo "Build Complete!"

      # Prompt user for an optional commit message
      read -rp "Enter a commit message to save changes (leave empty to skip): " user_msg

      # Only commit and push if message is not empty
      if [ -n "$user_msg" ]; then
        echo "Committing and pushing changes..."
        git commit -am "${config.hostname}: $user_msg ($current)"
        git push
      else
        echo "Skipping commit (no message provided)"
      fi

      # Back to where you were
      popd

      # Notify all OK!
      notify-send -e "NixOS Rebuilt OK!" --icon=software-update-available
    '')

    # Test
    (writeShellScriptBin "nix-test" ''
      #!/usr/bin/env sh

      # cd to your config dir
      pushd ${config.nixosDir}

      # Check if the user passed "--show-trace" as an argument
      show_trace_flag=""
      if [ "$1" = "trace" ]; then
        show_trace_flag="--show-trace"
      fi

      # Exit if no changes are made
      if git diff --quiet; then
          echo "No changes detected in config. Exiting."
          notify-send -e "NixOS Rebuild Failed!" --icon=software-update-available
          popd
          exit 0
      fi

      # Autoformat the nix files with alejandra
      alejandra . &>/dev/null \
        || ( alejandra . ; echo "formatting failed!" && exit 1)

      # Show the changes
      git diff -U0
      git add .

      # Rebuild with optional --show-trace and exit on failure
      echo "It is time to rebuild NixOS..."
      sudo nixos-rebuild test --flake ./#${config.hostname} $show_trace_flag || {
        echo "Nixos-rebuild failed."
        notify-send -e "NixOS Rebuild Failed!" --icon=dialog-error
        popd
        exit 1
      }

      echo "Build Complete!"

      # Back to where you were
      popd

      # Notify all OK!
      notify-send -e "NixOS Rebuilt OK!" --icon=software-update-available
    '')

    # Boot
    (writeShellScriptBin "nix-boot" ''
      #!/usr/bin/env sh

      # cd to your config dir
      pushd ${config.nixosDir}

      # Fetch remote changes to check if we're behind
      git fetch origin master --quiet
      LOCAL=$(git rev-parse HEAD)
      REMOTE=$(git rev-parse origin/master)

      if [ "$LOCAL" != "$REMOTE" ]; then
        BEHIND=$(git rev-list HEAD..origin/master --count)
        echo "Warning: Local config is $BEHIND commit(s) behind remote."
        read -p "Pull remote changes before rebuilding? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
          git pull origin master
        fi
      fi

      # Check if the user passed "--show-trace" as an argument
      show_trace_flag=""
      if [ "$1" = "trace" ]; then
        show_trace_flag="--show-trace"
      fi

      # Exit if no changes are made
      if git diff HEAD --quiet; then
          echo "Warning: No changes detected in config."
          notify-send -e "NixOS Rebuild Failed!" --icon=software-update-available
      fi

      # Autoformat the nix files with alejandra
      alejandra . &>/dev/null \
        || ( alejandra . ; echo "formatting failed!" && exit 1)

      # Show the changes
      git diff HEAD -U0
      git add .

      # Rebuild with optional --show-trace and exit on failure
      echo "It is time to rebuild NixOS..."
      sudo nixos-rebuild boot --flake ./#${config.hostname} $show_trace_flag || {
        echo "Nixos-rebuild failed."
        notify-send -e "NixOS Rebuild Failed!" --icon=dialog-error
        popd
        exit 1
      }

      # Get current generation metadata
      current=$(nixos-rebuild list-generations | grep current)

      echo "Build Complete!"

      # Prompt user for an optional commit message
      read -rp "Enter a commit message to save changes (leave empty to skip): " user_msg

      # Only commit and push if message is not empty
      if [ -n "$user_msg" ]; then
        echo "Committing and pushing changes..."
        git commit -am "${config.hostname}: $user_msg ($current)"
        git push
      else
        echo "Skipping commit (no message provided)"
      fi

      # Back to where you were
      popd

      # Notify all OK!
      notify-send -e "NixOS Rebuilt OK!" --icon=software-update-available
    '')
  ];
}
