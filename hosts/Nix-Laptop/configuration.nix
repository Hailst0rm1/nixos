{inputs, ...}: let
  device = "nvme0n1"; # IMPORTANT Set disk device (e.g. "sda", or "nvme0n1") - list with `lsblk`
  swapSize = "16G"; # IMPORTANT Keep at 16GB, unless hibernation - then set to RAM size (e.g. "32G", "64G") - check with `free -g`
  diskoConfig = "default";
in {
  imports = [
    ./hardware-configuration.nix
    ../default.nix

    # NixOS-Hardware
    # List: https://github.com/NixOS/nixos-hardware/blob/master/flake.nix
    inputs.nixos-hardware.nixosModules.common-pc-laptop
    inputs.nixos-hardware.nixosModules.common-pc-laptop-ssd
    inputs.nixos-hardware.nixosModules.common-cpu-intel

    # Disk partitioning
    inputs.disko.nixosModules.disko
    ../../nixosModules/system/bootloader.nix
    ../../disko/${diskoConfig}.nix
    {
      _module.args.device = device;
      _module.args.swapSize = swapSize;
    }
  ];

  # Override only what's different from the default
  laptop = true;
  myLocation = "Barkarby";
  cyber.redTools.enable = true;

  services.openssh.enable = true;

  services.nas.client = {
    enable = true;
    serverHost = "nix-server"; # Tailscale MagicDNS hostname (or use 100.x.x.x IP)
    shareName = "files";
    mountPoint = "/mnt/nas";
    idleTimeoutSec = "0";
  };

  # Graphics - Intel iGPU + NVIDIA dGPU with PRIME sync
  graphicDriver.intel = {
    enable = true;
    forceProbe = "a7a0";
  };
  graphicDriver.nvidia = {
    enable = true;
    prime = {
      offload.enable = true;
      intelBusId = "PCI:0:2:0";
      nvidiaBusId = "PCI:1:0:0";
    };
  };

  services.syncthing-sync = {
    enable = true;
    role = "client";
    deviceIds = {
      server = "BLUYDNF-PSX5QVQ-Y7KIB6W-R5PNVRU-DVILTCP-5JFF6GY-ZY537VM-BVB3JAG";
      workstation = "JYSSQ45-2FX47AF-JI6TW6H-GAUZUCP-ZGZTOSV-DEDARIY-ZVNPF3E-LHK7IQB";
      laptop = "XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX-XXXXXXX";
    };
  };
}
