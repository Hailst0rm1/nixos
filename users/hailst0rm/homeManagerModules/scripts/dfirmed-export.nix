{
  pkgs,
  lib,
  config,
  ...
}: let
  # Copies the private Dfirmed repos onto a USB stick as git bundles, for a
  # machine with no SSH key for them. A bundle is one plain file (safe on
  # vfat/exFAT) carrying every branch and tag; restore with
  # `git clone <repo>.bundle`.
  dfirmed-export = pkgs.writeShellApplication {
    name = "dfirmed-export";
    runtimeInputs = with pkgs; [gh git fzf util-linux udisks jq coreutils];
    text = ''
      org=Dfirmed

      # Picks the Dfirmed account for this call only, whichever gh account is active.
      GH_TOKEN=$(gh auth token --user K-Dfirmed)
      export GH_TOKEN

      mapfile -t repos < <(gh repo list "$org" --limit 1000 --json name,diskUsage \
          -q '.[] | "\(.name)\t\(.diskUsage / 1024 | floor) MB"' \
        | fzf --multi --bind 'start:select-all' --delimiter '\t' \
            --header 'TAB toggles, ENTER exports' --prompt 'repos> ' \
        | cut -f1)
      [ ''${#repos[@]} -gt 0 ] || { echo "No repos selected."; exit 1; }

      # Partitions on USB disks that hold a filesystem we can write to.
      dev=$(lsblk -J -p -o NAME,TRAN,FSTYPE,SIZE,LABEL,MOUNTPOINT \
          | jq -r '.blockdevices[] | select(.tran == "usb") | .children[]?
              | select(.fstype != null and .fstype != "crypto_LUKS")
              | [.name, .size, (.label // "-"), .fstype, (.mountpoint // "(not mounted)")] | @tsv' \
        | fzf --delimiter '\t' --header 'Pick the USB partition' --prompt 'usb> ' \
        | cut -f1) || true
      [ -n "$dev" ] || { echo "No USB partition selected."; exit 1; }

      mnt=$(lsblk -n -o MOUNTPOINT "$dev" | head -n1)
      if [ -z "$mnt" ]; then
        udisksctl mount -b "$dev" >/dev/null
        mnt=$(lsblk -n -o MOUNTPOINT "$dev" | head -n1)
      fi

      out="$mnt/dfirmed-repos-$(date +%F)"
      mkdir -p "$out"
      work=$(mktemp -d)
      trap 'rm -rf "$work"' EXIT

      failed=()
      for repo in "''${repos[@]}"; do
        echo ">> $repo"
        if git clone --quiet --mirror "git@github-dfirmed:$org/$repo.git" "$work/$repo.git" \
          && git -C "$work/$repo.git" bundle create "$out/$repo.bundle" --all \
          && git -C "$work/$repo.git" bundle verify --quiet "$out/$repo.bundle"; then
          rm -rf "''${work:?}/$repo.git"
        else
          failed+=("$repo")
        fi
      done

      echo "Flushing to $dev..."
      sync

      echo "Exported to $out. On the other machine: git clone <repo>.bundle <dir>"
      if [ ''${#failed[@]} -gt 0 ]; then
        echo "FAILED: ''${failed[*]}" >&2
        exit 1
      fi
    '';
  };
in {
  config = lib.mkIf config.cyber.dfir.enable {
    home.packages = [dfirmed-export];
  };
}
