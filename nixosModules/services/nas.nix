{
  config,
  lib,
  pkgs,
  ...
}: {
  options.services.nas = with lib; {
    enable = mkEnableOption "Enable NAS/fileserver with Samba";

    mountPoint = mkOption {
      type = types.str;
      default = "/mnt/nas";
      description = "Path where the external SSD will be mounted.";
    };

    diskId = mkOption {
      type = types.str;
      default = "";
      description = "Stable disk ID from /dev/disk/by-id/ (ls /dev/disk/by-id/).";
    };

    fsType = mkOption {
      type = types.enum ["ext4" "zfs" "btrfs"];
      default = "ext4";
      description = "Filesystem type of the external SSD.";
    };

    workgroup = mkOption {
      type = types.str;
      default = "WORKGROUP";
      description = "Samba workgroup name.";
    };

    allowedSubnets = mkOption {
      type = types.listOf types.str;
      default = ["192.168.0.0/24"];
      description = "Subnets allowed to access the share. Samba accepts space-separated entries, e.g. LAN + Tailscale.";
    };

    shareName = mkOption {
      type = types.str;
      default = "files";
      description = "Name of the Samba share.";
    };

    shareComment = mkOption {
      type = types.str;
      default = "NAS file share";
      description = "Comment/description for the Samba share.";
    };

    readOnly = mkOption {
      type = types.bool;
      default = false;
      description = "Whether the share is read-only.";
    };

    zfs = {
      autoScrub = mkOption {
        type = types.bool;
        default = true;
        description = "Enable periodic ZFS scrub (only relevant when fsType = zfs).";
      };
    };
  };

  config = lib.mkIf config.services.nas.enable {
    # ── Filesystem ──────────────────────────────────────────────────────────
    fileSystems.${config.services.nas.mountPoint} = lib.mkIf (config.services.nas.diskId != "") {
      device = "/dev/disk/by-id/${config.services.nas.diskId}";
      fsType = config.services.nas.fsType;
      options = ["defaults" "nofail"]; # nofail: don't panic if drive is absent at boot
    };

    # ── ZFS (only when fsType = zfs) ────────────────────────────────────────
    boot.supportedFilesystems = lib.mkIf (config.services.nas.fsType == "zfs") ["zfs"];
    services.zfs.autoScrub.enable = lib.mkIf (config.services.nas.fsType == "zfs") config.services.nas.zfs.autoScrub;

    # ── Samba ───────────────────────────────────────────────────────────────
    services.samba = {
      enable = true;
      package = pkgs.samba4Full; # includes avahi/mDNS for autodiscovery
      openFirewall = true;
      settings = {
        global = {
          workgroup = config.services.nas.workgroup;
          security = "user";
          "server smb encrypt" = "required";
          "server min protocol" = "SMB3_00";
          "hosts allow" = "${lib.concatStringsSep " " config.services.nas.allowedSubnets} 127.0.0.1";
          "hosts deny" = "0.0.0.0/0";
        };
        ${config.services.nas.shareName} = {
          path = config.services.nas.mountPoint;
          comment = config.services.nas.shareComment;
          browseable = "yes";
          "read only" = lib.boolToString config.services.nas.readOnly;
          "guest ok" = "no";
          "create mask" = "0644";
          "directory mask" = "0755";
          "valid users" = config.username;
        };
      };
    };

    # ── Samba-WSDD (Windows Service Discovery) ──────────────────────────────
    services.samba-wsdd = {
      enable = true;
      openFirewall = true;
    };

    # ── Avahi / mDNS autodiscovery ──────────────────────────────────────────
    services.avahi = {
      enable = true;
      publish.enable = true;
      publish.userServices = true;
      openFirewall = true;
    };
  };
}
