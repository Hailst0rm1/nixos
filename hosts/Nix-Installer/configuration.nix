{...}: {
  imports = [
    ../default.nix

    # NixOS-Hardware
    # List: https://github.com/NixOS/nixos-hardware/blob/master/flake.nix
    # inputs.nixos-hardware.nixosModules.common-cpu-intel
    # inputs.nixos-hardware.nixosModules.common-gpu-nvidia
    # inputs.nixos-hardware.nixosModules.common-gpu-intel
    # inputs.nixos-hardware.nixosModules.common-pc-laptop-ssd
    # inputs.nixos-hardware.nixosModules.common-pc-ssd
  ];

  # Override only what's different from default
  removableMedia = true;

  # Enables editing of hosts
  environment.etc.hosts.enable = false;
  environment.etc.hosts.mode = "0700";

  desktopEnvironment.name = "gnome";

  nixpkgs.hostPlatform = "x86_64-linux";
}
