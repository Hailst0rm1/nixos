# Hailst0rm NixOS

---

# Installation

Run `lsblk` and note down the disk you want to install nixos on, e.g.:
```
❯ lsblk
NAME        MAJ:MIN RM   SIZE RO TYPE MOUNTPOINTS
sda           8:0    0 476.9G  0 disk
└─sda1        8:1    0 476.9G  0 part /media/Resources
nvme0n1     259:0    0 476.9G  0 disk <----------- Say I want to install it here
├─nvme0n1p1 259:1    0   512M  0 part /boot
└─nvme0n1p2 259:2    0 476.4G  0 part /nix/store
                                      /
```

If a VPS - also run `ip a` and not down the IP-address.

If there is not hostname config that matches the installation - create one under `hosts/HOSTNAME/configuration.nix` together with `hosts/HOSTNAME/disks.nix` (see Nix-Laptop for an example config). E.g. Maybe you need to enable SSH with a key for access if using a VPS. Make sure that the bellow is set the disk determined with `lsblk`:

configuration.nix:
```
    ./disks.nix
    {
      _module.args.device = "nvme0n1"; # Set disk device (e.g. "sda", or "nvme0n1") - list with `lsblk`
    }
```

Then for installation:

## Disko-install (local installation)

```
sudo nix run 'github:nix-community/disko/latest#disko-install' -- --flake github:hailst0rm1/nixos#<hostname-for-config> --disk <disk-name> <disk-device>
```

### Examples

**External disk:**
```
sudo nix run 'github:nix-community/disko/latest#disko-install' -- --flake github:hailst0rm1/nixos#<hostname-for-config> --disk x2000 /dev/sda
```

**Current machine (new hardware, fresh install):**
```
sudo nix run 'github:nix-community/disko/latest#disko-install' -- --flake github:hailst0rm1/nixos#<hostname-for-config> --write-efi-boot-entries --disk x2000 /dev/nvme0n1
```
- --write-efi-boot-entries : Write EFI boot entries to the NVRAM of the system for the installed system. Specify this option if you plan to boot from this disk on the current machine, but not if you plan to move the disk to another machine.

**Update machine (same hardware):**
```
sudo nix run 'github:nix-community/disko/latest#disko-install' -- --flake github:hailst0rm1/nixos#<hostname-for-config> --write-efi-boot-entries --mode mount --disk x2000 /dev/nvme0n1
```
- --mode MODE - Specify the mode of operation. Valid modes are: format, mount.
  - Format will format the disk before installing.
  - Mount will mount the disk before installing.
    - Mount is useful for updating an existing system without losing data.

**Test run**
Add flag `--dry-run`

## Nixos-anywhere (remote install via ssh)

```
nix run github:nix-community/nixos-anywhere -- --flake <path to configuration>#<configuration name> --target-host root@<ip address>
```
**Warning:** I have not tried this yet, nor do I know how it behaves with secrets, look at the resources if you have to do this:
- [Quickstart](https://github.com/nix-community/nixos-anywhere/blob/main/docs/quickstart.md)
- [Secrets](https://github.com/nix-community/nixos-anywhere/blob/main/docs/howtos/secrets.md)
- [Copy files to installation](https://github.com/nix-community/nixos-anywhere/blob/main/docs/howtos/extra-files.md)


# Secrets (sops-nix)


