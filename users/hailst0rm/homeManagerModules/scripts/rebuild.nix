{
  pkgs,
  config,
  lib,
  ...
}: let
  hasDesktop = config.importConfig.hyprland.enable;
  buildDir = "/home/${config.username}/.nixos";

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
        echo -e "  ''${GREEN}--debug''${RESET}               Show timing info for each step"
        echo -e "  ''${GREEN}--no-auth''${RESET}             Skip GitHub auth; fetch-only with local file protection"
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
        echo -e "  ''${CYAN}${name} --no-auth''${RESET}                    # Skip GitHub auth (no push/pull)"
        echo -e "  ''${CYAN}${name} --nh-flags \"--update\"''${RESET}        # Update flake.lock first"
        echo -e "  ''${CYAN}${name} --nh-flags \"--max-jobs 4\"''${RESET}    # Limit to 4 parallel jobs"
      }

      # Debug helper - prints timing only when --debug is set
      debug_timer() {
        if [ "$use_debug" = true ]; then
          echo -e "''${BLUE}  ⏱ $1: $((SECONDS-STEP_START))s''${RESET}"
        fi
      }

      # Parse arguments
      use_legacy=false
      use_debug=false
      use_no_auth=false
      nh_flags=""
      while [[ $# -gt 0 ]]; do
        case "$1" in
          --debug)
            use_debug=true
            shift
            ;;
          --legacy)
            use_legacy=true
            shift
            ;;
          --no-auth)
            use_no_auth=true
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

      # cd to config dir
      NIXOS_DIR="${config.nixosDir}"
      if [ ! -d "$NIXOS_DIR/hosts" ]; then
        echo -e "''${RED}''${BOLD}❌ Config dir ($NIXOS_DIR) not found or missing hosts/ directory!''${RESET}"
        exit 1
      fi
      pushd "$NIXOS_DIR" >/dev/null || { echo -e "''${RED}''${BOLD}❌ Failed to change directory to config!''${RESET}" && exit 1; }

      # Check if current build matches latest config
      BUILT_REV=$(nixos-version --json 2>/dev/null | ${pkgs.jq}/bin/jq -r '.configurationRevision // empty' 2>/dev/null)
      CURRENT_REV=$(git rev-parse HEAD 2>/dev/null)
      if [ -n "$BUILT_REV" ] && [ -n "$CURRENT_REV" ]; then
        # Strip -dirty suffix for comparison
        BUILT_REV_CLEAN="''${BUILT_REV%-dirty}"
        PARENT_REV=$(git rev-parse HEAD~1 2>/dev/null)
        if [ "$BUILT_REV_CLEAN" = "$CURRENT_REV" ]; then
          echo -e "''${GREEN}✅ Current build matches latest config commit.''${RESET}"
        elif [ "$BUILT_REV_CLEAN" = "$PARENT_REV" ]; then
          # Built rev is parent of HEAD — the extra commit is the post-build commit from nix-switch
          echo -e "''${GREEN}✅ Current build matches latest config commit.''${RESET}"
        else
          COMMITS_SINCE=$(git rev-list "$BUILT_REV_CLEAN"..HEAD --count 2>/dev/null || echo "?")
          # Subtract 1 for the post-build commit if it exists
          if [ "$COMMITS_SINCE" -gt 1 ] 2>/dev/null; then
            COMMITS_SINCE=$((COMMITS_SINCE - 1))
          fi
          echo -e "''${YELLOW}''${BOLD}⚠️  Build is $COMMITS_SINCE commit(s) behind config.''${RESET}"
        fi
      fi

      # GitHub connectivity / remote sync
      if [ "$use_no_auth" = true ]; then
        # Test HTTPS connectivity (no SSH key needed)
        echo -e "''${CYAN}🌐 Testing GitHub connectivity (HTTPS)...''${RESET}"
        notify-send -e "${notifyName}" "Testing GitHub connectivity..." --icon=network-wireless 2>/dev/null

        if ! timeout 5 git ls-remote https://github.com/hailst0rm1/nixos.git HEAD &>/dev/null; then
          echo -e "''${RED}''${BOLD}❌ Cannot reach GitHub. Check your internet connection.''${RESET}"
          notify-send -e "${notifyName} Failed!" "Cannot reach GitHub. Check your internet connection." --icon=dialog-error --urgency=critical 2>/dev/null
          popd >/dev/null || { echo -e "''${RED}''${BOLD}❌ Failed to return to original directory!''${RESET}" && exit 1; }

          exit 1
        fi
        echo -e "''${GREEN}✅ GitHub connectivity OK''${RESET}"
      else
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
      fi

      # --no-auth: fetch remote via HTTPS and rebase local branch on top
      if [ "$use_no_auth" = true ]; then
        echo -e "''${BLUE}📡 Fetching remote changes (no-auth, HTTPS)...''${RESET}"
        STEP_START=$SECONDS
        HTTPS_URL="https://github.com/hailst0rm1/nixos.git"
        if timeout 10 git fetch "$HTTPS_URL" master:refs/remotes/origin/master --quiet 2>/dev/null; then
          debug_timer "git fetch (no-auth)"

          STEP_START=$SECONDS
          LOCAL=$(git rev-parse HEAD)
          REMOTE=$(git rev-parse origin/master 2>/dev/null || echo "")
          debug_timer "rev-parse (no-auth)"

          if [ -n "$REMOTE" ] && [ "$LOCAL" != "$REMOTE" ]; then
            BEHIND=$(git rev-list HEAD..origin/master --count 2>/dev/null || echo "0")
            if [ "$BEHIND" -gt 0 ] 2>/dev/null; then
              echo -e "''${YELLOW}''${BOLD}⚠️  Warning: Local config is $BEHIND commit(s) behind remote.''${RESET}"
              notify-send -e "NixOS Config Behind Remote" "Your config is $BEHIND commit(s) behind. Rebase before rebuilding?" --icon=dialog-warning 2>/dev/null
              read -p "Rebase on remote changes before rebuilding? (y/N): " -n 1 -r
              echo
              if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo -e "''${CYAN}⬇️  Rebasing on remote changes...''${RESET}"
                if git rebase origin/master; then
                  echo -e "''${GREEN}✅ Rebased successfully.''${RESET}"
                else
                  echo -e "''${RED}''${BOLD}❌ Rebase failed. Resolve conflicts then run: git rebase --continue''${RESET}"
                  notify-send -e "${notifyName} Failed!" "Rebase failed — resolve conflicts manually" --icon=dialog-error --urgency=critical 2>/dev/null
                  popd >/dev/null 2>/dev/null
                  exit 1
                fi
              fi
            fi
          fi
        else
          debug_timer "git fetch (no-auth, failed)"
          echo -e "''${YELLOW}⚠️  Fetch failed (no connectivity). Continuing with local state.''${RESET}"
        fi
      fi

      ${lib.optionalString checkRemote ''
        if [ "$use_no_auth" != true ]; then
          # Fetch remote changes to check if we're behind
          echo -e "''${BLUE}📡 Fetching remote changes...''${RESET}"
          STEP_START=$SECONDS
          if ! git fetch origin master --quiet 2>/dev/null; then
            echo -e "''${YELLOW}⚠️  Fetch failed (''${SECONDS-STEP_START}s), pruning stale refs and retrying...''${RESET}"
            git remote prune origin
            git fetch origin master --quiet || {
              echo -e "''${RED}❌ Failed to fetch remote changes. Continuing with local state.''${RESET}"
            }
          fi
          debug_timer "git fetch"

          STEP_START=$SECONDS
          LOCAL=$(git rev-parse HEAD)
          REMOTE=$(git rev-parse origin/master)
          debug_timer "rev-parse"

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
        fi
      ''}

      # Autoformat the nix files with alejandra (on NAS dir so formatting is committed)
      echo -e "''${MAGENTA}🎨 Formatting Nix files...''${RESET}"
      STEP_START=$SECONDS
      alejandra . &>/dev/null \
        || ( alejandra . ; echo -e "''${RED}''${BOLD}❌ Formatting failed!''${RESET}" && notify-send -e "Formatting Failed!" --icon=dialog-error 2>/dev/null && exit 1)
      debug_timer "alejandra"

      ${lib.optionalString (!hasDesktop) ''
        # Server: rsync NAS config to local disk for faster builds
        echo -e "''${CYAN}📋 Syncing config to local disk for faster build...''${RESET}"
        STEP_START=$SECONDS
        mkdir -p "${buildDir}"
        ${pkgs.rsync}/bin/rsync -a --delete \
          --exclude='result' \
          --exclude='.direnv' \
          "$NIXOS_DIR/" "${buildDir}/"
        debug_timer "rsync to local"
        BUILD_FROM="${buildDir}"
        cd "$BUILD_FROM"
      ''}
      ${lib.optionalString hasDesktop ''
        BUILD_FROM="$NIXOS_DIR"
      ''}

      # Show changes
      ${
        if checkRemote
        then ''
          # Check for changes
          STEP_START=$SECONDS
          if git diff HEAD --quiet; then
              echo -e "''${YELLOW}⚠️  Warning: No changes detected in config.''${RESET}"
          fi
          debug_timer "git diff --quiet"

          echo -e "''${CYAN}''${BOLD}📝 Changes to be applied:''${RESET}"
          STEP_START=$SECONDS
          git diff HEAD -U0
          debug_timer "git diff -U0"
          STEP_START=$SECONDS
          git add -N .
          debug_timer "git add -N"
        ''
        else ''
          # Show the changes if any (compare against local HEAD, not remote)
          STEP_START=$SECONDS
          if ! git diff HEAD --quiet; then
            debug_timer "git diff --quiet"
            echo -e "''${CYAN}''${BOLD}📝 Changes detected:''${RESET}"
            STEP_START=$SECONDS
            git diff HEAD -U0
            debug_timer "git diff -U0"
            git add -N .
          else
            debug_timer "git diff --quiet"
            echo -e "''${BLUE}ℹ️  No changes detected, testing current configuration...''${RESET}"
          fi
        ''
      }

      # Rebuild and exit on failure
      echo ""
      echo -e "''${GREEN}''${BOLD}🔨 ${buildingMsg}...''${RESET}"
      notify-send -e "${notifyName}" "${buildingMsg} for ${config.hostname}..." --icon=system-software-update 2>/dev/null

      # Ensure nh uses the resolved directory
      export NH_FLAKE="$BUILD_FROM"

      if [ "$use_legacy" = true ]; then
        echo -e "''${YELLOW}📦 Using legacy nixos-rebuild...''${RESET}"
        sudo nixos-rebuild ${action} --flake "$BUILD_FROM#${config.hostname}" || {
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
        if [ "$use_no_auth" = true ]; then
          echo -e "''${YELLOW}🔓 --no-auth mode: skipping commit/push''${RESET}"
        else
          ${lib.optionalString (!hasDesktop) ''
          # Server: sync changes (formatting etc.) back to NAS for git commit
          ${pkgs.rsync}/bin/rsync -a --delete \
            --exclude='result' \
            --exclude='.direnv' \
            "${buildDir}/" "$NIXOS_DIR/"
          cd "$NIXOS_DIR"
        ''}

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
