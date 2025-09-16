{
  inputs,
  config,
  hostname,
  lib,
  ...
}: let
  device = "nvme1n1"; # IMPORTANT Set disk device (e.g. "sda", or "nvme0n1") - list with `lsblk`
  diskoConfig = "default";
in {
  imports =
    [
      # Includes hardware config from hardware scan
      ./hardware-configuration.nix

      # NixOS-Hardware - Seem to not work properly on this system?
      # List: https://github.com/NixOS/nixos-hardware/blob/master/flake.nix
      # inputs.nixos-hardware.nixosModules.common-cpu-intel
      # inputs.nixos-hardware.nixosModules.common-gpu-nvidia
      # inputs.nixos-hardware.nixosModules.common-pc-ssd

      # Secrets
      inputs.sops-nix.nixosModules.sops

      # Disk partitioning
      inputs.disko.nixosModules.disko
      ../../nixosModules/system/bootloader.nix
      ../../disko/${diskoConfig}.nix
      {
        _module.args.device = device; # Set disk device (e.g. "sda", or "nvme0n1") - list with `lsblk`
      }

      # Recursively imports all nixosModules
    ]
    ++ lib.filter
    (n: lib.strings.hasSuffix ".nix" n)
    (lib.filesystem.listFilesRecursive ../../nixosModules);

  # === System Specific ===
  # ===

  # variables.nix
  # systemUsers = [ "hailst0rm" "testuser" ];
  username = "hailst0rm";
  hostname = hostname;
  systemArch = "x86_64-linux";
  laptop = false;
  removableMedia = false;
  myLocation = "Barkarby";

  # Red Teaming config
  cyber.redTools.enable = true;

  # desktop/default.nix
  # Gnome is default
  desktopEnvironment.name = "hyprland";

  # Display manager are currently built in the other desktops beside hyprland
  desktopEnvironment.displayManager = {
    enable = true;
    name = "sddm";
  };

  # graphic
  # graphicDriver.intel.enable = true;
  # graphicDriver.nvidia = {
  #   enable = true;
  #   type = "default";
  # };

  security = {
    sops.enable = true;
    firewall.enable = true;
    dnscrypt.enable = false;
    completePolkit.enable = false;
    yubikey.enable = true;
  };

  # Bluetooth
  hardware.bluetooth.enable = true;
  hardware.bluetooth.powerOnBoot = false;

  system = {
    kernel = "zen";
    bootloader = "grub";
    keyboard.colemak-se = true;
    theme = {
      enable = true;
      name = "catppuccin-mocha";
    };
    automatic = {
      upgrade = false;
      cleanup = true;
    };
  };

  virtualisation = {
    host = {
      vmware = false; # Broken?
      virtualbox = true;
      qemu = false;
    };
    guest = {
      vmware = false;
      qemu = false;
    };
  };

  # Hosted / Running services (nixosModules/services)
  services = {
    domain = "pontonsecurity.com";
    cloudflare = {
      enable = false;
      deviceType = "client";
    };
    gitlab.serverIp = "100.84.181.70";
    podman.enable = false;
    openssh.enable = false;
    mattermost.enable = false;
    ollama.enable = false;
    open-webui.enable = false; # UI for local AI
    tailscaleAutoconnect = {
      enable = true;
      authkeyFile = config.sops.secrets."services/tailscale/auth.key".path; # Needs updating every 90 days (okt 16)
      advertiseExitNode = false;
      loginServer = "https://login.tailscale.com";
      exitNode = "100.84.181.70";
      # exitNode = "nix-server";
      exitNodeAllowLanAccess = true;
    };
  };

  # Allow unfree software
  nixpkgs.config.allowUnfree = true;

  # Set your time zone.
  time.timeZone = "Europe/Stockholm";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_GB.UTF-8";

  # Define a user account.
  users = {
    mutableUsers = lib.mkIf config.security.sops.enable false; # All config, even password, is dedicated by nixconf
    users.${config.username} = {
      isNormalUser = true;
      extraGroups = [
        "sudo"
        "docker"
        "networkmanager"
        "wheel"
      ];
      initialPassword = lib.mkIf (!config.security.sops.enable) "t";
      hashedPasswordFile = lib.mkIf config.security.sops.enable config.sops.secrets."passwords/${config.username}".path;
    };
    users.root.hashedPassword = "$6$hj1dq/o8R3.U36Qh$UBNAolzIrKQZJWUdEgtjLDETjkiBHXPwKRUWxrp801bgw.3u72fDzYtOmd8hz8y/fiz.pUenfIJuImCld1ucB1";
  };

  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.05"; # Did you read the comment?
}
