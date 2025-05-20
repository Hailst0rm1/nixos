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
}: let
  device = "nvme0n1"; # IMPORTANT Set disk device (e.g. "sda", or "nvme0n1") - list with `lsblk`
in {
```

> [!Tip] Installation media
> Depending on the size of the config for the workstation installation, the RAM for /tmpfs wont be enough, which you'll have to compensate for using swap. My setup:
> - Create bootable USB (64GB): `dd bs=4M if=Downloads/nixos-gnome-installer-24.11.iso of=/dev/sdx status=progress oflag=sync`
> - Create a swap partiotion of remaining space on USB: I did it via gnome-disks
> - Now boot into the USB
> - Activate swap partition: `swapon /dev/sdx2`
> - Expand the root and nix-store: `mount -o remount,size=35G,noatime /nix/.rw-store && mount -o remount,size=25G,noatime /`

## Disko-install (local installation)

```shell
sudo nix run 'github:nix-community/disko/latest#disko-install' --extra-experimental-features "flakes nix-command" --cores 8 -j 1 -- --flake github:hailst0rm1/nixos#<Hostname-in-Flake> --write-efi-boot-entries --disk x2000-<device> /dev/<device>
```

### Examples

**External disk:**
```shell
sudo nix run 'github:nix-community/disko/latest#disko-install' --extra-experimental-features "flakes nix-command" --cores 8 -j 1 -- --flake github:hailst0rm1/nixos#<Hostname-in-Flake> --write-efi-boot-entries --disk x2000-sda /dev/sda --mode format
```

**Current machine (new hardware, fresh install):**
```shell
sudo nix run 'github:nix-community/disko/latest#disko-install' --extra-experimental-features "flakes nix-command" --cores 8 -j 1 -- --flake github:hailst0rm1/nixos#<Hostname-in-Flake> --write-efi-boot-entries --disk x2000-<device> /dev/<device> --mode format
sudo nix run 'github:nix-community/disko/latest#disko-install' --extra-experimental-features "flakes nix-command" --cores 8 -j 1 -- --flake github:hailst0rm1/nixos#<Hostname-in-Flake> --write-efi-boot-entries --disk x2000-<device> /dev/<device> --mode mount
```
> Note: The script isn't perfect - for me, the best approach was running format mode first allows me to set the passwords/yubis, then let it fail. Then run with mount to install the files.

- --write-efi-boot-entries : Write EFI boot entries to the NVRAM of the system for the installed system. Specify this option if you plan to boot from this disk on the current machine, but not if you plan to move the disk to another machine.

**Update machine (same hardware) NOT TESTED IF IT WORKS:**

```shell
sudo nix run 'github:nix-community/disko/latest#disko-install' --extra-experimental-features "flakes nix-command" --cores 8 -j 1 -- --flake github:hailst0rm1/nixos#<Hostname-in-Flake> --write-efi-boot-entries --disk x2000-<device> /dev/<device> --mode mount
```
- --mode MODE - Specify the mode of operation. Valid modes are: format, mount.
  - Format will format the disk before installing.
  - Mount will mount the disk before installing.
    - Mount is useful for updating an existing system without losing data.

## Nixos-anywhere (remote install via ssh) - NOT TESTED NOR FINISHED

```
nix run github:nix-community/nixos-anywhere -- --flake <path to configuration>#<configuration name> --target-host root@<ip address>
```
**Warning:** I have not tried this yet, nor do I know how it behaves with secrets, look at the resources if you have to do this:
- [Quickstart](https://github.com/nix-community/nixos-anywhere/blob/main/docs/quickstart.md)
- [Secrets](https://github.com/nix-community/nixos-anywhere/blob/main/docs/howtos/secrets.md)
- [Copy files to installation](https://github.com/nix-community/nixos-anywhere/blob/main/docs/howtos/extra-files.md)


# Secrets (sops-nix)

TODO
