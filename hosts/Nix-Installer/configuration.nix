{
  pkgs,
  lib,
  ...
}: {
  imports = [
    ../default.nix
    {_module.args.device = null;} # No disk — installer is a live USB
  ];

  # Installer is a live USB environment
  removableMedia = true;
  desktopEnvironment.name = "gnome";
  nixpkgs.hostPlatform = "x86_64-linux";

  # Enables editing of hosts
  environment.etc.hosts.enable = false;
  environment.etc.hosts.mode = "0700";

  # Minimal filesystem for live USB (no disko, no hardware-configuration.nix)
  fileSystems."/" = {
    device = "tmpfs";
    fsType = "tmpfs";
  };

  # GNOME provides its own SSH agent and display manager (GDM)
  programs.ssh.startAgent = lib.mkForce false;
  desktopEnvironment.displayManager.name = "gdm";

  # Disable services not needed on a live installer
  security.sops.enable = false;
  security.yubikey.enable = false;
  hardware.bluetooth.enable = false;
  services.tailscaleAutoconnect.enable = false;
  system.theme.enable = false;
  system.keyboard.colemak-se = false;
  system.automatic.cleanup = false;
  virtualisation.host.virtualbox = false;

  # Installation tools
  environment.systemPackages = with pkgs; [
    # Disk partitioning & filesystem
    gptfdisk
    parted
    gum
    btrfs-progs
    dosfstools
    cryptsetup

    # Network
    curl
    wget

    # Essentials
    git
    vim
    htop
  ];
}
