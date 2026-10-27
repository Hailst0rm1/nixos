{
  inputs,
  lib,
  ...
}: let
  device = "nvme1n1"; # IMPORTANT Set disk device (e.g. "sda", or "nvme0n1") - list with `lsblk`
  swapSize = "16G"; # IMPORTANT Keep at 16GB, unless hibernation - then set to RAM size (e.g. "32G", "64G") - check with `free -g`
  diskoConfig = "default";
in {
  imports = [
    ./hardware-configuration.nix
    ../default.nix

    # NixOS-Hardware
    # List: https://github.com/NixOS/nixos-hardware/blob/master/flake.nix
    # inputs.nixos-hardware.nixosModules.common-cpu-intel
    # inputs.nixos-hardware.nixosModules.common-gpu-nvidia
    # inputs.nixos-hardware.nixosModules.common-pc-ssd

    # Disk partitioning
    inputs.disko.nixosModules.disko
    ../../nixosModules/system/bootloader.nix
    ../../disko/${diskoConfig}.nix
    {
      _module.args.device = device;
      _module.args.swapSize = swapSize;
    }
  ];

  # Override only what's different from default
  myLocation = "Barkarby";
  cyber.redTools.enable = true;

  # NVMe enumeration swapped after install: the NixOS disk is now nvme0n1, but
  # `device` (above) stays "nvme1n1" because disko derives the on-disk LUKS/boot
  # partlabels from it and the running system resolves them by partlabel, not by
  # the raw /dev node. The only thing that used the raw /dev/${device} path was
  # GRUB's legacy-BIOS install, which then targeted the wrong (Windows) disk.
  # This box is UEFI (ESP at /boot, canTouchEfiVariables) so install EFI-only.
  # disko's EF02 partition auto-sets grub.devices to /dev/${device}; force the
  # list (what install-grub.pl actually uses) to nodev, not just the singular.
  boot.loader.grub.device = lib.mkForce "nodev";
  boot.loader.grub.devices = lib.mkForce ["nodev"];

  services.openssh.enable = true;

  services.nas.client = {
    enable = true;
    serverHost = "nix-server"; # Tailscale MagicDNS hostname (or use 100.x.x.x IP)
    shareName = "files";
    mountPoint = "/mnt/nas";
    idleTimeoutSec = "0";
  };

  # graphic
  graphicDriver.intel = {
    enable = true;
    forceProbe = "a7a0";
  };
  graphicDriver.nvidia.enable = true;

  services.syncthing-sync = {
    enable = true;
    folders = {
      "nixos-config" = {
        label = "NixOS Config";
        path = "/home/hailst0rm/.nixos";
        stignore = ''
          .claude
          .codegraph
          .direnv
          result
        '';
      };
      "code" = {
        label = "Code Projects";
        path = "/home/hailst0rm/Code";
      };
      "notsliver" = {
        label = "NotSliver";
        path = "/home/hailst0rm/.config/NotSliver";
      };
    };
  };
}
