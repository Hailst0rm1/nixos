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
    domain = "pontonsecurity.com";
    homepage-dashboard = {
      enable = true;
      icon = ../../assets/images/pontonsecurity_transparent.png;
      background = ../../assets/images/mountain.jpg;
      # colour = "gray";

      settings.layout = [
        {
          Business = {
            style = "row";
            columns = 4;
            icon = "mdi-briefcase-variant.svg";
          };
        }
        {
          Cyber = {
            style = "row";
            columns = 4;
            icon = "mdi-shield-bug.svg";
          };
        }
        {
          Admin = {
            style = "row";
            columns = 4;
            icon = "mdi-server.svg";
          };
        }
        {
          Other = {
            style = "row";
            columns = 4;
            icon = "mdi-dots-grid.svg";
          };
        }
      ];

      # https://gethomepage.dev/configs/services/
      services = [
        {
          Business = [
            {
              "Ponton Security" = {
                description = "Business website";
                icon = "sh-ghost.png";
                href = "https://pontonsecurity.com";
                siteMonitor = "https://pontonsecurity.com";
              };
            }
            {
              "Admin Panel: Ponton Security" = {
                description = "Website admin panel";
                icon = "sh-ghost.png";
                href = "https://admin.pontonsecurity.com";
              };
            }
          ];
        }
        {
          Cyber = [
            {
              "Ponton Security" = {
                description = "Business website";
                icon = "sh-ghost.png";
                href = "https://pontonsecurity.com";
                siteMonitor = "https://pontonsecurity.com";
              };
            }
            {
              "Admin Panel: Ponton Security" = {
                description = "Website admin panel";
                icon = "sh-ghost.png";
                href = "https://admin.pontonsecurity.com";
              };
            }
          ];
        }
        {
          Admin = [
            {
              "Firewalla" = {
                description = "Home Firewall";
                icon = "sh-firewalla.svg";
                href = "https://my.firewalla.com/#/dashboard";
              };
            }
            {
              "AltaLabs" = {
                description = "Home switch + AP";
                icon = "sh-watchyourlan.png";
                href = "https://manage.alta.inc";
              };
            }
            {
              "Router" = {
                description = "ISP Router";
                icon = "sh-watchyourlan.png";
                href = "http://192.168.0.1";
              };
            }
            {
              "Tailscale" = {
                description = "Internal VPN";
                icon = "sh-tailscale.svg";
                href = "https://login.tailscale.com/admin/machines";
              };
            }
            {
              "Cloudflare" = {
                description = "Domain and DNS";
                icon = "sh-cloudflare.svg";
                href = "https://dash.cloudflare.com/";
              };
            }
            {
              "Zero Trust" = {
                description = "Access and applications";
                icon = "sh-cloudflare.svg";
                href = "https://one.dash.cloudflare.com";
              };
            }
          ];
        }
        {
          Other = [
            {
              "Vaultwarden" = {
                description = "Password Manages";
                icon = "sh-vaultwarden.svg";
                href = "https://vault.pontonsecurity.com";
                siteMonitor = "https://vault.pontonsecurity.com";
              };
            }
            {
              "Admin Panel: Ponton Security" = {
                description = "Website admin panel";
                icon = "sh-ghost.png";
                href = "https://admin.pontonsecurity.com";
              };
            }
          ];
        }
      ];

      bookmarks = [
        {
          Utilities = [
            {
              "Proton Drive" = [
                {
                  icon = "sh-proton-drive.svg";
                  href = "https://drive.proton.me";
                }
              ];
            }
            {
              "Proton Mail" = [
                {
                  icon = "sh-proton-mail.svg";
                  href = "https://mail.proton.me";
                }
              ];
            }
            {
              "Google Maps" = [
                {
                  icon = "sh-google-maps.svg";
                  href = "https://maps.google.com/";
                }
              ];
            }
            {
              "Google Calendar" = [
                {
                  icon = "sh-google-calendar.svg";
                  href = "https://calendar.google.com";
                }
              ];
            }
            {
              "Budget" = [
                {
                  icon = "sh-google-sheets.svg";
                  href = "https://docs.google.com/spreadsheets/d/1fxOANLsHROOpEToCqeHe_TY7ScNmveNOAwyqX4ajX6Y/edit?usp=sharing";
                }
              ];
            }
          ];
        }
        {
          AI = [
            {
              ChatGPT = [
                {
                  icon = "sh-openai.svg";
                  href = "https://chatgpt.com";
                }
              ];
            }
          ];
        }
        {
          Developer = [
            {
              Github = [
                {
                  icon = "sh-github.svg";
                  href = "https://github.com/";
                }
              ];
            }
          ];
        }
        {
          Entertainment = [
            {
              YouTube = [
                {
                  icon = "sh-youtube.svg";
                  href = "https://youtube.com/";
                }
              ];
            }
            {
              Twitch = [
                {
                  icon = "sh-twitch.svg";
                  href = "https://twitch.com/";
                }
              ];
            }
            {
              F1 = [
                {
                  icon = "si-f1.svg";
                  href = "https://https://f1tv.formula1.com/";
                }
              ];
            }
          ];
        }
      ];
    };

    vaultwarden = {
      enable = false;
      adminToken = "$argon2id$v=19$m=65540,t=3,p=4$D/pg3E3rtnry4H1z6OqWA1EVHJZ7aN8rU5nnBQJ+Vf8$Vv7Nb4yvCkMCTWzSKchfuCcQoNDEKqNwE5WPx616TlY"; # Same as bitwarden
      allowSignup = true; # Set to false after account creation
      yubicoClient = "";
      yubicoKey = "";
    };
    gitlab = {
      enable = true;
      databasePasswordFile = config.sops.secrets."services/gitlab/db-password".path;
      initialRootPasswordFile = config.sops.secrets."services/gitlab/root-password".path;
      secrets = {
        secretFile = config.sops.secrets."services/gitlab/secret".path;
        otpFile = config.sops.secrets."services/gitlab/otp".path;
        dbFile = config.sops.secrets."services/gitlab/db".path;
        jwsFile = config.sops.secrets."services/gitlab/jws".path;
        activeRecordPrimaryKeyFile = config.sops.secrets."services/gitlab/recordPrimary".path;
        activeRecordDeterministicKeyFile = config.sops.secrets."services/gitlab/recordDeterministic".path;
        activeRecordSaltFile = config.sops.secrets."services/gitlab/recordSalt".path;
      };
    };
    podman.enable = true;
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
      sslCertFile = config.sops.secrets."services/ghost/pontonsecurity/cert.pem".path;
      sslCertKeyFile = config.sops.secrets."services/ghost/pontonsecurity/cert.key".path;
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
