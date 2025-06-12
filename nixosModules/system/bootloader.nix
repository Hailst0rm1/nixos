{
  device,
  pkgs,
  config,
  lib,
  ...
}: let
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
          enableCryptodisk = true;
          device =
            if device != null
            then "/dev/${device}"
            else "nodev";
          efiInstallAsRemovable = lib.mkIf config.removableMedia true;
        };
        efi.efiSysMountPoint = "/boot";
        timeout = lib.mkDefault 2;
        efi.canTouchEfiVariables = lib.mkIf (!config.removableMedia) true;
      };

      supportedFilesystems = {
        ntfs = true;
        btrfs = true;
        luks = true;
      };

      extraModprobeConfig = ''
        options snd slots=snd-hda-intel
      '';
    };
  };
}
