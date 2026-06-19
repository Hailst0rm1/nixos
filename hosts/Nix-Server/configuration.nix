{
  inputs,
  config,
  ...
}: {
  imports = [
    ./hardware-configuration.nix
    ../default.nix

    # NixOS-Hardware
    # List: https://github.com/NixOS/nixos-hardware/blob/master/flake.nix
    inputs.nixos-hardware.nixosModules.common-cpu-intel
    # inputs.nixos-hardware.nixosModules.common-gpu-nvidia
    inputs.nixos-hardware.nixosModules.common-gpu-intel
    inputs.nixos-hardware.nixosModules.common-pc-laptop-ssd
    # inputs.nixos-hardware.nixosModules.dell-precision-5530

    # Disk partitioning - DISABLED for this host
    # inputs.disko.nixosModules.disko
    # ../../nixosModules/system/bootloader.nix
    # ../../disko/${diskoConfig}.nix
    # {
    #   _module.args.device = device;
    # }
  ];

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

  # Override only what's different from default
  laptop = true;
  myLocation = "Barkarby";

  desktopEnvironment.name = "headless";
  desktopEnvironment.displayManager.enable = false;

  system = {
    bootloader = "systemd";
    keyboard.colemak-se = false;
    theme.enable = false;
    automatic.cleanup = false;
  };

  virtualisation.host = {
    virtualbox = false;
    qemu = false;
  };

  services = {
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
          Developing = {
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
        {
          Utilities = {
            icon = "mdi-wrench.svg";
          };
        }
        {
          Cyber = {
            icon = "mdi-shield-bug.svg";
          };
        }
        {
          Entertainment = {
            icon = "mdi-folder-play.svg";
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
                siteMonitor = "https://admin.pontonsecurity.com";
              };
            }
          ];
        }
        {
          Developing = [
            {
              "GitLab" = {
                description = "Business Code Repository";
                icon = "sh-gitlab.svg";
                href = "https://gitlab.pontonsecurity.com";
                siteMonitor = "https://gitlab.pontonsecurity.com";
              };
            }
            {
              "GitHub" = {
                description = "Public Code Repository";
                icon = "sh-github.svg";
                href = "https://github.com";
              };
            }
            {
              "Nix Packages" = {
                description = "NixOS Package Repository";
                icon = "sh-nixos.svg";
                href = "https://search.nixos.org/packages?channel=unstable";
              };
            }
            {
              "Nix Options" = {
                description = "MyNixOS Settings Collection";
                icon = "sh-nixos.svg";
                href = "https://mynixos.com/search";
              };
            }
          ];
        }
        {
          Admin = [
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
            {
              "Tailscale" = {
                description = "Internal VPN";
                icon = "sh-tailscale.svg";
                href = "https://login.tailscale.com/admin/machines";
              };
            }
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
              "Agent Browser" = {
                description = "Live noVNC view of the Hermes agent's Chrome";
                icon = "mdi-eye.svg";
                href = "http://nix-server:6080/vnc.html?host=nix-server&port=6080&autoconnect=true&resize=remote";
              };
            }
          ];
        }
        {
          Other = [
            {
              "Vaultwarden" = {
                description = "Password Manager";
                icon = "sh-vaultwarden.svg";
                href = "https://vault.pontonsecurity.com";
                siteMonitor = "https://vault.pontonsecurity.com";
              };
            }
            {
              "ChatGPT" = {
                description = "Online AI Chatbot";
                icon = "sh-openai.svg";
                href = "https://chatgpt.com";
              };
            }
          ];
        }
      ];

      bookmarks = [
        {
          Utilities = [
            {
              "Google Calendar" = [
                {
                  description = "";
                  icon = "sh-google-calendar.svg";
                  href = "https://calendar.google.com";
                }
              ];
            }
            {
              "Proton Mail" = [
                {
                  description = "";
                  icon = "sh-proton-mail.svg";
                  href = "https://mail.proton.me";
                }
              ];
            }
            {
              "Proton Drive" = [
                {
                  description = "";
                  icon = "sh-proton-drive.svg";
                  href = "https://drive.proton.me";
                }
              ];
            }
            {
              "Google Maps" = [
                {
                  description = "";
                  icon = "sh-google-maps.svg";
                  href = "https://maps.google.com/";
                }
              ];
            }
            {
              "Budget" = [
                {
                  description = "";
                  icon = "sh-google-sheets.svg";
                  href = "https://docs.google.com/spreadsheets/d/1fxOANLsHROOpEToCqeHe_TY7ScNmveNOAwyqX4ajX6Y/edit?usp=sharing";
                }
              ];
            }
          ];
        }
        {
          Cyber = [
            {
              Github = [
                {
                  description = "";
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
                  description = "";
                  icon = "sh-youtube.svg";
                  href = "https://youtube.com/";
                }
              ];
            }
            {
              Twitch = [
                {
                  description = "";
                  icon = "sh-twitch.svg";
                  href = "https://twitch.com/";
                }
              ];
            }
            {
              F1 = [
                {
                  description = "";
                  icon = "si-f1.svg";
                  href = "https://f1tv.formula1.com/";
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
      enable = false;
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
    n8n.podman.enable = false;
    rsshub.enable = true;
    hermes-agent = {
      enable = true;
      discord = {
        # Default/system Hermes Agent bot: only under the regular Hermes channel.
        # Dev Orchestrator is a separate user-profile gateway restricted in
        # ~/.hermes/profiles/dev-orchestrator/.
        homeChannel = "1504852662313681108";
        allowedChannels = ["1504852662313681108"];
        ignoredChannels = ["1512064018230149170"];
      };
      signal.enable = false;
      # Headless server runs the backend, not the GUI client — skip the heavy
      # Electron closure (desktop is default-on via hosts/default.nix).
      desktop.enable = false;
      # Dashboard backend for the desktop client on Nix-Laptop. Binds to
      # 0.0.0.0 (reachable from the laptop over Tailscale at :9119) and runs in
      # --insecure token mode. Keep port 9119 off the public internet
      # (Tailscale/LAN only — not proxied by Cloudflare); the tailnet is the
      # trust boundary. Set a stable session token by adding this to the
      # `services/hermes-agent/env` blob via `sops secrets/hailst0rm.yaml`:
      #   HERMES_DASHBOARD_SESSION_TOKEN=<long-random-token>   # `openssl rand -base64 32`
      # and put the SAME value in the raw `services/hermes-agent/desktop-token`
      # secret so the laptop's HERMES_DESKTOP_REMOTE_TOKEN matches.
      dashboard.enable = true;
      browser.enable = true;
    };
    vncDisplay.enable = true;
    podman.enable = true;
    openssh.enable = true;
    cloudflare = {
      enable = true;
      deviceType = "server";
    };
    tailscaleAutoconnect = {
      advertiseExitNode = true;
      exitNode = "";
      exitNodeAllowLanAccess = false;
    };
    ghost = {
      enable = true;
      sslCertFile = config.sops.secrets."services/ghost/pontonsecurity/cert.pem".path;
      sslCertKeyFile = config.sops.secrets."services/ghost/pontonsecurity/cert.key".path;
    };
    # code-server = {
    #   enable = true;
    #   port = 8443;
    # };
    openvscode-server = {
      enable = true;
      port = 8443;
    };

    proton-bridge.enable = true;
    nas = {
      enable = true;
      diskId = "usb-Samsung_Portable_SSD_T5_1234568390CD-0:0";
      mountPoint = "/mnt/nas";
      shareName = "files";
      shareComment = "NAS file share";
      allowedSubnets = [
        "192.168.0.0/24" # LAN
        "100.64.0.0/10" # Tailscale CGNAT range
      ];
      workgroup = "WORKGROUP";
      readOnly = false;
    };
    claudeTeach.enable = true;
  };

  services.syncthing-sync = {
    enable = true;
    folders = {
      "nixos-config" = {
        label = "NixOS Config";
        path = "/mnt/nas/NixOS";
        stignore = ''
          .claude
          .direnv
          result
        '';
      };
      "code" = {
        label = "Code Projects";
        path = "/mnt/nas/Code";
      };
      "notsliver" = {
        label = "NotSliver";
        path = "/mnt/nas/Config/NotSliver";
      };
    };
  };

  # Point nixosDir to NAS where Syncthing syncs the config.
  # The rebuild script rsyncs NAS→local before building for performance.
  nixosDir = "/mnt/nas/NixOS";

  users.users.${config.username}.linger = true;
}
