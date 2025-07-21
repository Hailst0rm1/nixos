{
  inputs,
  config,
  hostname,
  lib,
  pkgs,
  ...
}: let
  device = "nvme0n1"; # IMPORTANT Set disk device (e.g. "sda", or "nvme0n1") - list with `lsblk`
  diskoConfig = "default";
in {
  imports =
    [
      # Includes hardware config from hardware scan
      ./hardware-configuration.nix

      # NixOS-Hardware - Seem to not work properly on this system?
      # List: https://github.com/NixOS/nixos-hardware/blob/master/flake.nix
      inputs.nixos-hardware.nixosModules.common-cpu-intel
      # inputs.nixos-hardware.nixosModules.common-gpu-nvidia
      inputs.nixos-hardware.nixosModules.common-gpu-intel
      inputs.nixos-hardware.nixosModules.common-pc-laptop-ssd
      # inputs.nixos-hardware.nixosModules.dell-precision-5530

      # Secrets
      inputs.sops-nix.nixosModules.sops

      # Disk partitioning
      # inputs.disko.nixosModules.disko
      # ../../nixosModules/system/bootloader.nix
      # ../../disko/${diskoConfig}.nix
      # {
      #   _module.args.device = device; # Set disk device (e.g. "sda", or "nvme0n1") - list with `lsblk`
      # }

      # Recursively imports all nixosModules
    ]
    ++ lib.filter
    (n: lib.strings.hasSuffix ".nix" n)
    (lib.filesystem.listFilesRecursive ../../nixosModules);

  # === System Specific ===
  sops.secrets."wifi.env" = {};

  networking = {
    networkmanager = {
      enable = true;
      ensureProfiles = {
        environmentFiles = [config.sops.secrets."wifi.env".path];
        profiles = {
          home-wifi = {
            connection.id = "home-wifi";
            connection.type = "wifi";
            wifi.ssid = "$HOME_WIFI_SSID";
            wifi-security = {
              auth-alg = "open";
              key-mgmt = "wpa-psk";
              psk = "$HOME_WIFI_PASSWORD";
            };
          };
        };
      };
    };
  };
  # ===

  # variables.nix
  # systemUsers = [ "hailst0rm" "testuser" ];
  username = "hailst0rm";
  hostname = hostname;
  systemArch = "x86_64-linux";
  laptop = true;
  removableMedia = false;
  myLocation = "Barkarby";

  # Red Teaming config
  cyber.redTools.enable = false;

  # desktop/default.nix
  # Gnome is default
  desktopEnvironment.name = "";

  # Display manager are currently built in the other desktops beside hyprland
  desktopEnvironment.displayManager = {
    enable = false;
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
    bootloader = "systemd";
    keyboard.colemak-se = false;
    theme = {
      enable = false;
      name = "catppuccin-mocha";
    };
    automatic = {
      upgrade = false;
      cleanup = false;
    };
  };

  virtualisation = {
    host = {
      vmware = false; # Broken?
      qemu = false;
    };
    guest = {
      vmware = false;
      qemu = false;
    };
  };

  # Hosted / Running services (nixosModules/services)
  services = {
    openssh.enable = true;
    mattermost.enable = false;
    ollama.enable = false;
    open-webui.enable = false; # UI for local AI
    cloudflared.enable = true;
    tailscaleAutoconnect = {
      enable = true;
      authkeyFile = config.sops.secrets."services/tailscale/auth.key".path; # Needs updating every 90 days (okt 16)
      advertiseExitNode = true;
      loginServer = "https://login.tailscale.com";
      exitNode = "";
      exitNodeAllowLanAccess = false;
    };
    ghost = {
      enable = true;
      domain = "pontonsecurity.com";
      sslCertPath = config.sops.secrets."services/ghost/pontonsecurity/cert.pem".path;
      sslCertKeyPath = config.sops.secrets."services/ghost/pontonsecurity/cert.key".path;
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
      initialPassword = "t";
      # hashedPasswordFile = lib.mkIf config.security.sops.enable config.sops.secrets."passwords/${config.username}".path;
    };
    users.root.hashedPassword = "$6$hj1dq/o8R3.U36Qh$UBNAolzIrKQZJWUdEgtjLDETjkiBHXPwKRUWxrp801bgw.3u72fDzYtOmd8hz8y/fiz.pUenfIJuImCld1ucB1";
  };

  # Do NOT change this value unless you have manually inspected all the changes it would make to your configuration,
  # and migrated your data accordingly.
  #
  # For more information, see `man configuration.nix` or https://nixos.org/manual/nixos/stable/options#opt-system.stateVersion .
  system.stateVersion = "24.05"; # Did you read the comment?
}
