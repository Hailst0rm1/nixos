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

      # Test GitHub connectivity
      echo "🌐 Testing GitHub connectivity..."
      notify-send -e "NixOS Rebuild" "Testing GitHub connectivity..." --icon=network-wireless

      if ! timeout 5 git ls-remote git@github.com:hailst0rm1/nixos.git HEAD &>/dev/null; then
        echo "❌ Cannot reach GitHub. Check your internet connection."
        notify-send -e "NixOS Rebuild Failed!" "Cannot reach GitHub. Check your internet connection." --icon=dialog-error --urgency=critical
        popd
        exit 1
      fi
      echo "✅ GitHub connectivity OK"

      # Fetch remote changes to check if we're behind
      echo "📡 Fetching remote changes..."
      git fetch origin master --quiet
      LOCAL=$(git rev-parse HEAD)
      REMOTE=$(git rev-parse origin/master)

      if [ "$LOCAL" != "$REMOTE" ]; then
        BEHIND=$(git rev-list HEAD..origin/master --count)
        echo "⚠️  Warning: Local config is $BEHIND commit(s) behind remote."
        notify-send -e "NixOS Config Behind Remote" "Your config is $BEHIND commit(s) behind. Pull before rebuilding?" --icon=dialog-warning
        read -p "Pull remote changes before rebuilding? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
          echo "⬇️  Pulling remote changes..."
          git pull origin master
        fi
      fi

      # Check if the user passed "--show-trace" as an argument
      show_trace_flag=""
      if [ "$1" = "trace" ]; then
        show_trace_flag="--show-trace"
      fi

      # Check for changes
      if git diff HEAD --quiet; then
          echo "⚠️  Warning: No changes detected in config."
      fi

      # Autoformat the nix files with alejandra
      echo "🎨 Formatting Nix files..."
      alejandra . &>/dev/null \
        || ( alejandra . ; echo "❌ Formatting failed!" && notify-send -e "Formatting Failed!" --icon=dialog-error && exit 1)

      # Show the changes
      echo "📝 Changes to be applied:"
      git diff HEAD -U0
      git add -N .

      # Rebuild with optional --show-trace and exit on failure
      echo ""
      echo "🔨 Rebuilding NixOS..."
      notify-send -e "NixOS Rebuild" "Building and switching ${config.hostname}..." --icon=system-software-update

      sudo nixos-rebuild switch --flake ./#${config.hostname} $show_trace_flag || {
        echo ""
        echo "❌ NixOS rebuild failed!"
        notify-send -e "NixOS Rebuild Failed!" "Build failed for ${config.hostname}" --icon=dialog-error --urgency=critical
        popd
        exit 1
      }

      # Get current generation metadata
      current=$(nixos-rebuild list-generations | awk '$NF == "True" {print "Generation " $1 " built on " $2}')

      echo ""
      echo "✅ Build Complete!"

      # Prompt user for an optional commit message
      read -rp "💾 Enter a commit message to save changes (leave empty to skip): " user_msg

      # Only commit and push if message is not empty
      if [ -n "$user_msg" ]; then
        echo "📤 Committing and pushing changes..."
        notify-send -e "NixOS Config" "Pushing changes to GitHub..." --icon=emblem-synchronizing
        git add .
        git commit -am "${config.hostname}: $user_msg ($current)"
        git push && echo "✅ Pushed to GitHub!" || echo "❌ Push failed!"
      else
        echo "⏭️  Skipping commit (no message provided)"
      fi

      # Back to where you were
      popd

      # Notify all OK!
      notify-send -e "NixOS Rebuilt Successfully!" "System switched to new generation" --icon=emblem-default
    '')

    # Test
    (writeShellScriptBin "nix-test" ''
      #!/usr/bin/env sh

      # cd to your config dir
      pushd ${config.nixosDir}

      # Test GitHub connectivity
      echo "🌐 Testing GitHub connectivity..."
      notify-send -e "NixOS Test Build" "Testing GitHub connectivity..." --icon=network-wireless

      if ! timeout 5 git ls-remote git@github.com:hailst0rm1/nixos.git HEAD &>/dev/null; then
        echo "❌ Cannot reach GitHub. Check your internet connection."
        notify-send -e "NixOS Test Failed!" "Cannot reach GitHub. Check your internet connection." --icon=dialog-error --urgency=critical
        popd
        exit 1
      fi
      echo "✅ GitHub connectivity OK"

      # Check if the user passed "--show-trace" as an argument
      show_trace_flag=""
      if [ "$1" = "trace" ]; then
        show_trace_flag="--show-trace"
      fi

      # Autoformat the nix files with alejandra
      echo "🎨 Formatting Nix files..."
      alejandra . &>/dev/null \
        || ( alejandra . ; echo "❌ Formatting failed!" && notify-send -e "Formatting Failed!" --icon=dialog-error && exit 1)

      # Show the changes if any
      if ! git diff --quiet; then
        echo "📝 Changes detected:"
        git diff -U0
        git add -N .
      else
        echo "ℹ️  No changes detected, testing current configuration..."
      fi

      # Rebuild with optional --show-trace and exit on failure
      echo ""
      echo "🔨 Building NixOS test configuration..."
      notify-send -e "NixOS Test Build" "Building test configuration for ${config.hostname}..." --icon=system-software-update

      sudo nixos-rebuild test --flake ./#${config.hostname} $show_trace_flag || {
        echo ""
        echo "❌ NixOS rebuild failed!"
        notify-send -e "NixOS Test Failed!" "Build failed for ${config.hostname}" --icon=dialog-error --urgency=critical
        popd
        exit 1
      }

      echo ""
      echo "✅ Test Build Complete!"

      # Back to where you were
      popd

      # Notify all OK!
      notify-send -e "NixOS Test Successful!" "Test build completed successfully for ${config.hostname}" --icon=emblem-default
    '')

    # Boot
    (writeShellScriptBin "nix-boot" ''
      #!/usr/bin/env sh

      # cd to your config dir
      pushd ${config.nixosDir}

      # Test GitHub connectivity
      echo "🌐 Testing GitHub connectivity..."
      notify-send -e "NixOS Boot Build" "Testing GitHub connectivity..." --icon=network-wireless

      if ! timeout 5 git ls-remote git@github.com:hailst0rm1/nixos.git HEAD &>/dev/null; then
        echo "❌ Cannot reach GitHub. Check your internet connection."
        notify-send -e "NixOS Boot Build Failed!" "Cannot reach GitHub. Check your internet connection." --icon=dialog-error --urgency=critical
        popd
        exit 1
      fi
      echo "✅ GitHub connectivity OK"

      # Fetch remote changes to check if we're behind
      echo "📡 Fetching remote changes..."
      git fetch origin master --quiet
      LOCAL=$(git rev-parse HEAD)
      REMOTE=$(git rev-parse origin/master)

      if [ "$LOCAL" != "$REMOTE" ]; then
        BEHIND=$(git rev-list HEAD..origin/master --count)
        echo "⚠️  Warning: Local config is $BEHIND commit(s) behind remote."
        notify-send -e "NixOS Config Behind Remote" "Your config is $BEHIND commit(s) behind. Pull before rebuilding?" --icon=dialog-warning
        read -p "Pull remote changes before rebuilding? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
          echo "⬇️  Pulling remote changes..."
          git pull origin master
        fi
      fi

      # Check if the user passed "--show-trace" as an argument
      show_trace_flag=""
      if [ "$1" = "trace" ]; then
        show_trace_flag="--show-trace"
      fi

      # Check for changes
      if git diff HEAD --quiet; then
          echo "⚠️  Warning: No changes detected in config."
      fi

      # Autoformat the nix files with alejandra
      echo "🎨 Formatting Nix files..."
      alejandra . &>/dev/null \
        || ( alejandra . ; echo "❌ Formatting failed!" && notify-send -e "Formatting Failed!" --icon=dialog-error && exit 1)

      # Show the changes
      echo "📝 Changes to be applied:"
      git diff HEAD -U0
      git add -N .

      # Rebuild with optional --show-trace and exit on failure
      echo ""
      echo "🔨 Building NixOS boot configuration..."
      notify-send -e "NixOS Boot Build" "Building boot configuration for ${config.hostname}..." --icon=system-software-update

      sudo nixos-rebuild boot --flake ./#${config.hostname} $show_trace_flag || {
        echo ""
        echo "❌ NixOS rebuild failed!"
        notify-send -e "NixOS Boot Build Failed!" "Build failed for ${config.hostname}" --icon=dialog-error --urgency=critical
        popd
        exit 1
      }

      # Get current generation metadata
      current=$(nixos-rebuild list-generations | awk '$NF == "True" {print "Generation " $1 " built on " $2}')

      echo ""
      echo "✅ Build Complete!"

      # Prompt user for an optional commit message
      read -rp "💾 Enter a commit message to save changes (leave empty to skip): " user_msg

      # Only commit and push if message is not empty
      if [ -n "$user_msg" ]; then
        echo "📤 Committing and pushing changes..."
        notify-send -e "NixOS Config" "Pushing changes to GitHub..." --icon=emblem-synchronizing
        git add .
        git commit -am "${config.hostname}: $user_msg ($current)"
        git push && echo "✅ Pushed to GitHub!" || echo "❌ Push failed!"
      else
        echo "⏭️  Skipping commit (no message provided)"
      fi

      # Back to where you were
      popd

      # Notify all OK!
      notify-send -e "NixOS Boot Build Successful!" "New configuration will load on next boot" --icon=emblem-default
    '')
  ];
}
