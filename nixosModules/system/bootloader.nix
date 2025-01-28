{ config, lib, ... }:
let
  cfg = config.system.bootloader;
in {
  options.system.bootloader = lib.mkOption {
    type = lib.types.str;
    default = "systemd";
    description = "Select which bootloader you want."
  };

  config = lib.mkIf (cfg == "systemd") {
    boot = {
      # Pretty boot
      kernelParams = [
        "splash"
        "quiet"
      ];
      plymouth = {
        enable = true;
      };

      # Bootloader
      loader = {
        timeout = 2;
        systemd-boot.enable = true;
        grub.device = "nodev";
        efi.canTouchEfiVariables = true;
      };

      supportedFilesystems = ["ntfs"];

      extraModprobeConfig = ''
        options snd slots=snd-hda-intel
      '';

      # Yubikey FDE with systemd-cryptenroll
      #initrd = {
      #  systemd.enable = true;
      #  luks.fido2Support = false;
      #  luks.devices = {
      #    "encrypted" = {
            # Make sure to verify UUID of the LUKS-partition (using the command blkid)
            # AFTER running nixos-install.
      #      crypttabExtraOpts = ["fido2-device=auto"];
      #    };
      #  };
      #};
    };
  };
}
