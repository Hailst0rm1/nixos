# Hailst0rm NixOS

![Desktop Preview](/assets/desktop.png)

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

## Installation media

Depending on the size of the config for the workstation installation, the RAM for /tmpfs wont be enough, which you'll have to compensate for using swap.

My setup:
1. Create custom installer .iso from thir repo: `nix run nixpkgs#nixos-generators -- --format iso --flake github:hailst0rm1/nixos#Nix-Installer -o result`
1. Create bootable USB (64GB): `dd bs=4M if=result/iso/nixos-minimal-25.05.20250602.10d7f8d-x86_64-linux.iso of=/dev/sdx status=progress oflag=sync` (double check `of=` with `lsblk`)
2. Create a swap partiotion of remaining space on USB: I did it via gnome-disks
3. Now boot into the USB
4. Activate swap partition: `swapon /dev/sdx2`
5. Expand the root and nix-store: `mount -o remount,size=35G,noatime /nix/.rw-store && mount -o remount,size=25G,noatime /`

## Method 1: Disko-install

**Warning:** This method formats the disk and installs your entire nixos configuration in one step. This is meant for *local installation* that are *minimal enough* not to crash the installation. For a more safe method where you *format the disk first* and finish the installation on the targeted hardware, look at Method 2.


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

## Method 2: Disko-Install with minimal installation

**Use case:** This is meant for when you have a large configuration that you don't want to crash during the installation process - or is not certain if it will boot after a finished installation.

Download disko config:
```shell
git clone https://github.com/hailst0rm1/nixos
```

Only generate hardware config:
```shell
sudo nixos-generate-config --no-filesystems --show-hardware-config >> nixos/hosts/Nix-Minimal/hardware-configuration.nix
```

Change device in `hosts/Nix-Minimal/configuration.nix`
> Get `target-disk` with `lsblk` to determine correct disk

Run installation:
```shell
sudo nix run 'github:nix-community/disko/latest#disko-install' --extra-experimental-features "flakes nix-command" --cores 8 -j 1 -- --flake nixos#Nix-Minimal --write-efi-boot-entries --disk x2000-<device> /dev/<device> --mode format
sudo nix run 'github:nix-community/disko/latest#disko-install' --extra-experimental-features "flakes nix-command" --cores 8 -j 1 -- --flake nixos#Nix-Minimal --write-efi-boot-entries --disk x2000-<device> /dev/<device> --mode mount
```
> Note: The script isn't perfect - for me, the best approach was running format mode first allows me to set the passwords/yubis, then let it fail. Then run with mount to install the files.

- --write-efi-boot-entries : Write EFI boot entries to the NVRAM of the system for the installed system. Specify this option if you plan to boot from this disk on the current machine, but not if you plan to move the disk to another machine.

Now reboot and finish the installation:
```shell
git clone https://github.com/hailst0rm1/nixos
mv nixos .nixos
sudo nixos-rebuild boot --cores 8 -j 1 --flake .nixos#<Hostname>
```


## Method 3: Nixos-anywhere 

**Warning:** This method has not yet been tested by me.

**Use case:** Remote install via SSH - e.g. install to a cloud provider.

```
nix run github:nix-community/nixos-anywhere -- --flake <path to configuration>#<configuration name> --target-host root@<ip address>
```
**Warning:** I have not tried this yet, nor do I know how it behaves with secrets, look at the resources if you have to do this:
- [Quickstart](https://github.com/nix-community/nixos-anywhere/blob/main/docs/quickstart.md)
- [Secrets](https://github.com/nix-community/nixos-anywhere/blob/main/docs/howtos/secrets.md)
- [Copy files to installation](https://github.com/nix-community/nixos-anywhere/blob/main/docs/howtos/extra-files.md)

## VMWare error

VMWare changed their download link to be behind a loginpage, thus we have to download it and manually put it into the nix-store:

1. Repo: https://github.com/liberodark/vmware/releases
2. Run: `nix-store --add-fixed sha256 VMWARE.BUNDLE`

# Secrets (sops-nix)

Edit `.sops.yaml` to your liking.

TODO: Make secrets for each user.

Generate master key - store it in a vault of some sort to always have access to your sops:
```shell
age-keygen -o ~/.config/sops/age/keys.txt
```

Then generate age for your user and add it in `.sops.yaml`. If you use the same ssh-key it will always generate the same age-key:
```shell
nix run nixpkgs#ssh-to-age -- -private-key -i ~/.ssh/id_hailst0rm > ~/.config/sops/age/keys.txt
```

Do the same for the host ssh-key:
```shell
nix-shell -p ssh-to-age --run 'cat /etc/ssh/ssh_host_ed25519_key.pub | ssh-to-age'
```
> Note: The private key will be generated by the nixosModule - so it's not required to generate

After you add any keys to `.sops.yaml` - you must run the following to re-encyrpt the secrets using the new `.sops.yaml`:
```shell
sops updatekeys secrets.yaml
```

When you're done, you can access your secrets under `secrets/secrets.yaml`.

# Yubikeys

The repo supports ssh and sudo using yubikeys

Set pin:
```shell
ykman fido access change-pin
```

SSH: Generate ssh-key for yubi:
```
ssh-keygen -t ed25519-sk -N "" -C "yubikey A" -f ~/.ssh/id_yubic
```
- Import private keys in secrets.yaml under `keys/ssh/`
- Put the public keys in `nixosModules/system/keys/` - this is to allow ssh to the host from our yubikeys

Sudo:
```
# First key
pamu2fcfg -u <username> > ~/u2f_keys

# If you have more than one, run this for the remaining ones
pamu2fcfg -n >> ~/u2f_keys
```
> Then make an entry under `keys/yubikey/<username>` with the contents of `u2f_keys` in secrets.yaml - sops will then import it correctly.
