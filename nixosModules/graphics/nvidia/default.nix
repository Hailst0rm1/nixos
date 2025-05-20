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
    type = lib.mkOption {
      default = "default";
      type = lib.types.str;
      description = "Select display manager.";
    };
  };

  config = lib.mkIf (cfg.enable == true && cfg.type == "default") {
    nixpkgs.config.allowUnfree = true;

    boot = {
      initrd.kernelModules = [
        "nvidia"
        "nvidia_modeset"
        "nvidia_uvm"
        "nvidia_drm"
      ];

      kernelParams = [
        # "nvidia_drm.fbdev=1"
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
      # Currently alpha-quality/buggy, so false is currently the recommended setting.
      open = true;
      # open = false;

      # Enable the Nvidia settings menu,
      # accessible via `nvidia-settings`.
      nvidiaSettings = true;

      package = config.boot.kernelPackages.nvidiaPackages.latest;
      # package = config.boot.kernelPackages.nvidiaPackages.stable;
    };
  };
}
