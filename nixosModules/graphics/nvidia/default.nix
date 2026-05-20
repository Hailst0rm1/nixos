{
  config,
  lib,
  pkgs-unstable,
  ...
}: let
  cfg = config.graphicDriver.nvidia;
in {
  options.graphicDriver.nvidia = {
    enable = lib.mkEnableOption "Enable nvidia gpu drivers.";
    containerToolkit = lib.mkEnableOption "Enable nvidia-container-toolkit for Docker/Podman GPU access.";
    prime = {
      offload.enable = lib.mkEnableOption "Enable NVIDIA PRIME offload mode (render on dGPU, display via iGPU).";
      intelBusId = lib.mkOption {
        default = "";
        type = lib.types.str;
        description = "Bus ID of the Intel iGPU (e.g. 'PCI:0:2:0').";
      };
      nvidiaBusId = lib.mkOption {
        default = "";
        type = lib.types.str;
        description = "Bus ID of the NVIDIA dGPU (e.g. 'PCI:1:0:0').";
      };
    };
  };

  config = lib.mkIf cfg.enable {
    nixpkgs.config.allowUnfree = true;

    boot = {
      initrd.kernelModules = [
        "nvidia"
        "nvidia_modeset"
        "nvidia_uvm"
        "nvidia_drm"
      ];

      kernelParams = [
        "nvidia_drm.fbdev=1"
      ];
    };

    hardware.graphics = {
      enable = true;
      extraPackages = [pkgs-unstable.libva-vdpau-driver];
    };

    # Load nvidia driver for Xorg and Wayland
    services.xserver.videoDrivers = ["nvidia"];

    hardware.nvidia = {
      # Modesetting is required.
      modesetting.enable = true;

      # Nvidia power management. Experimental, and can cause sleep/suspend to fail.
      # Enable this if you have graphical corruption issues or application crashes after waking
      # up from sleep. This fixes it by saving the entire VRAM memory to /tmp/ instead
      # of just the bare essentials.
      powerManagement.enable = true;

      # Fine-grained power management. Turns off GPU when not in use.
      # Experimental and only works on modern Nvidia GPUs (Turing or newer).
      powerManagement.finegrained = false;

      # Use the NVidia open source kernel module (not to be confused with the
      # independent third-party "nouveau" open source driver).
      # Support is limited to the Turing and later architectures. Full list of
      # supported GPUs is at:
      # https://github.com/NVIDIA/open-gpu-kernel-modules#compatible-gpus
      # Only available from driver 515.43.04+
      open = true;

      # Enable the Nvidia settings menu,
      # accessible via `nvidia-settings`.
      nvidiaSettings = true;

      package = config.boot.kernelPackages.nvidiaPackages.latest;

      prime = lib.mkIf cfg.prime.offload.enable {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
        intelBusId = cfg.prime.intelBusId;
        nvidiaBusId = cfg.prime.nvidiaBusId;
      };
    };

    # Enable nvidia-container-toolkit for Docker/Podman GPU access
    hardware.nvidia-container-toolkit.enable = cfg.containerToolkit;

    environment.sessionVariables =
      {
        GBM_BACKEND = "nvidia-drm";
        __GLX_VENDOR_LIBRARY_NAME = "nvidia";
      }
      // lib.optionalAttrs cfg.prime.offload.enable {
        __NV_PRIME_RENDER_OFFLOAD = "1";
        __NV_PRIME_RENDER_OFFLOAD_PROVIDER = "NVIDIA-G0";
        __VK_LAYER_NV_optimus = "NVIDIA_only";
      };

    # GPU diagnostic tools
    environment.systemPackages = with pkgs-unstable; [
      vulkan-tools
      mesa-demos
      libva-utils
      vdpauinfo
    ];
  };
}
