{inputs, ...}: let
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
