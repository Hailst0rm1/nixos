{inputs, ...}: let
  device = "sda"; # IMPORTANT Set disk device (e.g. "sda", or "nvme0n1") - list with `lsblk`
  diskoConfig = "default";
in {
  imports = [
    ./hardware-configuration.nix
    ../default.nix

    # NixOS-Hardware
    # List: https://github.com/NixOS/nixos-hardware/blob/master/flake.nix
    # inputs.nixos-hardware.nixosModules.common-cpu-intel
    # inputs.nixos-hardware.nixosModules.common-gpu-nvidia
    # inputs.nixos-hardware.nixosModules.common-gpu-intel
    # inputs.nixos-hardware.nixosModules.common-pc-laptop-ssd
    # inputs.nixos-hardware.nixosModules.common-pc-ssd

    # Disk partitioning
    inputs.disko.nixosModules.disko
    ../../nixosModules/system/bootloader.nix
    ../../disko/${diskoConfig}.nix
    {
      _module.args.device = device;
    }
  ];

  # Override only what's different from default
  laptop = true;
  removableMedia = true;
  myLocation = "Barkarby";

  # Enables editing of hosts
  environment.etc.hosts.enable = false;
  environment.etc.hosts.mode = "0700";

  security.sops.enable = false;

  graphicDriver.nvidia.enable = false;

  virtualisation.host = {
    virtualbox = false;
    vmware = true;
  };

  system.automatic.cleanup = false;
}
