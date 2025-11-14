{inputs, ...}: let
  device = "nvme1n1"; # IMPORTANT Set disk device (e.g. "sda", or "nvme0n1") - list with `lsblk`
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
    }
  ];

  # Override only what's different from default
  myLocation = "Barkarby";
  cyber.redTools.enable = true;

  # graphic
  graphicDriver.intel.enable = true;
  graphicDriver.nvidia = {
    enable = true;
    type = "default";
  };
}
