{
  config,
  lib,
  pkgs-unstable,
  ...
}: let
  cfg = config.graphicDriver.intel;
in {
  options.graphicDriver.intel = {
    enable = lib.mkEnableOption "Download gpu drivers for intel";
  };

  # WARNING:
  # - Some settings may need to be tuned for older chips:
  # - https://nixos.wiki/wiki/Intel_Graphics

  config = lib.mkIf cfg.enable {
    # Insert device ID for GPU found with:
    # nix-shell --extra-experimental-features "flakes" -p pciutils --run "lspci -nn | grep VGA"
    boot.kernelParams = ["i915.force_probe=a7a0"];

    hardware.graphics = {
      enable = true;
      extraPackages = with pkgs-unstable; [
        intel-compute-runtime
        vpl-gpu-rt
        intel-ocl
      ];
    };

    environment.sessionVariables = {
      LIBVA_DRIVER_NAME = "iHD";
    };
  };
}
