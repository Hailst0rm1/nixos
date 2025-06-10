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

      echo "Build Complete! Commiting build..."

      # Prompt user for an additional commit message
      read -rp "Enter a short description of the change (optional): " user_msg

      # Commit all changes witih the generation metadata
      git commit -am "${config.hostname}: $user_msg ($current)"

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

      echo "Build Complete! Commiting build..."

      # Prompt user for an additional commit message
      read -rp "Enter a short description of the change (optional): " user_msg

      # Commit all changes witih the generation metadata
      git commit -am "${config.hostname}: $user_msg ($current)"

      # Back to where you were
      popd

      # Notify all OK!
      notify-send -e "NixOS Rebuilt OK!" --icon=software-update-available
    '')
  ];
}
