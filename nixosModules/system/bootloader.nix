{ pkgs, config, lib, ... }:
let
  loader = config.system.bootloader;
  kernel = config.system.kernel;
in {
  options.system = {
    bootloader = lib.mkOption {
      type = lib.types.str;
      default = "systemd";
      description = "Select which bootloader you want.";
    };
    kernel = lib.mkOption {
      type = lib.types.str;
      default = "";
      description = "Select which kernel you want.";
    };
  };
     

  config = {
    boot = {
      # Pretty boot
      kernelParams = [
        "splash"
        "quiet"
      ];
      plymouth = {
        enable = true;
      };

      kernelPackages = lib.mkIf (kernel == "zen") pkgs.linuxKernel.packages.linux_zen; 

      # Bootloader
      loader = {
        systemd-boot.enable = lib.mkIf (loader == "systemd") true;
        grub = lib.mkIf (loader == "grub") {
          enable = true;
          #theme = lib.mkForce "${pkgs.libsForQt5.breeze-grub}/grub/themes/breeze";
          #useOSProber = true;
          efiSupport = true;
          device = "/dev/sda";
          # device = "nodev";
          efiInstallAsRemovable = true;
        };
        timeout = 2;
        # efi.canTouchEfiVariables = true;
      };

      supportedFilesystems = {
        ntfs = true;
        btrfs = true;
        luks = true;
      };

      extraModprobeConfig = ''
        options snd slots=snd-hda-intel
      '';

      # Yubikey FDE with systemd-cryptenroll
      initrd = {
        systemd.enable = true;
        luks.fido2Support = false;
      #  luks.devices = {
      #    "encrypted" = {
            # Make sure to verify UUID of the LUKS-partition (using the command blkid)
            # AFTER running nixos-install.
      #      crypttabExtraOpts = ["fido2-device=auto"];
      #    };
      #  };
      };
    };
  };
}
