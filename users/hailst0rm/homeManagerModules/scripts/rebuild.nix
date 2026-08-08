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
        echo -e "  ''${GREEN}--no-diff''${RESET}             Skip git diff display"
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
      use_no_diff=false
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
          --no-diff)
            use_no_diff=true
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

      # GitHub connectivity — SSH preferred; fall back to HTTPS (fetch-only,
      # no commit/push), then to fully offline. Never blocks the rebuild.
      echo -e "''${CYAN}🌐 Testing GitHub connectivity...''${RESET}"
      notify-send -e "${notifyName}" "Testing GitHub connectivity..." --icon=network-wireless 2>/dev/null
      if [ "$use_no_auth" != true ] && timeout 5 git ls-remote git@github.com:hailst0rm1/nixos.git HEAD &>/dev/null; then
        echo -e "''${GREEN}✅ GitHub connectivity OK (SSH)''${RESET}"
      elif timeout 5 git ls-remote https://github.com/hailst0rm1/nixos.git HEAD &>/dev/null; then
        if [ "$use_no_auth" = true ]; then
          echo -e "''${GREEN}✅ GitHub connectivity OK (HTTPS)''${RESET}"
        else
          echo -e "''${YELLOW}⚠️  SSH auth unavailable — falling back to no-auth mode (fetch-only, no commit/push).''${RESET}"
          use_no_auth=true
        fi
      else
        echo -e "''${YELLOW}⚠️  GitHub unreachable — continuing offline with local state (no commit/push).''${RESET}"
        use_no_auth=true
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
                  # Auto-resolve known per-host files by keeping local version
                  conflict_files=$(git diff --name-only --diff-filter=U 2>/dev/null)
                  auto_resolved=true
                  for f in $conflict_files; do
                    case "$f" in
                      pkgs/claudecodeui/package.nix)
                        echo -e "''${YELLOW}⚠️  Auto-resolving $f (keeping local version)''${RESET}"
                        git checkout --ours "$f"
                        git add "$f"
                        ;;
                      *)
                        auto_resolved=false
                        ;;
                    esac
                  done
                  if [ "$auto_resolved" = true ] && [ -n "$conflict_files" ]; then
                    GIT_EDITOR=true git rebase --continue || {
                      echo -e "''${RED}''${BOLD}❌ Rebase failed. Resolve conflicts then run: git rebase --continue''${RESET}"
                      notify-send -e "${notifyName} Failed!" "Rebase failed — resolve conflicts manually" --icon=dialog-error --urgency=critical 2>/dev/null
                      popd >/dev/null 2>/dev/null
                      exit 1
                    }
                  elif [ "$auto_resolved" = false ]; then
                    echo -e "''${RED}''${BOLD}❌ Rebase failed. Resolve conflicts then run: git rebase --continue''${RESET}"
                    notify-send -e "${notifyName} Failed!" "Rebase failed — resolve conflicts manually" --icon=dialog-error --urgency=critical 2>/dev/null
                    popd >/dev/null 2>/dev/null
                    exit 1
                  fi
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
            echo -e "''${YELLOW}⚠️  Fetch failed ($((SECONDS-STEP_START))s), pruning stale refs and retrying...''${RESET}"
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
              if ! git pull --rebase origin master; then
                echo -e "''${RED}''${BOLD}❌ Pull failed. Resolve conflicts, run: git rebase --continue (or --abort), then rerun ${name}.''${RESET}"
                notify-send -e "${notifyName} Failed!" "Pull failed — resolve conflicts manually" --icon=dialog-error --urgency=critical 2>/dev/null
                popd >/dev/null 2>/dev/null
                exit 1
              fi
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

      # Register new files with git BEFORE diffing/building — flakes ignore
      # untracked files when copying the tree to the store, and git diff HEAD
      # can't see them either. -N records intent without staging content.
      STEP_START=$SECONDS
      git add -N .
      debug_timer "git add -N"

      # Show changes (skip with --no-diff for auto-retry)
      if [ "$use_no_diff" != true ]; then
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
          else
            debug_timer "git diff --quiet"
            echo -e "''${BLUE}ℹ️  No changes detected, testing current configuration...''${RESET}"
          fi
        ''
      }
      fi

      # Rebuild, auto-resolving fixed-output hash mismatches in a loop.
      #
      # nh drives nix via nom (--log-format internal-json), which bakes ANSI
      # color codes into the error text, so we match the bare SRI hash rather
      # than $NF. On a mismatch we patch the hash in $BUILD_FROM — the tree nix
      # actually builds from (buildDir on the server, NIXOS_DIR on desktop) — and
      # loop, so a cascade of stale FODs resolves in one run. On the server the
      # post-build rsync propagates the fix from buildDir back to the NAS for git.
      echo ""
      echo -e "''${GREEN}''${BOLD}🔨 ${buildingMsg}...''${RESET}"
      notify-send -e "${notifyName}" "${buildingMsg} for ${config.hostname}..." --icon=system-software-update 2>/dev/null

      # Ensure nh uses the resolved directory
      export NH_FLAKE="$BUILD_FROM"

      REBUILD_LOG=$(mktemp)
      build_ok=0
      hash_retries=0
      max_hash_retries=8
      while :; do
        rebuild_failed=false
        set -o pipefail
        if [ "$use_legacy" = true ]; then
          echo -e "''${YELLOW}📦 Using legacy nixos-rebuild...''${RESET}"
          sudo nixos-rebuild ${action} --flake "$BUILD_FROM#${config.hostname}" 2>&1 | tee "$REBUILD_LOG" || rebuild_failed=true
        else
          nh os ${action} --diff always $nh_flags 2>&1 | tee "$REBUILD_LOG" || rebuild_failed=true
        fi
        set +o pipefail

        if [ "$rebuild_failed" != true ]; then
          build_ok=1
          break
        fi

        # Auto-resolve a fixed-output hash mismatch, then loop to rebuild.
        if [ "$hash_retries" -lt "$max_hash_retries" ] && grep -q "hash mismatch in fixed-output derivation" "$REBUILD_LOG"; then
          # Bare SRI hashes (ANSI-safe): what the file claims vs what nix got.
          OLD_HASH=$(grep "specified:" "$REBUILD_LOG" | head -1 | grep -oE 'sha(1|256|512)-[A-Za-z0-9+/]+=*' | head -1)
          NEW_HASH=$(grep "got:" "$REBUILD_LOG" | head -1 | grep -oE 'sha(1|256|512)-[A-Za-z0-9+/]+=*' | head -1)
          # Name of the failing FOD, e.g. "21st-registry.md" or "cli-1.6.0.tgz".
          DRV_NAME=$(grep "hash mismatch in fixed-output derivation" "$REBUILD_LOG" | head -1 \
            | grep -oE '/nix/store/[a-z0-9]{32}-[A-Za-z0-9._+-]+\.drv' | head -1 \
            | sed -e 's|.*/[a-z0-9]\{32\}-||' -e 's|\.drv$||')

          if [ -n "$OLD_HASH" ] && [ -n "$NEW_HASH" ]; then
            HASH_FILE=$(grep -rlF "$OLD_HASH" "$BUILD_FROM" --include="*.nix" | head -1)
            if [ -n "$HASH_FILE" ]; then
              echo ""
              echo -e "''${YELLOW}''${BOLD}🔧 Hash mismatch detected! Auto-fixing...''${RESET}"
              echo -e "  ''${CYAN}File:''${RESET} $HASH_FILE"
              echo -e "  ''${CYAN}FOD:''${RESET}  $DRV_NAME"
              echo -e "  ''${RED}Old:''${RESET}  $OLD_HASH"
              echo -e "  ''${GREEN}New:''${RESET}  $NEW_HASH"

              if [ "$(grep -cF "$OLD_HASH" "$HASH_FILE")" -le 1 ]; then
                # Unique in the file — plain replace ('|' delim keeps the hash's '/' safe).
                sed -i "s|$OLD_HASH|$NEW_HASH|" "$HASH_FILE"
              else
                # Several sources share this hash (e.g. a duplicated placeholder).
                # Replace only the fetch whose URL basename matches the failing FOD
                # name (Nix interpolations treated as wildcards) so a sibling isn't clobbered.
                fixed=$(mktemp)
                awk -v name="$DRV_NAME" -v newh="$NEW_HASH" '
                  {
                    if (match($0, /url = "[^"]*"/)) {
                      u = substr($0, RSTART, RLENGTH); sub(/^url = "/, "", u); sub(/"$/, "", u)
                      sub(/.*\//, "", u); gsub(/\$\{[^}]*\}/, ".*", u)
                      armed = (name ~ ("^" u "$"))
                    }
                    if (armed && $0 ~ /hash = "sha[0-9]+-/) { sub(/sha[0-9]+-[A-Za-z0-9+\/]+=*/, newh); armed = 0 }
                    print
                  }
                ' "$HASH_FILE" > "$fixed"
                if cmp -s "$fixed" "$HASH_FILE"; then
                  rm -f "$fixed"
                  echo -e "''${RED}''${BOLD}❌ '$DRV_NAME' shares its hash with another source and couldn't be matched by URL — fix manually.''${RESET}"
                  break
                fi
                mv "$fixed" "$HASH_FILE"
              fi

              echo -e "''${GREEN}✅ Hash updated. Rebuilding...''${RESET}"
              hash_retries=$((hash_retries + 1))
              : > "$REBUILD_LOG"
              continue
            fi
          fi
        fi

        # Not auto-fixable (or retries exhausted) — real failure.
        break
      done

      ${lib.optionalString (!hasDesktop) ''
        # Server: sync build-dir changes (formatting, hash auto-fixes) back to
        # the NAS even for nix-test or a failed build — otherwise the next
        # NAS→buildDir rsync --delete wipes them.
        ${pkgs.rsync}/bin/rsync -a --delete \
          --exclude='result' \
          --exclude='.direnv' \
          "${buildDir}/" "$NIXOS_DIR/"
        cd "$NIXOS_DIR"
      ''}

      if [ "$build_ok" != 1 ]; then
        echo ""
        echo -e "''${RED}''${BOLD}❌ NixOS rebuild failed!''${RESET}"
        notify-send -e "${notifyName} Failed!" "Build failed for ${config.hostname}" --icon=dialog-error --urgency=critical 2>/dev/null
        rm -f "$REBUILD_LOG"
        popd >/dev/null || { echo -e "''${RED}''${BOLD}❌ Failed to return to original directory!''${RESET}" && exit 1; }
        exit 1
      fi
      rm -f "$REBUILD_LOG"

      ${lib.optionalString promptCommit ''
        # Newly built generation: the system profile points at it after both
        # switch and boot (list-generations' "current" flag misses boot builds)
        current="Generation $(readlink /nix/var/nix/profiles/system | grep -oE '[0-9]+') built on $(date +%Y-%m-%d)"
      ''}

      echo ""
      echo -e "''${GREEN}''${BOLD}✅ Build Complete!''${RESET}"

      ${lib.optionalString promptCommit ''
        if [ "$use_no_auth" = true ]; then
          echo -e "''${YELLOW}🔓 No SSH auth — skipping commit/push''${RESET}"
        else
          # Skip the commit prompt entirely when there is nothing to commit
          if [ -z "$(git status --porcelain)" ]; then
            echo -e "''${BLUE}ℹ️  Working tree clean — nothing to commit.''${RESET}"
          else
            # Prompt user for an optional commit message
            echo -e "''${BOLD}''${CYAN}📄 Modified files:''${RESET}"
            git status --porcelain | sed -e 's/^ *M */Modified: /' -e 's/^A */Added: /' -e 's/^?? */Added: /' -e 's/^ *D */Deleted: /'
            echo ""
            echo -e "''${CYAN}💾 Enter a commit message to save changes (leave empty to skip):''${RESET}"
            read -rp "➜ " user_msg

            # Only commit and push if message is not empty
            if [ -n "$user_msg" ]; then
              echo -e "''${BLUE}📤 Committing and pushing changes...''${RESET}"
              notify-send -e "NixOS Config" "Pushing changes to GitHub..." --icon=emblem-synchronizing 2>/dev/null
              git add .
              git commit -m "${config.hostname}: $user_msg ($current)"
              if git push; then
                echo -e "''${GREEN}''${BOLD}✅ Pushed to GitHub!''${RESET}"
              else
                # Remote moved since the pre-build fetch (multi-host race) —
                # rebase our commit on top and retry once.
                echo -e "''${YELLOW}⚠️  Push rejected — rebasing on remote and retrying...''${RESET}"
                if git pull --rebase origin master && git push; then
                  echo -e "''${GREEN}''${BOLD}✅ Pushed to GitHub!''${RESET}"
                else
                  echo -e "''${RED}''${BOLD}❌ Push failed! Finish the rebase (git rebase --continue or --abort), then git push manually.''${RESET}"
                  notify-send -e "${notifyName} Push Failed!" "Rebase/push needs manual resolution" --icon=dialog-error --urgency=critical 2>/dev/null
                fi
              fi
            else
              echo -e "''${YELLOW}⏭️  Skipping commit (no message provided)''${RESET}"
            fi
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
