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

    client = {
      enable = mkEnableOption "Automount the NAS share from a client machine via CIFS/SMB";

      serverHost = mkOption {
        type = types.str;
        default = "nix-server";
        description = "Hostname or IP of the NAS server (Tailscale hostname works with MagicDNS).";
      };

      shareName = mkOption {
        type = types.str;
        default = "files";
        description = "Name of the Samba share to mount.";
      };

      mountPoint = mkOption {
        type = types.str;
        default = "/mnt/nas";
        description = "Local path where the share will be automounted.";
      };

      idleTimeoutSec = mkOption {
        type = types.str;
        default = "600";
        description = "Unmount the share after this many seconds of inactivity (0 = never).";
      };
    };
  };

  config = lib.mkMerge [
    # ── SERVER ───────────────────────────────────────────────────────────────
    (lib.mkIf config.services.nas.enable {
      # ── Samba password via sops ────────────────────────────────────────────
      sops.secrets."passwords/nas-password" = {
        owner = "root";
        mode = "0400";
      };

      # Set/update the Samba password after smbd is running (secrets.tdb must exist)
      systemd.services.samba-password = {
        description = "Set Samba user password from sops secret";
        after = ["samba-smbd.service"];
        requires = ["samba-smbd.service"];
        wantedBy = ["multi-user.target"];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
        };
        script = ''
          SMB_PASS=$(cat ${config.sops.secrets."passwords/nas-password".path})
          echo -e "$SMB_PASS\n$SMB_PASS" | ${pkgs.samba}/bin/smbpasswd -L -s -a ${config.username} || \
          echo -e "$SMB_PASS\n$SMB_PASS" | ${pkgs.samba}/bin/smbpasswd -L -s ${config.username}
        '';
      };

      # ── Filesystem ──────────────────────────────────────────────────────────
      fileSystems.${config.services.nas.mountPoint} = lib.mkIf (config.services.nas.diskId != "") {
        device = "/dev/disk/by-id/${config.services.nas.diskId}";
        fsType = "ext4";
        options = ["defaults" "nofail"]; # nofail: don't panic if drive is absent at boot
      };

      # ── Samba ─────────────────────────────────────────────────────────────
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

      # ── Samba-WSDD (Windows Service Discovery) ────────────────────────────
      services.samba-wsdd = {
        enable = true;
        openFirewall = true;
      };

      # ── Avahi / mDNS autodiscovery ────────────────────────────────────────
      services.avahi = {
        enable = true;
        publish.enable = true;
        publish.userServices = true;
        openFirewall = true;
      };
    })

    # ── CLIENT (laptops/workstations) ─────────────────────────────────────
    (lib.mkIf config.services.nas.client.enable {
      # Credentials file: username=... / password=... kept in sops
      sops.secrets."passwords/nas-client" = {
        owner = "root";
        mode = "0400";
      };

      environment.systemPackages = [pkgs.cifs-utils];

      fileSystems.${config.services.nas.client.mountPoint} = {
        device = "//${config.services.nas.client.serverHost}/${config.services.nas.client.shareName}";
        fsType = "cifs";
        options = [
          "credentials=${config.sops.secrets."passwords/nas-client".path}"
          "uid=1000"
          "gid=100"
          "iocharset=utf8"
          "vers=3.0"
          "_netdev"
          "nofail"
          "x-systemd.automount"
          "x-systemd.idle-timeout=${config.services.nas.client.idleTimeoutSec}"
          "x-systemd.after=tailscaled.service"
        ];
      };

      # Point nixosDir to the NAS copy, keep local as fallback
      nixosDir = "${config.services.nas.client.mountPoint}/NixOS";
      nixosDirFallback = "/home/${config.username}/.nixos";
    })
  ];
}
