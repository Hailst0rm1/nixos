{
  device ? "sda",  # The target disk device (e.g. "sda", "nvme0n1"); can be overridden
  pkgs,            # Nixpkgs set, required for accessing utilities like 'gum'
  lib,
  ...
}:
let
  luksLabel = "luks-x2000-${device}";  # Label for the LUKS-encrypted partition
in
{
  # Define the LUKS device to unlock at boot via systemd
  boot.initrd = {
    # Yubikey FDE with systemd-cryptenroll
    systemd.enable = true;
    luks.fido2Support = false;

    # luks.devices."x2000-encrypted-${device}" = {
    #   device = "/dev/disk/by-partlabel/${luksLabel}";  # LUKS device identified by partition label
    #   crypttabExtraOpts = [ "fido2-device=auto" ];     # Use FIDO2 device (e.g. YubiKey) for unlocking
    # };
      
  
  };

  disko.devices = {
    disk = {
      "x2000-${device}" = {
        type = "disk";  # This is a physical disk
        device = "/dev/${device}";  # Device path for the disk

        content = {
          type = "gpt";  # Use GPT partitioning scheme

          partitions = {
            MBR = {
              type = "EF02";  # BIOS boot partition (GRUB bootloader support in legacy mode)
              size = "1M";
              priority = 1;
              # NOTE: Can be removed if UEFI-only system
            };

            ESP-x2000 = {
              label = "boot-x2000-${device}";
              name = "ESP-x2000-${device}";            
              size = "2G";        # Size of EFI System Partition
              type = "EF00";      # GPT partition type for EFI system

              content = {
                type = "filesystem";
                format = "vfat";  # Required format for EFI
                mountpoint = "/boot";

                mountOptions = [
                  "defaults"
                  "umask=0077"  # Restrict permissions for security
                ];
              };
            };

            luks-x2000 = {
              label = luksLabel;
              size = "100%";  # Use all remaining space for encrypted volume

              content = {
                type = "luks";  # Encrypt with LUKS
                name = "x2000-encrypted-${device}";

                postCreateHook = ''
                  # Interactive setup using gum (only runs during disk creation)
                  choice=$(${pkgs.gum}/bin/gum choose --header="Do you wish to enroll one or more yubikeys for the luks encryption?" "Enroll FIDO2-keys" "Do nothing")

                  if [ "$choice" = "Enroll FIDO2-keys" ]; then
                    complete=0
                    while [ ! $complete -eq 1 ]; do
                      systemd-cryptenroll --fido2-device=auto --fido2-with-client-pin=true /dev/disk/by-partlabel/${luksLabel};
                      ${pkgs.gum}/bin/gum confirm --default=false --affirmative="Enroll another" --negative="Done\!" "Do you wish to enroll any backup keys?" || complete=1;
                    done

                    ${pkgs.gum}/bin/gum confirm --default=false "Do you wish to wipe the passwords protecting the disk?" && systemd-cryptenroll --wipe-slot=password --unlock-fido2-device=auto /dev/disk/by-partlabel/${luksLabel}

                    ${pkgs.gum}/bin/gum confirm --default=true "Do you wish to generate a recovery key?" && systemd-cryptenroll --recovery-key --unlock-fido2-device=auto /dev/disk/by-partlabel/${luksLabel}

                    ${pkgs.gum}/bin/gum confirm --default=true --negative="YOLO" --affirmative="IVE FULFILLED MY DUTY" "Make sure to note that badboi down";
                    sleep 0.1
                  fi
                '';

                extraOpenArgs = [
                  "--allow-discards"           # Enable TRIM (important for SSDs)
                  "--perf-no_read_workqueue"  # Performance tweaks
                  "--perf-no_write_workqueue"
                ];

                settings = {
                  crypttabExtraOpts = [
                    "fido2-device=auto"  # Use FIDO2 to unlock at boot
                    "token-timeout=15"   # Time before timeout for token
                  ];
                };

                # Encrypted content is a btrfs filesystem with subvolumes
                content = {
                  type = "btrfs";
                  extraArgs = [
                    "-L" "fsroot"  # Label the filesystem
                    "-f"          # Force creation
                  ];

                  subvolumes = {
                    "/root" = {
                      mountpoint = "/";
                      mountOptions = [
                        "subvol=root"
                        "compress=zstd"  # Enable compression
                        "noatime"        # Improve performance
                      ];
                    };

                    "/home" = {
                      mountpoint = "/home";
                      mountOptions = [
                        "subvol=home"
                        "compress=zstd"
                        "noatime"
                      ];
                    };

                    "/persist" = {
                      mountpoint = "/persist";  # Often used for persistent config or secrets
                      mountOptions = [
                        "subvol=persist"
                        "compress=zstd"
                        "noatime"
                      ];
                    };

                    "/log" = {
                      mountpoint = "/var/log";  # Separate log volume to avoid cluttering root
                      mountOptions = [
                        "subvol=log"
                        "compress=zstd"
                        "noatime"
                      ];
                    };

                    "/swap" = {
                      mountpoint = "/swap";
                      swap.swapfile.size = "96G";  # Size of the swapfile (adjust to your needs)
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };

  # Ensure logs are mounted early (important for boot-time logging)
  fileSystems."/var/log".neededForBoot = true;
}
