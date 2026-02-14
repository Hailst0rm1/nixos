{
  pkgs,
  config,
  lib,
  ...
}: let
  # Helper function to generate rebuild scripts
  mkRebuildScript = {
    name,
    action,
    checkRemote ? false,
    promptCommit ? false,
    notifyName,
    buildingMsg,
    successMsg,
  }:
    pkgs.writeShellScriptBin name ''
      #!/usr/bin/env sh

      # Colors
      RED='\033[0;31m'
      GREEN='\033[0;32m'
      YELLOW='\033[0;33m'
      BLUE='\033[0;34m'
      MAGENTA='\033[0;35m'
      CYAN='\033[0;36m'
      BOLD='\033[1m'
      RESET='\033[0m'

      show_help() {
        echo -e "''${CYAN}''${BOLD}Usage:''${RESET} ${name} [OPTIONS]"
        echo ""
        echo -e "''${BOLD}Options:''${RESET}"
        echo -e "  ''${GREEN}--legacy''${RESET}              Use nixos-rebuild instead of nh"
        echo -e "  ''${GREEN}--nh-flags ''${YELLOW}\"<args>\"''${RESET}   Pass extra arguments to nh"
        echo -e "  ''${GREEN}-h, --help''${RESET}            Show this help message"
        echo ""
        echo -e "''${BOLD}Useful --nh-flags options:''${RESET}"
        echo -e "  ''${MAGENTA}--update''${RESET}              Update flake.lock before building"
        echo -e "  ''${MAGENTA}--update-input ''${YELLOW}<name>''${RESET} Update a specific flake input"
        echo -e "  ''${MAGENTA}--max-jobs ''${YELLOW}<n>''${RESET}        Number of concurrent jobs Nix should run"
        echo -e "  ''${MAGENTA}--cores ''${YELLOW}<n>''${RESET}           Number of cores Nix should utilize"
        echo -e "  ''${MAGENTA}--show-trace''${RESET}          Display tracebacks on errors"
        echo ""
        echo -e "''${BOLD}Examples:''${RESET}"
        echo -e "  ''${CYAN}${name}''${RESET}                              # Normal rebuild with nh"
        echo -e "  ''${CYAN}${name} --legacy''${RESET}                     # Use nixos-rebuild"
        echo -e "  ''${CYAN}${name} --nh-flags \"--update\"''${RESET}        # Update flake.lock first"
        echo -e "  ''${CYAN}${name} --nh-flags \"--max-jobs 4\"''${RESET}    # Limit to 4 parallel jobs"
      }

      # Parse arguments
      use_legacy=false
      nh_flags=""
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --legacy)
            use_legacy=true
            shift
            ;;
          --nh-flags)
            nh_flags="$2"
            shift 2
            ;;
          -h|--help)
            show_help
            exit 0
            ;;
          *)
            echo -e "''${RED}Unknown option: $1''${RESET}"
            show_help
            exit 1
            ;;
        esac
      done

      # cd to your config dir
      pushd ${config.nixosDir} >/dev/null || { echo -e "''${RED}''${BOLD}❌ Failed to change directory to config!''${RESET}" && exit 1; }

      # Test GitHub connectivity
      echo -e "''${CYAN}🌐 Testing GitHub connectivity...''${RESET}"
      notify-send -e "${notifyName}" "Testing GitHub connectivity..." --icon=network-wireless 2>/dev/null

      if ! timeout 5 git ls-remote git@github.com:hailst0rm1/nixos.git HEAD &>/dev/null; then
        echo -e "''${RED}''${BOLD}❌ Cannot reach GitHub. Check your internet connection.''${RESET}"
        notify-send -e "${notifyName} Failed!" "Cannot reach GitHub. Check your internet connection." --icon=dialog-error --urgency=critical 2>/dev/null
        popd >/dev/null || { echo -e "''${RED}''${BOLD}❌ Failed to return to original directory!''${RESET}" && exit 1; }

        exit 1
      fi
      echo -e "''${GREEN}✅ GitHub connectivity OK''${RESET}"

      ${lib.optionalString checkRemote ''
        # Fetch remote changes to check if we're behind
        echo -e "''${BLUE}📡 Fetching remote changes...''${RESET}"
        git fetch origin master --quiet
        LOCAL=$(git rev-parse HEAD)
        REMOTE=$(git rev-parse origin/master)

        if [ "$LOCAL" != "$REMOTE" ]; then
          BEHIND=$(git rev-list HEAD..origin/master --count)
          echo -e "''${YELLOW}''${BOLD}⚠️  Warning: Local config is $BEHIND commit(s) behind remote.''${RESET}"
          notify-send -e "NixOS Config Behind Remote" "Your config is $BEHIND commit(s) behind. Pull before rebuilding?" --icon=dialog-warning 2>/dev/null
          read -p "Pull remote changes before rebuilding? (y/N): " -n 1 -r
          echo
          if [[ $REPLY =~ ^[Yy]$ ]]; then
            echo -e "''${CYAN}⬇️  Pulling remote changes...''${RESET}"
            git pull origin master
          fi
        fi
      ''}

      # Autoformat the nix files with alejandra
      echo -e "''${MAGENTA}🎨 Formatting Nix files...''${RESET}"
      alejandra . &>/dev/null \
        || ( alejandra . ; echo -e "''${RED}''${BOLD}❌ Formatting failed!''${RESET}" && notify-send -e "Formatting Failed!" --icon=dialog-error 2>/dev/null && exit 1)

      # Show changes
      ${
        if checkRemote
        then ''
          # Check for changes
          if git diff HEAD --quiet; then
              echo -e "''${YELLOW}⚠️  Warning: No changes detected in config.''${RESET}"
          fi

          echo -e "''${CYAN}''${BOLD}📝 Changes to be applied:''${RESET}"
          git diff HEAD -U0
          git add -N .
        ''
        else ''
          # Show the changes if any (compare against local HEAD, not remote)
          if ! git diff HEAD --quiet; then
            echo -e "''${CYAN}''${BOLD}📝 Changes detected:''${RESET}"
            git diff HEAD -U0
            git add -N .
          else
            echo -e "''${BLUE}ℹ️  No changes detected, testing current configuration...''${RESET}"
          fi
        ''
      }

      # Rebuild and exit on failure
      echo ""
      echo -e "''${GREEN}''${BOLD}🔨 ${buildingMsg}...''${RESET}"
      notify-send -e "${notifyName}" "${buildingMsg} for ${config.hostname}..." --icon=system-software-update 2>/dev/null

      if [ "$use_legacy" = true ]; then
        echo -e "''${YELLOW}📦 Using legacy nixos-rebuild...''${RESET}"
        sudo nixos-rebuild ${action} --flake ./#${config.hostname} || {
          echo ""
          echo -e "''${RED}''${BOLD}❌ NixOS rebuild failed!''${RESET}"
          notify-send -e "${notifyName} Failed!" "Build failed for ${config.hostname}" --icon=dialog-error --urgency=critical 2>/dev/null
          popd >/dev/null || { echo -e "''${RED}''${BOLD}❌ Failed to return to original directory!''${RESET}" && exit 1; }
          exit 1
        }
      else
        nh os ${action} --diff always $nh_flags || {
          echo ""
          echo -e "''${RED}''${BOLD}❌ NixOS rebuild failed!''${RESET}"
          notify-send -e "${notifyName} Failed!" "Build failed for ${config.hostname}" --icon=dialog-error --urgency=critical 2>/dev/null
          popd >/dev/null || { echo -e "''${RED}''${BOLD}❌ Failed to return to original directory!''${RESET}" && exit 1; }
          exit 1
        }
      fi

      ${lib.optionalString promptCommit ''
        # Get current generation metadata
        current=$(nixos-rebuild list-generations | awk '$NF == "True" {print "Generation " $1 " built on " $2}')
      ''}

      echo ""
      echo -e "''${GREEN}''${BOLD}✅ Build Complete!''${RESET}"

      ${lib.optionalString promptCommit ''
        # Prompt user for an optional commit message
        echo -e "''${BOLD}''${CYAN}📄 Modified files:''${RESET}"
        if git diff --name-status | sed -e 's/^M/Modified: /' -e 's/^A/Added: /' -e 's/^D/Deleted: /'; then
          :
        else
          echo -e "''${YELLOW}⚠️  No modified files detected.''${RESET}"
        fi
        echo ""
        echo -e "''${CYAN}💾 Enter a commit message to save changes (leave empty to skip):''${RESET}"
        read -rp "➜ " user_msg

        # Only commit and push if message is not empty
        if [ -n "$user_msg" ]; then
          echo -e "''${BLUE}📤 Committing and pushing changes...''${RESET}"
          notify-send -e "NixOS Config" "Pushing changes to GitHub..." --icon=emblem-synchronizing 2>/dev/null
          git add .
          git commit -am "${config.hostname}: $user_msg ($current)"
          git push && echo -e "''${GREEN}''${BOLD}✅ Pushed to GitHub!''${RESET}" || echo -e "''${RED}''${BOLD}❌ Push failed!''${RESET}"
        else
          echo -e "''${YELLOW}⏭️  Skipping commit (no message provided)''${RESET}"
        fi
      ''}

      # Back to where you were
      popd >/dev/null || { echo -e "''${RED}''${BOLD}❌ Failed to return to original directory!''${RESET}" && exit 1; }

      # Notify all OK!
      notify-send -e "${notifyName} Successful!" "${successMsg}" --icon=emblem-default 2>/dev/null
    '';
in {
  # Shell scripts to handle rebuilds in a more convenient way
  home.packages = with pkgs; [
    # Prerequisites
    libnotify
    alejandra

    # Switch - rebuild and switch to new configuration
    (mkRebuildScript {
      name = "nix-switch";
      action = "switch";
      checkRemote = true;
      promptCommit = true;
      notifyName = "NixOS Rebuild";
      buildingMsg = "Building and switching";
      successMsg = "System switched to new generation";
    })

    # Boot - build and add to bootloader but don't switch
    (mkRebuildScript {
      name = "nix-boot";
      action = "boot";
      checkRemote = true;
      promptCommit = true;
      notifyName = "NixOS Boot Build";
      buildingMsg = "Building boot configuration";
      successMsg = "New configuration will load on next boot";
    })

    # Test - build and activate without adding to bootloader
    (mkRebuildScript {
      name = "nix-test";
      action = "test";
      checkRemote = false;
      promptCommit = false;
      notifyName = "NixOS Test Build";
      buildingMsg = "Building test configuration";
      successMsg = "Test build completed successfully for ${config.hostname}";
    })
  ];
}
