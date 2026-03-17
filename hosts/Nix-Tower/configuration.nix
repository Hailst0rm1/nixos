{
  inputs,
  pkgs,
  ...
}: let
  device = "nvme0n1"; # IMPORTANT Set disk device (e.g. "sda", or "nvme0n1") - list with `lsblk`
  swapSize = "16G"; # IMPORTANT Keep at 16GB, unless hibernation - then set to RAM size (e.g. "32G", "64G") - check with `free -g`
  diskoConfig = "default";
in {
  imports = [
    ./hardware-configuration.nix
    ../default.nix

    # NixOS-Hardware
    # List: https://github.com/NixOS/nixos-hardware/blob/master/flake.nix
    inputs.nixos-hardware.nixosModules.common-cpu-intel-cpu-only # Intel microcode updates (without iGPU stack)
    inputs.nixos-hardware.nixosModules.common-pc-ssd # Periodic fstrim for NVMe SSD longevity
    # inputs.nixos-hardware.nixosModules.common-gpu-nvidia-nonprime # Redundant - custom nvidia module is more comprehensive
    # inputs.nixos-hardware.nixosModules.common-gpu-nvidia # PRIME offload - laptop only, NOT for desktop
    # inputs.nixos-hardware.nixosModules.common-gpu-intel # iGPU drivers - not needed, displays on NVIDIA
    # inputs.nixos-hardware.nixosModules.common-pc-laptop
    # inputs.nixos-hardware.nixosModules.common-pc-laptop-ssd

    # Disk partitioning
    inputs.disko.nixosModules.disko
    ../../nixosModules/system/bootloader.nix
    ../../disko/${diskoConfig}.nix
    {
      _module.args.device = device;
      _module.args.swapSize = swapSize;
    }
  ];

  # Override only what's different from the default
  cyber.redTools.enable = true;
  graphicDriver.nvidia.enable = true;
  security.sops.enable = true;
  security.yubikey.enable = true;
  services.tailscaleAutoconnect.enable = true;

  # Desktop performance tuning
  # Set power-profiles-daemon to performance mode on boot (ppd controls intel_pstate governor)
  systemd.services.power-profiles-performance = {
    description = "Set power profile to performance";
    after = ["power-profiles-daemon.service"];
    wants = ["power-profiles-daemon.service"];
    wantedBy = ["multi-user.target"];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.power-profiles-daemon}/bin/powerprofilesctl set performance";
      RemainAfterExit = true;
    };
  };

  boot.kernel.sysctl = {
    "vm.swappiness" = 10; # Prefer RAM over swap on 32GB desktop
    "kernel.nmi_watchdog" = 0; # Free a hardware perf counter (no hang detection needed on desktop)
  };

  services.nas.client = {
    enable = true;
    serverHost = "nix-server"; # Tailscale MagicDNS hostname (or use 100.x.x.x IP)
    shareName = "files";
    mountPoint = "/mnt/nas";
    idleTimeoutSec = "0";
  };

  services = {
    syncthing-sync = {
      enable = true;
      folders = {
        "nixos-config" = {
          label = "NixOS Config";
          path = "/home/hailst0rm/.nixos";
          stignore = ''
            .claude
            .direnv
            result
          '';
        };
        "code" = {
          label = "Code Projects";
          path = "/home/hailst0rm/Code";
        };
        "notsliver" = {
          label = "NotSliver";
          path = "/home/hailst0rm/.config/NotSliver";
        };
      };
    };
  };
}
