# Root helper for serpantinum's system monitor panel.
#
# Three of the panel's actions write to kernel interfaces no unprivileged user
# can touch: dropping the page cache, forcing memory reclaim, and raising a
# process's priority (a user may only ever *lower* it). Without this the buttons
# would appear to work and change nothing.
#
# The helper is a fixed store path with a closed set of operations and its
# arguments validated before use, and the polkit rule grants it to wheel only.
# That is deliberately narrower than making the whole script setuid: `pkexec` on
# an arbitrary shell script would be a root shell for anyone who can write the
# script's path.
{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.serpantinum.sysmon;

  helper = pkgs.writeShellApplication {
    name = "serpantinum-sysmon-helper";
    runtimeInputs = [pkgs.procps pkgs.coreutils];
    text = ''
      # Called through pkexec, so this runs as root with an attacker-controlled
      # argv. Every operation is matched exactly and every numeric argument is
      # re-validated here rather than trusted from the caller.
      op=''${1:-}

      case "$op" in
        drop-caches)
          # 3 = page cache + dentries + inodes. Purely a cache drop; no data loss.
          sync
          echo 3 > /proc/sys/vm/drop_caches
          ;;

        compact-ram)
          # Push idle anonymous pages out to swap (zram where it is configured),
          # which is what actually lowers "used" memory — dropping caches does
          # not. memory.reclaim is the cgroup-v2 interface for this; scoping it
          # to user.slice leaves system services alone. Falls back to the
          # compaction knob on a kernel without it.
          if [ -w /sys/fs/cgroup/user.slice/memory.reclaim ]; then
            # Best-effort: the kernel returns EAGAIN when it cannot reclaim the
            # full amount, which is not an error worth failing the button over.
            echo "${toString cfg.reclaimBytes}" > /sys/fs/cgroup/user.slice/memory.reclaim || true
          elif [ -w /proc/sys/vm/compact_memory ]; then
            echo 1 > /proc/sys/vm/compact_memory
          else
            echo "no reclaim interface available" >&2
            exit 1
          fi
          ;;

        renice)
          nice=''${2:-}
          pid=''${3:-}
          # Reject anything that is not a plain integer before it reaches renice.
          case "$nice" in
            -[0-9] | -1[0-9] | -20 | [0-9] | 1[0-9]) : ;;
            *)
              echo "nice value out of range: $nice" >&2
              exit 1
              ;;
          esac
          case "$pid" in
            "" | *[!0-9]*)
              echo "not a pid: $pid" >&2
              exit 1
              ;;
          esac
          renice -n "$nice" -p "$pid" > /dev/null
          ;;

        *)
          echo "unknown operation: $op" >&2
          exit 1
          ;;
      esac
    '';
  };

  helperPath = "${helper}/bin/serpantinum-sysmon-helper";
in {
  options.serpantinum.sysmon = {
    enable = lib.mkEnableOption "root helper for serpantinum's system monitor panel";

    reclaimBytes = lib.mkOption {
      type = lib.types.int;
      default = 1073741824; # 1 GiB
      description = ''
        How much memory the "Clean RAM" button asks the kernel to reclaim from
        user.slice in one press. The kernel reclaims what it can and reports
        EAGAIN for the rest, so an oversized value is a ceiling, not a demand.
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [helper];

    # Matched on both paths the caller can end up with: pkexec is handed the
    # profile symlink resolved from PATH, but canonicalises it before polkit
    # sees it on some versions.
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (action.id == "org.freedesktop.policykit.exec" &&
            (action.lookup("program") == "${helperPath}" ||
             action.lookup("program") == "/run/current-system/sw/bin/serpantinum-sysmon-helper") &&
            subject.isInGroup("wheel")) {
          return polkit.Result.YES;
        }
      });
    '';
  };
}
